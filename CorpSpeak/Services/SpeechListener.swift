import AVFoundation
import Foundation
import Observation
import Speech

/// Always-on, on-device dictation.
///
/// Keeps the microphone open for the life of the app and feeds it to `SFSpeechRecognizer`.
/// Each time the speaker pauses for `silenceInterval`, the text heard so far is delivered
/// through `onUtterance` and a fresh recognition task is started.
@MainActor
@Observable
final class SpeechListener {
    enum Status: Equatable {
        case idle
        case listening
        case paused
        case muted
        case unavailable(String)
    }

    enum ListenerError: LocalizedError {
        case noInputDevice

        var errorDescription: String? {
            switch self {
            case .noInputDevice: "No microphone input device was found."
            }
        }
    }

    private(set) var status: Status = .idle

    /// Text recognised so far for the utterance currently being spoken.
    private(set) var liveTranscript = ""

    /// Called on the main actor once per completed utterance.
    var onUtterance: ((String) -> Void)?

    /// Microphone loudness, 0…1, smoothed. Updated ~30 times a second while the mic is open.
    private(set) var audioLevel: Float = 0

    /// How long the speaker must be quiet before the utterance is treated as finished.
    var silenceInterval: TimeInterval = 2.0

    /// When the current utterance will be treated as finished if nothing more is heard.
    /// Nil while nothing has been heard yet.
    private(set) var silenceDeadline: Date?

    /// True while the user has muted the microphone. Nothing is recognised until unmuted.
    private(set) var isMuted = false

    private let audioEngine = AVAudioEngine()
    private let feed = AudioFeed()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var silenceTask: Task<Void, Never>?
    private var levelTask: Task<Void, Never>?
    private var generation = 0
    private var wantsListening = false
    private var isPaused = false

    // MARK: Lifecycle

    /// Requests permissions, opens the microphone, and starts recognising.
    func start() async {
        guard !wantsListening else { return }

        guard await requestSpeechAuthorization() == .authorized else {
            status = .unavailable("Speech Recognition permission was not granted. Enable it in System Settings → Privacy & Security.")
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            status = .unavailable("Microphone permission was not granted. Enable it in System Settings → Privacy & Security.")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(),
              recognizer.isAvailable
        else {
            status = .unavailable("No speech recogniser is available for this locale.")
            return
        }
        self.recognizer = recognizer

        do {
            try startAudioEngine()
        } catch {
            status = .unavailable("Could not start the microphone: \(error.localizedDescription)")
            return
        }

        wantsListening = true
        isPaused = false
        beginRecognition()
        startLevelMonitor()
    }

    func stop() {
        wantsListening = false
        levelTask?.cancel()
        levelTask = nil
        audioLevel = 0
        endRecognition()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        liveTranscript = ""
        status = .idle
    }

    /// Stops recognising without releasing the microphone, e.g. while the app is talking
    /// so it does not transcribe its own voice.
    func pause() {
        guard wantsListening, !isPaused else { return }
        isPaused = true
        endRecognition()
        liveTranscript = ""
        status = .paused
    }

    func resume() {
        guard wantsListening, isPaused else { return }
        isPaused = false
        if isMuted {
            status = .muted
        } else {
            beginRecognition()
        }
    }

    /// Mutes or unmutes. Muting drops the current utterance; unmuting starts fresh.
    func setMuted(_ muted: Bool) {
        guard muted != isMuted else { return }
        isMuted = muted
        guard wantsListening else { return }
        if muted {
            endRecognition()
            liveTranscript = ""
            status = .muted
        } else if !isPaused {
            beginRecognition()
        } else {
            status = .paused
        }
    }

    // MARK: Raw capture (for voice enrollment)

    /// Starts keeping the raw microphone audio, in addition to feeding the recogniser.
    func startCapture() {
        feed.startCapture()
    }

    /// Stops keeping raw audio and returns what was captured since `startCapture`.
    func stopCapture() -> VoiceSample? {
        let (samples, rate) = feed.stopCapture()
        guard !samples.isEmpty, rate > 0 else { return nil }
        return VoiceSample(samples: samples, sampleRate: rate)
    }

    // MARK: Audio

    private func startAudioEngine() throws {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw ListenerError.noInputDevice }

        let feed = self.feed
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            feed.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func startLevelMonitor() {
        levelTask?.cancel()
        levelTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard let self else { return }
                let target = self.feed.level
                // Rise quickly, fall slowly, so the meter feels alive without flickering.
                let smoothed = target > self.audioLevel
                    ? self.audioLevel + (target - self.audioLevel) * 0.6
                    : self.audioLevel * 0.85
                self.audioLevel = smoothed < 0.005 ? 0 : smoothed
            }
        }
    }

    // MARK: Recognition

    private func beginRecognition() {
        guard let recognizer, wantsListening, !isPaused, !isMuted else { return }
        endRecognition()
        let thisGeneration = generation

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        feed.request = request

        liveTranscript = ""
        status = .listening

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handle(result: result, error: error, generation: thisGeneration)
            }
        }
    }

    /// Tears down the current task. Bumps `generation` so late callbacks from it are ignored.
    private func endRecognition() {
        generation += 1
        silenceTask?.cancel()
        silenceTask = nil
        silenceDeadline = nil
        feed.request = nil
        task?.cancel()
        task = nil
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?, generation: Int) {
        guard generation == self.generation else { return }

        if let result {
            let text = result.bestTranscription.formattedString
            if text != liveTranscript {
                if liveTranscript.isEmpty, !text.isEmpty {
                    feed.markSpeechStart(marginSeconds: 0.7)
                }
                liveTranscript = text
                restartSilenceTimer()
            }
            if result.isFinal {
                finishUtterance()
                return
            }
        }

        if error != nil {
            // Tasks end on their own: no speech for a while, the ~1 minute per-task limit, or
            // a transient recogniser failure. Deliver whatever was heard and start again.
            if liveTranscript.isEmpty {
                endRecognition()
                scheduleRestart()
            } else {
                finishUtterance()
            }
        }
    }

    private func restartSilenceTimer() {
        silenceTask?.cancel()
        let thisGeneration = generation
        let interval = silenceInterval
        silenceDeadline = Date().addingTimeInterval(interval)
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, let self, thisGeneration == self.generation else { return }
            self.finishUtterance()
        }
    }

    private func finishUtterance() {
        let text = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        endRecognition()
        liveTranscript = ""
        if !text.isEmpty {
            onUtterance?(text)
        }
        // The utterance handler may have paused us. If not, keep going.
        if !isPaused {
            beginRecognition()
        }
    }

    private func scheduleRestart() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.beginRecognition()
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }
}

/// Hands microphone buffers (which arrive on a realtime audio thread) to whichever
/// recognition request is current.
private final class AudioFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var current: SFSpeechAudioBufferRecognitionRequest?
    private var latestLevel: Float = 0
    private var capturing = false
    private var captured: [Float] = []
    private var captureRate: Double = 0

    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    /// Loudness of the most recent buffer, 0…1.
    var level: Float {
        lock.withLock { latestLevel }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        let level = Self.normalizedLevel(of: buffer)
        lock.withLock {
            current?.append(buffer)
            latestLevel = level
            if capturing, let channel = buffer.floatChannelData?[0] {
                captured.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
                captureRate = buffer.format.sampleRate
            }
        }
    }

    private var speechStart: Int?

    func startCapture() {
        lock.withLock {
            captured.removeAll(keepingCapacity: true)
            speechStart = nil
            capturing = true
        }
    }

    /// Remembers where speech began so the capture can be cut there, keeping a short margin.
    /// Only the first call per capture counts.
    func markSpeechStart(marginSeconds: Double) {
        lock.withLock {
            guard capturing, speechStart == nil else { return }
            speechStart = max(0, captured.count - Int(marginSeconds * captureRate))
        }
    }

    /// Returns the audio from where speech began (or the whole capture if it never did).
    func stopCapture() -> ([Float], Double) {
        lock.withLock {
            capturing = false
            defer { captured = []; speechStart = nil }
            let start = speechStart ?? 0
            return (Array(captured[start...]), captureRate)
        }
    }

    /// RMS of the first channel, mapped from roughly -50 dBFS…0 dBFS onto 0…1.
    private static func normalizedLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count {
            let sample = samples[i]
            sum += sample * sample
        }
        let rms = (sum / Float(count)).squareRoot()
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        return min(max((decibels + 50) / 50, 0), 1)
    }
}
