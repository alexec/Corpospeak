import Foundation
import Observation

/// Wires the services together: listen → translate → speak → listen.
/// Until the user's Personal Voice is available, it holds in a setup step instead.
@MainActor
@Observable
final class CorpospeakModel {
    enum Phase: Equatable {
        case starting
        case setup
        case listening
        case muted
        case translating
        case speaking
        case error(String)
    }

    let listener = SpeechListener()
    let translator = Translator()
    let speaker = Speaker()

    private(set) var phase: Phase = .starting

    /// The last thing the user said.
    private(set) var heard = ""
    /// Its Corpospeak rendering.
    private(set) var translated = ""

    private enum Job {
        case utterance(String)
    }

    private var pending: [Job] = []
    private var isProcessing = false
    private var isSettingUp = false
    /// Bumped by `stopSpeaking` so a translation in flight is discarded instead of spoken.
    private var cancelGeneration = 0

    var isMuted: Bool { listener.isMuted }

    func start() async {
        translator.checkAvailability()

        speaker.onVoiceChange = { [weak self] in
            self?.voiceChanged()
        }
        speaker.prepare()

        listener.onUtterance = { [weak self] text in
            self?.handleUtterance(text)
        }
        await listener.start()

        if listener.status == .listening || listener.status == .muted, !speaker.isReady {
            beginSetup()
        } else {
            refreshPhase()
        }
    }

    func stop() {
        listener.stop()
        speaker.stop()
    }

    /// Mutes or unmutes the microphone. Muting mid-sentence drops that sentence.
    func toggleMute() {
        listener.setMuted(!listener.isMuted)
        if !isProcessing, !isSettingUp { refreshPhase() }
    }

    /// True while there is something to stop: a translation in flight or speech playing.
    var canStop: Bool {
        phase == .translating || phase == .speaking
    }

    /// Cuts off whatever is being spoken or translated and drops anything queued behind it.
    /// Listening resumes as usual.
    func stopSpeaking() {
        guard canStop else { return }
        cancelGeneration += 1
        pending.removeAll()
        speaker.stop()
    }

    // MARK: Voice setup

    /// Asks macOS to let Corpospeak use the Personal Voice.
    func authorizeVoice() async {
        await speaker.requestAuthorization()
    }

    /// Opens the settings app as near to Accessibility → Personal Voice as the platform allows.
    func openVoiceSettings() {
        Platform.openVoiceSettings()
    }

    /// Restarts the microphone if the system stopped it while the app was away.
    func resumeAfterInterruption() {
        listener.recover()
    }

    /// Holds the pipeline until a Personal Voice is available. Listening pauses meanwhile.
    private func beginSetup() {
        guard listener.status != .idle else { return }
        if case .unavailable = listener.status { return }
        speaker.stop()
        pending.removeAll()
        isSettingUp = true
        listener.pause()
        phase = .setup
    }

    private func finishSetup() {
        isSettingUp = false
        listener.resume()
        refreshPhase()
    }

    private func voiceChanged() {
        if speaker.isReady {
            if isSettingUp { finishSetup() }
        } else if !isSettingUp, !isProcessing {
            beginSetup()
        }
    }

    // MARK: Pipeline

    private func handleUtterance(_ text: String) {
        guard !isSettingUp else { return }
        enqueue(.utterance(text))
    }

    private func enqueue(_ job: Job) {
        pending.append(job)
        // Pause synchronously so nothing is heard while we work (including our own voice).
        listener.pause()
        guard !isProcessing else { return }
        Task { await drain() }
    }

    private func drain() async {
        isProcessing = true
        defer { isProcessing = false }

        while !pending.isEmpty {
            switch pending.removeFirst() {
            case .utterance(let text):
                await process(text)
            }
        }

        if speaker.isReady {
            listener.resume()
            refreshPhase()
        } else {
            beginSetup()
        }
    }

    private func process(_ text: String) async {
        heard = text
        translated = ""

        if case .unavailable(let why) = translator.availability {
            phase = .error(why)
            return
        }

        phase = .translating
        let generation = cancelGeneration
        do {
            translated = try await translator.translate(text)
            guard generation == cancelGeneration else { return }
            phase = .speaking
            if await !speaker.speak(translated) {
                phase = .error("Your Personal Voice isn't available. Check the voice menu.")
            }
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func refreshPhase() {
        if case .unavailable(let why) = listener.status {
            phase = .error(why)
        } else if case .unavailable(let why) = translator.availability {
            phase = .error(why)
        } else if isSettingUp {
            phase = .setup
        } else if listener.status == .muted {
            phase = .muted
        } else if listener.status == .listening {
            phase = .listening
        }
    }
}
