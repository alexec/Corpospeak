import AVFoundation
import Foundation
import Observation

/// Speaks with Kokoro, a sentence at a time.
///
/// Kokoro synthesizes a whole utterance at once, so there is no token-by-token audio to stream
/// the way the rewrite itself streams. What there is instead: the text arrives here already cut
/// into sentences, and sentence N+1 is synthesized while sentence N is still playing. Speech
/// starts after the first short sentence rather than after the whole reply, which is the part
/// the user actually feels.
///
/// This file deliberately knows nothing about which model is behind `SpeechSynthesizing`.
@MainActor
@Observable
final class KokoroEngine {
    /// True once the model is loaded and Kokoro can be spoken with.
    private(set) var isReady = false

    private var synthesizer: (any SpeechSynthesizing)?
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat?
    private var isRunning = false
    private var generation = 0
    private var current: KokoroPlayback?

    /// Loads the model, off the main thread. Safe to call more than once; does nothing where
    /// Kokoro can't run, leaving the app on Apple's voices.
    func prepare() async {
        guard synthesizer == nil else { return }
        guard KokoroSynthesizer.isSupportedHere else {
            note("Kokoro off: this OS build can crash in libBNNS")
            return
        }
        let started = Date()
        let loaded = await Task.detached(priority: .utility) { () -> (any SpeechSynthesizing)? in
            do {
                let synthesizer = try KokoroSynthesizer()
                try await synthesizer.load()
                return synthesizer
            } catch {
                note("Kokoro failed to load: \(error)")
                return nil
            }
        }.value
        note(loaded == nil
            ? "Kokoro unavailable"
            : String(format: "Kokoro ready in %.1fs", Date().timeIntervalSince(started)))
        guard let loaded,
              let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: loaded.sampleRate,
                channels: 1,
                interleaved: false)
        else { return }
        synthesizer = loaded
        self.format = format
        isReady = true
    }

    /// Speaks sentences as they arrive, reporting the index of the one that starts playing.
    /// Returns once the last sentence has finished, or false if Kokoro couldn't speak at all —
    /// in which case the caller falls back to a system voice rather than saying nothing.
    @discardableResult
    func speak(
        _ sentences: AsyncStream<String>,
        onSentenceStart: @MainActor @escaping (Int) -> Void
    ) async -> Bool {
        guard isReady, let synthesizer, let format, start() else { return false }

        generation += 1
        let thisGeneration = generation
        let playback = KokoroPlayback()
        current = playback

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            playback.onFinish = { continuation.resume() }

            Task { @MainActor [weak self] in
                var index = 0
                for await sentence in sentences {
                    guard let self, self.generation == thisGeneration else { break }
                    // Synthesis is the slow part, so it happens off the main thread while
                    // whatever is already queued keeps playing.
                    let samples = await Task.detached(priority: .userInitiated) {
                        try? await synthesizer.synthesize(sentence)
                    }.value
                    guard self.generation == thisGeneration else { break }
                    guard let samples, !samples.isEmpty,
                          let buffer = Self.buffer(samples, format: format)
                    else {
                        // A sentence the model refused isn't worth stopping the reply for.
                        index += 1
                        continue
                    }
                    playback.queued.append(index)
                    // The first sentence is playing the moment it is handed over; the rest
                    // start as the one in front of them finishes.
                    if playback.queued.count == 1 { onSentenceStart(index) }
                    // The player runs its queue back to back, so scheduling ahead of playback
                    // is what keeps one sentence from clipping into the next.
                    self.player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
                        Task { @MainActor [weak self] in
                            guard let self, self.generation == thisGeneration else { return }
                            playback.played += 1
                            if let next = playback.nowPlaying { onSentenceStart(next) }
                            if playback.isComplete { playback.complete() }
                        }
                    }
                    index += 1
                }
                guard let self, self.generation == thisGeneration else { return }
                playback.ended = true
                if playback.isComplete { playback.complete() }
            }
        }
        current = nil
        return true
    }

    /// Stops playback. Any pending `speak` returns promptly.
    func stop() {
        generation += 1
        if isRunning { player.stop() }
        current?.complete()
        current = nil
    }

    // MARK: Audio

    /// Starts the audio engine on first use. The iOS audio session is already configured for
    /// playback alongside the microphone, in `AudioSession`.
    private func start() -> Bool {
        guard let format else { return false }
        if isRunning {
            if !player.isPlaying { player.play() }
            return true
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            return false
        }
        player.play()
        isRunning = true
        return true
    }

    private static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel.update(from: base, count: samples.count)
        }
        return buffer
    }
}

/// Says what happened to Kokoro, on a device where there is no other way to see it — the first
/// load costs minutes of one-time Core ML compilation, and a failure is otherwise silent. Read it
/// with `xcrun devicectl device process launch --console`. Debug builds only.
private func note(_ message: String) {
    #if DEBUG
    FileHandle.standardError.write(Data(("[corpospeak] " + message + "\n").utf8))
    #endif
}

/// How far through one `speak` call playback has got.
@MainActor
private final class KokoroPlayback {
    /// The sentence index behind each buffer handed to the player, in the order they play.
    var queued: [Int] = []
    var played = 0
    /// True once the last sentence has been handed to the player.
    var ended = false
    var onFinish: (() -> Void)?

    /// The sentence now playing, once the one before it has finished.
    var nowPlaying: Int? { played < queued.count ? queued[played] : nil }

    var isComplete: Bool { ended && played == queued.count }

    /// Resumes whoever is waiting on this playback, exactly once.
    func complete() {
        onFinish?()
        onFinish = nil
    }
}
