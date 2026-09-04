import Foundation
import NaturalLanguage
import Observation

/// Reads text aloud in the user's own cloned voice, one sentence at a time, and reports which
/// sentence is playing. There is no other voice: until the user has recorded theirs and the
/// model is loaded, nothing is spoken.
@MainActor
@Observable
final class Speaker {
    let modelStore = ModelStore()

    private(set) var isSpeaking = false
    /// The sentences of the text currently being spoken.
    private(set) var sentences: [String] = []
    /// Index into `sentences` of the one playing right now.
    private(set) var currentSentence: Int?

    /// The user's recorded reference, if they have enrolled.
    private(set) var voiceSample: VoiceSample?

    private var zipVoice: ZipVoiceSynthesizer?
    private var loadTask: Task<Void, Never>?
    private var prepareTask: Task<Void, Never>?
    private let player = AudioPlayer()
    private var generation = 0

    init() {
        voiceSample = VoiceSample.load(from: VoiceSample.fileURL(in: modelStore.root))
    }

    var hasOwnVoice: Bool { voiceSample != nil }

    /// True once the cloning model is loaded and can synthesize.
    var isReady: Bool { zipVoice != nil }

    /// Installs the model if needed and loads it. Listening carries on while this runs.
    func prepare() async {
        if let prepareTask {
            await prepareTask.value
            return
        }
        let task = Task {
            await loadClonerIfPossible()
            await modelStore.ensureInstalled()
            await loadClonerIfPossible()
        }
        prepareTask = task
        await task.value
    }

    /// Loads the cloner if its files are on disk and it is not loaded yet. Only one load runs
    /// at a time: the model's phonemizer keeps global state, and two concurrent loads can
    /// leave one of them broken.
    private func loadClonerIfPossible() async {
        if let loadTask {
            await loadTask.value
            return
        }
        guard zipVoice == nil,
              modelStore.isInstalled(ModelStore.zipVoice),
              modelStore.isInstalled(ModelStore.vocoder)
        else { return }

        let synthesizer = ZipVoiceSynthesizer(
            modelDirectory: modelStore.location(of: ModelStore.zipVoice),
            vocoder: modelStore.location(of: ModelStore.vocoder)
        )
        let task = Task { [weak self] in
            do {
                try await synthesizer.warmUp()
                self?.zipVoice = synthesizer
            } catch {
                self?.zipVoice = nil
            }
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    // MARK: Enrollment

    /// Stores a new recording of the user reading the phrase.
    func enroll(_ sample: VoiceSample) {
        let cleaned = sample.trimmed()
        try? cleaned.save(to: VoiceSample.fileURL(in: modelStore.root))
        voiceSample = cleaned
    }

    // MARK: Speaking

    /// Speaks in the user's voice. Waits for the model if it is still installing. Returns false
    /// if nothing could be spoken: no recording yet, or the model failed to install.
    @discardableResult
    func speak(_ text: String) async -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return true }

        if zipVoice == nil {
            await prepare()
        }
        guard let zipVoice, let sample = voiceSample else { return false }

        stop()
        generation += 1
        let thisGeneration = generation
        isSpeaking = true
        sentences = Self.split(text)
        currentSentence = nil
        defer {
            if generation == thisGeneration {
                isSpeaking = false
                currentSentence = nil
            }
        }

        // Synthesize the next sentence while the current one plays.
        func prefetch(_ index: Int) -> Task<AudioClip?, Never> {
            let sentence = sentences[index]
            return Task.detached(priority: .userInitiated) {
                try? await zipVoice.synthesize(sentence, reference: sample)
            }
        }

        var upcoming = prefetch(0)
        for index in sentences.indices {
            let clip = await upcoming.value
            guard generation == thisGeneration else { return true }
            if index + 1 < sentences.count {
                upcoming = prefetch(index + 1)
            }
            guard let clip else { continue }
            currentSentence = index
            await player.play(clip)
            guard generation == thisGeneration else { return true }
        }
        return true
    }

    func stop() {
        generation += 1
        player.stop()
        isSpeaking = false
        currentSentence = nil
    }

    /// Splits text into sentences, keeping punctuation. Falls back to the whole text.
    static func split(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { result.append(sentence) }
            return true
        }
        return result.isEmpty ? [text] : result
    }
}
