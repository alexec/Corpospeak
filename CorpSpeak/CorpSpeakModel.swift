import Foundation
import Observation

/// Wires the services together: listen → translate → speak → listen.
/// On first launch, before any of that, it records the user's voice for cloning.
@MainActor
@Observable
final class CorpSpeakModel {
    enum Phase: Equatable {
        case starting
        case enrolling
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
    /// Its CorpSpeak rendering.
    private(set) var translated = ""
    /// Shown during enrollment when a take was not usable.
    private(set) var enrollmentHint = ""

    private enum Job {
        case utterance(String)
        case voicePreview
    }

    private var pending: [Job] = []
    private var isProcessing = false
    private var isEnrolling = false
    /// Bumped by `stopSpeaking` so a translation in flight is discarded instead of spoken.
    private var cancelGeneration = 0
    private static let normalSilence: TimeInterval = 2.0
    private static let enrollmentSilence: TimeInterval = 2.5

    var isMuted: Bool { listener.isMuted }

    func start() async {
        translator.checkAvailability()

        // Fetch and load the voice models in the background; listening does not wait for them.
        Task { await speaker.prepare() }

        listener.onUtterance = { [weak self] text in
            self?.handleUtterance(text)
        }
        await listener.start()

        if listener.status == .listening || listener.status == .muted, !speaker.hasOwnVoice {
            beginEnrollment()
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

    // MARK: Enrollment

    /// Asks the user to read the phrase and records it. Also used to re-record later.
    func beginEnrollment() {
        guard listener.status != .idle else { return }
        if case .unavailable = listener.status { return }
        listener.setMuted(false)
        speaker.stop()
        pending.removeAll()
        isEnrolling = true
        enrollmentHint = ""
        heard = ""
        translated = ""
        listener.silenceInterval = Self.enrollmentSilence
        listener.resume()
        listener.startCapture()
        phase = .enrolling
    }

    private func finishEnrollment(heard text: String) {
        let sample = listener.stopCapture()?.trimmed()
        let match = VoiceSample.match(text)
        let duration = sample?.duration ?? 0
        guard let sample, match >= 0.6, duration >= 3, duration <= 20 else {
            if match < 0.6 {
                enrollmentHint = "That didn't sound like the phrase. Once more, from the top."
            } else if duration < 3 {
                enrollmentHint = "That was too short. Once more, a little slower."
            } else {
                enrollmentHint = "That ran long. Once more, in one go."
            }
            listener.startCapture()
            return
        }

        isEnrolling = false
        listener.silenceInterval = Self.normalSilence
        speaker.enroll(sample)
        enrollmentHint = ""
        enqueue(.voicePreview)
    }

    // MARK: Pipeline

    private func handleUtterance(_ text: String) {
        if isEnrolling {
            finishEnrollment(heard: text)
        } else {
            enqueue(.utterance(text))
        }
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
            case .voicePreview:
                phase = .speaking
                _ = await speaker.speak("Great news. We're ready to turn plain English into speech suitable for any of your upcoming presentations or meetings.")
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
                phase = .error(speaker.hasOwnVoice
                    ? "The voice model isn't ready. Check the voice menu."
                    : "Record your voice first.")
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
        } else if isEnrolling {
            phase = .enrolling
        } else if listener.status == .muted {
            phase = .muted
        } else if listener.status == .listening {
            phase = .listening
        }
    }
}
