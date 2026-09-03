import Foundation
import Observation

/// Wires the services together: listen → translate → speak → listen.
@MainActor
@Observable
final class CorpSpeakModel {
    enum Phase: Equatable {
        case starting
        case listening
        case translating
        case speaking
        case error(String)
    }

    let listener = SpeechListener()
    let translator = Translator()
    let speaker = Speaker()

    /// Only one direction for now. Flip this to go the other way.
    let direction: TranslationDirection = .englishToCorpSpeak

    private(set) var phase: Phase = .starting

    /// The last thing the user said.
    private(set) var heard = ""
    /// Its CorpSpeak rendering.
    private(set) var translated = ""

    private enum Job {
        case utterance(String)
        case voicePreview
    }

    private var pending: [Job] = []
    private var isProcessing = false

    func start() async {
        translator.checkAvailability()

        listener.onUtterance = { [weak self] text in
            self?.enqueue(.utterance(text))
        }
        await listener.start()

        refreshPhase()
    }

    func stop() {
        listener.stop()
        speaker.stop()
    }

    /// Switches voices and reads a short line in the new voice.
    func selectVoice(_ identifier: String) {
        guard identifier != speaker.voiceIdentifier else { return }
        speaker.select(voiceIdentifier: identifier)
        enqueue(.voicePreview)
    }

    // MARK: Pipeline

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
            case .voicePreview:
                phase = .speaking
                await speaker.speak("Let's circle back on that.")
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
        do {
            translated = try await translator.translate(text, direction: direction)
            phase = .speaking
            await speaker.speak(translated)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func refreshPhase() {
        if case .unavailable(let why) = listener.status {
            phase = .error(why)
        } else if case .unavailable(let why) = translator.availability {
            phase = .error(why)
        } else if listener.status == .listening {
            phase = .listening
        }
    }
}
