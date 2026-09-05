import Foundation
import Observation

/// Wires the services together: listen → translate → speak → listen.
@MainActor
@Observable
final class CorpospeakModel {
    enum Phase: Equatable {
        case starting
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
    /// Bumped by `stopSpeaking` so a translation in flight is discarded instead of spoken.
    private var cancelGeneration = 0

    var isMuted: Bool { listener.isMuted }

    func start() async {
        translator.checkAvailability()
        speaker.prepare()

        listener.onUtterance = { [weak self] text in
            self?.handleUtterance(text)
        }
        await listener.start()
        refreshPhase()
    }

    func stop() {
        listener.stop()
        speaker.stop()
    }

    /// Mutes or unmutes the microphone. Muting mid-sentence drops that sentence.
    func toggleMute() {
        listener.setMuted(!listener.isMuted)
        if !isProcessing { refreshPhase() }
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

    // MARK: Voice

    /// Picks the voice Corpospeak speaks with, from the voice menu.
    func selectVoice(id: String) {
        speaker.select(voiceID: id)
    }

    /// Asks the system to let Corpospeak use the Personal Voice.
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

    // MARK: Pipeline

    private func handleUtterance(_ text: String) {
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

        listener.resume()
        refreshPhase()
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
                phase = .error("No voice is available. Check the voice menu.")
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
        } else if listener.status == .muted {
            phase = .muted
        } else if listener.status == .listening {
            phase = .listening
        }
    }
}
