import AVFoundation
import Foundation

/// Mono float PCM audio produced by a synthesizer.
struct AudioClip {
    let samples: [Float]
    let sampleRate: Int
}

/// Plays raw mono float PCM through the default output. `play` suspends until playback ends.
@MainActor
final class AudioPlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var connectedSampleRate: Double = 0

    init() {
        engine.attach(node)
    }

    func play(_ clip: AudioClip) async {
        guard !clip.samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: Double(clip.sampleRate), channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(clip.samples.count))
        else { return }

        clip.samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: clip.samples.count)
        }
        buffer.frameLength = AVAudioFrameCount(clip.samples.count)

        if connectedSampleRate != format.sampleRate {
            engine.disconnectNodeOutput(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            connectedSampleRate = format.sampleRate
        }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }

        let done = Resumer()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            done.continuation = continuation
            node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
                done.resume()
            }
            node.play()
        }
    }

    /// Stops playback. Any pending `play` returns promptly.
    func stop() {
        node.stop()
    }
}

/// Guards a continuation so it resumes exactly once, from whichever thread AVFoundation uses.
private final class Resumer: @unchecked Sendable {
    private let lock = NSLock()
    var continuation: CheckedContinuation<Void, Never>?

    func resume() {
        lock.withLock {
            continuation?.resume()
            continuation = nil
        }
    }
}
