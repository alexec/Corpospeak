import AVFoundation
import Foundation

/// The recording of the user reading the enrollment phrase, used as the cloning reference.
struct VoiceSample {
    /// What the user is asked to read. ZipVoice needs the transcript of the reference audio.
    static let phrase = "Thanks for making time for this sync. I know the timeline slipped, so let's zoom out, get aligned on the big picture, and land the plane by Friday."

    let samples: [Float]
    let sampleRate: Double

    var duration: TimeInterval { Double(samples.count) / sampleRate }

    static func fileURL(in root: URL) -> URL {
        root.appendingPathComponent("voice-sample.wav")
    }

    /// Records which phrase the sample was read from, so a changed phrase invalidates it.
    private static func transcriptURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("txt")
    }

    // MARK: Persistence

    /// Loads a saved sample, or nil if there is none or it was read from a different phrase.
    static func load(from url: URL) -> VoiceSample? {
        guard let transcript = try? String(contentsOf: transcriptURL(for: url), encoding: .utf8),
              transcript.trimmingCharacters(in: .whitespacesAndNewlines) == phrase
        else { return nil }
        guard let file = try? AVAudioFile(forReading: url),
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil,
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        return VoiceSample(samples: samples, sampleRate: file.fileFormat.sampleRate)
    }

    func save(to url: URL) throws {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: url)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { throw CocoaError(.fileWriteUnknown) }
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ], commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
        try Self.phrase.write(to: Self.transcriptURL(for: url), atomically: true, encoding: .utf8)
    }

    // MARK: Cleanup

    /// Cuts leading and trailing silence, keeping a short margin, and normalises the level.
    func trimmed() -> VoiceSample {
        let window = max(1, Int(sampleRate * 0.02))
        let threshold: Float = 0.012
        var first: Int?
        var last: Int?
        var start = 0
        while start < samples.count {
            let end = min(start + window, samples.count)
            var energy: Float = 0
            for i in start..<end { energy += samples[i] * samples[i] }
            let rms = (energy / Float(end - start)).squareRoot()
            if rms > threshold {
                if first == nil { first = start }
                last = end
            }
            start = end
        }
        guard let first, let last, last > first else { return self }
        let margin = Int(sampleRate * 0.25)
        let range = max(0, first - margin)..<min(samples.count, last + margin)
        var cut = Array(samples[range])
        let peak = cut.map(abs).max() ?? 0
        if peak > 0 {
            let gain = min(0.9 / peak, 4)
            for i in cut.indices { cut[i] *= gain }
        }
        return VoiceSample(samples: cut, sampleRate: sampleRate)
    }

    // MARK: Transcript check

    /// How much of the phrase the recogniser heard, 0…1, by word overlap.
    static func match(_ heard: String, against phrase: String = phrase) -> Double {
        func words(_ text: String) -> [String] {
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        }
        let expected = words(phrase)
        let got = Set(words(heard))
        guard !expected.isEmpty else { return 0 }
        return Double(expected.filter { got.contains($0) }.count) / Double(expected.count)
    }
}
