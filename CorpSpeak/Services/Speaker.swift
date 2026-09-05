import AVFoundation
import Foundation
import NaturalLanguage
import Observation

/// Reads text aloud in the user's own voice, one sentence at a time, and reports which
/// sentence is playing.
///
/// The voice is the user's Personal Voice, which macOS creates in System Settings →
/// Accessibility → Personal Voice and hands to apps through `AVSpeechSynthesizer` once the
/// user allows it. There is no other voice: until the user has one and has let CorpSpeak use
/// it, nothing is spoken.
@MainActor
@Observable
final class Speaker {
    enum VoiceStatus: Equatable {
        /// Not looked yet.
        case checking
        /// This Mac cannot offer a Personal Voice.
        case unsupported
        /// CorpSpeak has not asked to use the Personal Voice yet.
        case notDetermined
        /// The user said no, or "Allow Apps to Request to Use" is off.
        case denied
        /// Allowed, but no Personal Voice has been created.
        case noVoice
        /// Ready to speak with the named voice.
        case ready(String)
    }

    private(set) var voiceStatus: VoiceStatus = .checking

    private(set) var isSpeaking = false
    /// The sentences of the text currently being spoken.
    private(set) var sentences: [String] = []
    /// Index into `sentences` of the one playing right now.
    private(set) var currentSentence: Int?

    /// Called on the main actor whenever `voiceStatus` changes.
    var onVoiceChange: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private let events = SynthesisEvents()
    private var voice: AVSpeechSynthesisVoice?
    private var generation = 0
    private var finishCurrent: Resumer?
    private var voicesObserver: Task<Void, Never>?

    init() {
        synthesizer.delegate = events
    }

    /// True once a Personal Voice is available and CorpSpeak may use it.
    var isReady: Bool { voice != nil }

    // MARK: Voice

    /// Looks up the current permission without prompting, loads the voice if allowed, and keeps
    /// watching for a voice being created or removed while the app runs.
    func prepare() {
        refresh()
        guard voicesObserver == nil else { return }
        voicesObserver = Task { [weak self] in
            let changes = NotificationCenter.default.notifications(named: AVSpeechSynthesizer.availableVoicesDidChangeNotification)
            for await _ in changes {
                self?.refresh()
            }
        }
    }

    /// Asks macOS for permission to use the Personal Voice. The first time, macOS shows its own
    /// prompt; after that it answers from the user's earlier choice.
    func requestAuthorization() async {
        _ = await withCheckedContinuation { (continuation: CheckedContinuation<AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus, Never>) in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { continuation.resume(returning: $0) }
        }
        refresh()
    }

    private func refresh() {
        let status: VoiceStatus
        switch AVSpeechSynthesizer.personalVoiceAuthorizationStatus {
        case .unsupported:
            voice = nil
            status = .unsupported
        case .notDetermined:
            voice = nil
            status = .notDetermined
        case .denied:
            voice = nil
            status = .denied
        case .authorized:
            voice = Self.personalVoice()
            status = voice.map { .ready($0.name) } ?? .noVoice
        @unknown default:
            voice = nil
            status = .unsupported
        }
        guard status != voiceStatus else { return }
        voiceStatus = status
        onVoiceChange?()
    }

    /// The user's Personal Voice, preferring one in the current language if there are several.
    private static func personalVoice() -> AVSpeechSynthesisVoice? {
        let personal = AVSpeechSynthesisVoice.speechVoices().filter { $0.voiceTraits.contains(.isPersonalVoice) }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        return personal.first { $0.language.hasPrefix(language) } ?? personal.first
    }

    // MARK: Speaking

    /// Speaks in the user's voice. Returns false if nothing could be spoken because no
    /// Personal Voice is available.
    @discardableResult
    func speak(_ text: String) async -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return true }
        guard let voice else { return false }

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

        let utterances = sentences.map { sentence in
            let utterance = AVSpeechUtterance(string: sentence)
            utterance.voice = voice
            utterance.prefersAssistiveTechnologySettings = false
            return utterance
        }
        let ids = utterances.map(ObjectIdentifier.init)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let done = Resumer(continuation)
            finishCurrent = done
            events.onStart = { [weak self] id in
                guard let self, self.generation == thisGeneration, let index = ids.firstIndex(of: id) else { return }
                self.currentSentence = index
            }
            events.onFinish = { [weak self] id in
                guard let self, self.generation == thisGeneration, id == ids.last else { return }
                done.resume()
            }
            events.onCancel = { [weak self] _ in
                guard let self, self.generation == thisGeneration else { return }
                done.resume()
            }
            for utterance in utterances {
                synthesizer.speak(utterance)
            }
        }
        withExtendedLifetime(utterances) {}
        return true
    }

    /// Stops playback. Any pending `speak` returns promptly.
    func stop() {
        generation += 1
        synthesizer.stopSpeaking(at: .immediate)
        finishCurrent?.resume()
        finishCurrent = nil
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

/// Forwards synthesizer callbacks, which may arrive on any thread, to the main actor as
/// utterance identities.
private final class SynthesisEvents: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onStart: (@MainActor (ObjectIdentifier) -> Void)?
    var onFinish: (@MainActor (ObjectIdentifier) -> Void)?
    var onCancel: (@MainActor (ObjectIdentifier) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.onStart?(id) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.onFinish?(id) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.onCancel?(id) }
    }
}

/// Guards a continuation so it resumes exactly once.
private final class Resumer: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.withLock {
            continuation?.resume()
            continuation = nil
        }
    }
}
