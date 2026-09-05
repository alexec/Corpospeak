import AVFoundation
import Foundation
import NaturalLanguage
import Observation

/// Reads text aloud, one sentence at a time, and reports which sentence is playing.
///
/// Corpospeak is at its best in the user's own voice, so the Personal Voice — which the system
/// creates in Settings → Accessibility → Personal Voice — leads the voice menu and is spoken
/// with by default as soon as Corpospeak is allowed to use it. System voices are the fallback:
/// they need no setup, so the app works the moment it launches, and in the Simulator, which
/// cannot create a Personal Voice.
@MainActor
@Observable
final class Speaker {
    /// One voice the user can choose from the voice menu.
    struct VoiceOption: Identifiable, Equatable {
        let id: String
        let name: String
        let isPersonalVoice: Bool
    }

    /// Where things stand with the user's own cloned voice, separate from which voice is
    /// currently selected.
    enum PersonalVoiceStatus: Equatable {
        /// Not looked yet.
        case checking
        /// This device cannot offer a Personal Voice.
        case unsupported
        /// Corpospeak has not asked to use the Personal Voice yet.
        case notDetermined
        /// The user said no, or "Allow Apps to Request to Use" is off.
        case denied
        /// Allowed, but no Personal Voice has been created.
        case noVoice
        /// One or more Personal Voices are available to select.
        case available
    }

    private(set) var personalVoiceStatus: PersonalVoiceStatus = .checking
    /// Every voice Corpospeak can currently speak with: the user's Personal Voices first, then
    /// the system voices.
    private(set) var voices: [VoiceOption] = []
    /// The identifier of the voice Corpospeak speaks with. `nil` only if no voice at all is
    /// installed, which should not happen on a real device or the Simulator.
    private(set) var selectedVoiceID: String?

    private(set) var isSpeaking = false
    /// The sentences of the text currently being spoken.
    private(set) var sentences: [String] = []
    /// Index into `sentences` of the one playing right now.
    private(set) var currentSentence: Int?

    private let synthesizer = AVSpeechSynthesizer()
    private let events = SynthesisEvents()
    private var generation = 0
    private var finishCurrent: Resumer?
    private var voicesObserver: Task<Void, Never>?

    private static let selectedVoiceDefaultsKey = "corpospeak.selectedVoiceIdentifier"

    init() {
        synthesizer.delegate = events
    }

    /// The voice currently selected, resolved from its identifier.
    var selectedVoice: VoiceOption? {
        voices.first { $0.id == selectedVoiceID }
    }

    /// True once a voice is selected and Corpospeak may speak.
    var isReady: Bool { selectedVoiceID != nil }

    // MARK: Voice

    /// Looks up the current Personal Voice permission without prompting, loads the available
    /// voices, and keeps watching for one being created, downloaded, or removed while the app
    /// runs.
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

    /// Asks the system for permission to use the Personal Voice, but only if the user hasn't
    /// been asked before. Called at launch, so the app starts in the user's voice when it can.
    func requestAuthorizationIfNeeded() async {
        guard personalVoiceStatus == .notDetermined else { return }
        await requestAuthorization()
    }

    /// Asks the system for permission to use the Personal Voice. The first time, it shows its
    /// own prompt; after that it answers from the user's earlier choice.
    func requestAuthorization() async {
        _ = await withCheckedContinuation { (continuation: CheckedContinuation<AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus, Never>) in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { continuation.resume(returning: $0) }
        }
        refresh()
    }

    /// The user's Personal Voices, if any: `voices` without the system voices.
    var personalVoiceOptions: [VoiceOption] { voices.filter(\.isPersonalVoice) }

    /// The system voices: `voices` without the user's Personal Voices.
    var systemVoiceOptions: [VoiceOption] { voices.filter { !$0.isPersonalVoice } }

    /// Selects the voice to speak with and remembers the choice for next launch.
    func select(voiceID: String) {
        guard voices.contains(where: { $0.id == voiceID }) else { return }
        selectedVoiceID = voiceID
        UserDefaults.standard.set(voiceID, forKey: Self.selectedVoiceDefaultsKey)
    }

    private func refresh() {
        switch AVSpeechSynthesizer.personalVoiceAuthorizationStatus {
        case .unsupported:
            personalVoiceStatus = .unsupported
        case .notDetermined:
            personalVoiceStatus = .notDetermined
        case .denied:
            personalVoiceStatus = .denied
        case .authorized:
            personalVoiceStatus = Self.personalVoices().isEmpty ? .noVoice : .available
        @unknown default:
            personalVoiceStatus = .unsupported
        }

        let personal = Self.personalVoices().map { VoiceOption(id: $0.identifier, name: $0.name, isPersonalVoice: true) }
        let system = Self.systemVoices().map { VoiceOption(id: $0.identifier, name: Self.displayName(for: $0), isPersonalVoice: false) }
        // The user's own Personal Voice, if any, leads the list; system voices follow.
        voices = personal + system

        if let saved = UserDefaults.standard.string(forKey: Self.selectedVoiceDefaultsKey),
           voices.contains(where: { $0.id == saved }) {
            // The user picked this one; keep it.
            selectedVoiceID = saved
        } else {
            // Until the user picks a voice, the default is their own Personal Voice as soon as
            // there is one — including the moment it is authorized or finishes processing while
            // the app runs — and the system's default voice until then.
            selectedVoiceID = personal.first?.id ?? Self.defaultSystemVoice()?.identifier ?? voices.first?.id
        }
    }

    /// The user's Personal Voices, if Corpospeak has been allowed to use them.
    private static func personalVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.voiceTraits.contains(.isPersonalVoice) }
    }

    /// The system's voices for the current language, one per name (the best quality installed,
    /// where a name has both a standard and an Enhanced/Premium version). Excludes the old
    /// novelty voices (Bad News, Zarvox, and the like), which share the modern voices' language
    /// but not their identifier scheme.
    private static func systemVoices() -> [AVSpeechSynthesisVoice] {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let all = AVSpeechSynthesisVoice.speechVoices().filter {
            !$0.voiceTraits.contains(.isPersonalVoice) && !$0.identifier.hasPrefix("com.apple.speech.synthesis.voice.")
        }
        let matching = all.filter { $0.language.hasPrefix(language) }
        let pool = matching.isEmpty ? all : matching

        var bestByName: [String: AVSpeechSynthesisVoice] = [:]
        for voice in pool where bestByName[voice.name].map({ $0.quality.rawValue < voice.quality.rawValue }) ?? true {
            bestByName[voice.name] = voice
        }
        return bestByName.values.sorted { $0.name < $1.name }
    }

    /// The system's own default voice for the current language, which is usually the best one
    /// installed.
    private static func defaultSystemVoice() -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: nil) ?? systemVoices().first
    }

    private static func displayName(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .enhanced: "\(voice.name) (Enhanced)"
        case .premium: "\(voice.name) (Premium)"
        default: voice.name
        }
    }

    // MARK: Speaking

    /// Speaks with the selected voice. Returns false if nothing could be spoken because no voice
    /// is available at all.
    @discardableResult
    func speak(_ text: String) async -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return true }
        guard let selectedVoiceID, let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceID) else { return false }

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
