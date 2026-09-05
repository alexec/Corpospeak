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
    /// Its Corpospeak rendering, growing as the model writes it.
    private(set) var translated = ""
    /// Counts replies, so views can tell a new reply from the current one growing.
    private(set) var replyID = 0

    private enum Job {
        case utterance(String)
    }

    private var pending: [Job] = []
    private var isProcessing = false
    /// Bumped by `stopSpeaking` so a translation in flight is discarded instead of spoken.
    private var cancelGeneration = 0
    /// Returns the display to the listener's state a few seconds after a failed translation,
    /// so the message can be read first.
    private var errorDismissal: Task<Void, Never>?

    var isMuted: Bool { listener.isMuted }

    func start() async {
        translator.checkAvailability()
        translator.prewarm()
        speaker.prepare()

        listener.onUtterance = { [weak self] text in
            self?.handleUtterance(text)
        }
        await listener.start()
        refreshPhase()
        // Ask to use the Personal Voice on first launch, after the microphone prompts: the app
        // is at its best in the user's own voice, and once allowed it becomes the default.
        await speaker.requestAuthorizationIfNeeded()
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

    /// Switches to the user's Personal Voice, if one is available.
    func selectPersonalVoice() {
        guard let voice = speaker.personalVoiceOptions.first else { return }
        speaker.select(voiceID: voice.id)
    }

    /// True when the device supports a Personal Voice but Corpospeak isn't speaking with one yet:
    /// permission not asked or refused, no voice created, or a system voice picked instead.
    var canImprovePersonalVoice: Bool {
        switch speaker.personalVoiceStatus {
        case .checking, .unsupported: false
        case .notDetermined, .denied, .noVoice: true
        case .available: speaker.selectedVoice?.isPersonalVoice != true
        }
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
        // Background noise makes the recogniser produce the odd stray word ("you", "hmm"). One
        // word is not a sentence to translate, so it is dropped rather than sent to the model,
        // which would have nothing to say about it.
        guard text.split(whereSeparator: \.isWhitespace).count >= 2 else { return }
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
        if case .error = phase {
            // Leave the message up long enough to read, then show the listener's state again.
            errorDismissal?.cancel()
            errorDismissal = Task { [weak self] in
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled, let self, !self.isProcessing else { return }
                self.refreshPhase()
            }
        } else {
            refreshPhase()
        }
    }

    private func process(_ text: String) async {
        heard = text
        translated = ""
        replyID += 1

        // The model can come and go while the app runs (a system update re-downloading it,
        // Apple Intelligence switched off), so look again rather than trusting launch time.
        translator.checkAvailability()
        if case .unavailable(let why) = translator.availability {
            phase = .error(why)
            return
        }

        phase = .translating
        let generation = cancelGeneration
        // Each sentence goes to the speaker as soon as it is complete, so speech starts while
        // the model is still writing the rest.
        let (sentences, feed) = AsyncStream<String>.makeStream()
        let speaking = Task { await speaker.speak(sentences) }
        var splitter = SentenceStreamer()
        do {
            for try await partial in translator.translate(text) {
                guard generation == cancelGeneration else { break }
                translated = partial
                for sentence in splitter.take(from: partial) {
                    phase = .speaking
                    feed.yield(sentence)
                }
            }
            if generation == cancelGeneration {
                for sentence in splitter.finish(with: translated) {
                    phase = .speaking
                    feed.yield(sentence)
                }
            }
            feed.finish()
            let spoke = await speaking.value
            if generation == cancelGeneration {
                if !spoke {
                    phase = .error("No voice is available. Check the voice menu.")
                } else if translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Nothing was spoken, so say why rather than bouncing straight back to
                    // listening as if nothing happened.
                    phase = .error("The model came back with nothing for that. Try again.")
                }
            }
        } catch {
            feed.finish()
            speaker.stop()
            if generation == cancelGeneration {
                phase = .error(error.localizedDescription)
            }
        }
        // The model is free again: get the next session ready while the user talks.
        translator.prewarm()
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

/// Hands out the sentences of a reply that is still being written, each as soon as it is
/// complete, so they can be spoken before the reply is finished.
private struct SentenceStreamer {
    private var delivered = 0

    /// A first line shaping up to be "Certainly! Here is the rewritten text:" rather than the
    /// reply. `Translator` drops such a line once the real reply starts on the next line; until
    /// then nothing is delivered, so it is never spoken.
    private static let preamble = try! NSRegularExpression(
        pattern: "^(certainly|sure|absolutely|of course|okay|here('s| is| are))\\b",
        options: .caseInsensitive
    )

    /// The sentences completed by `partial` that have not been handed out yet. A sentence counts
    /// as complete once the one after it has started.
    mutating func take(from partial: String) -> [String] {
        guard !partial.isEmpty else { return [] }
        if !partial.contains("\n"),
           Self.preamble.firstMatch(in: partial, range: NSRange(partial.startIndex..., in: partial)) != nil {
            return []
        }
        return deliver(Array(Speaker.split(partial).dropLast()))
    }

    /// Whatever is left once the reply is finished, including its last sentence.
    mutating func finish(with text: String) -> [String] {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return deliver(Speaker.split(text))
    }

    private mutating func deliver(_ sentences: [String]) -> [String] {
        guard sentences.count > delivered else { return [] }
        defer { delivered = sentences.count }
        return Array(sentences[delivered...])
    }
}
