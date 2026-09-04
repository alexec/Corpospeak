import Foundation
import SherpaOnnx

/// Zero-shot voice cloning with ZipVoice through sherpa-onnx: given a few seconds of someone
/// speaking and the transcript, speaks new text in that voice.
actor ZipVoiceSynthesizer {
    private let modelDirectory: URL
    private let vocoder: URL
    private var tts: SherpaOnnxOfflineTtsWrapper?

    init(modelDirectory: URL, vocoder: URL) {
        self.modelDirectory = modelDirectory
        self.vocoder = vocoder
    }

    func warmUp() throws {
        _ = try engine()
    }

    func synthesize(_ text: String, reference: VoiceSample, speed: Float = 1.0) throws -> AudioClip {
        let tts = try engine()
        var config = SherpaOnnxGenerationConfigSwift()
        config.speed = speed
        config.referenceAudio = reference.samples
        config.referenceSampleRate = Int(reference.sampleRate)
        config.referenceText = VoiceSample.phrase
        config.numSteps = 4
        let audio = tts.generateWithConfig(text: text, config: config, callback: nil, arg: nil)
        // The wrapper force-unwraps its pointer; generation can legitimately return nothing.
        guard audio.audio != nil, audio.n > 0 else { throw SynthesisError.nothingGenerated }
        return AudioClip(samples: audio.samples, sampleRate: Int(audio.sampleRate))
    }

    private func engine() throws -> SherpaOnnxOfflineTtsWrapper {
        if let tts { return tts }
        let dir = modelDirectory
        let path = { (name: String) in dir.appendingPathComponent(name).path }
        guard FileManager.default.fileExists(atPath: path("decoder.int8.onnx")),
              FileManager.default.fileExists(atPath: vocoder.path)
        else { throw SynthesisError.modelMissing }
        let zipvoice = sherpaOnnxOfflineTtsZipvoiceModelConfig(
            tokens: path("tokens.txt"),
            encoder: path("encoder.int8.onnx"),
            decoder: path("decoder.int8.onnx"),
            vocoder: vocoder.path,
            dataDir: path("espeak-ng-data"),
            lexicon: path("lexicon.txt")
        )
        let threads = max(2, min(6, ProcessInfo.processInfo.activeProcessorCount / 2))
        let model = sherpaOnnxOfflineTtsModelConfig(numThreads: threads, debug: 0, zipvoice: zipvoice)
        var config = sherpaOnnxOfflineTtsConfig(model: model)
        let created = SherpaOnnxOfflineTtsWrapper(config: &config)
        // The wrapper does not check the C handle; a failed load would crash on first use.
        guard created.tts != nil else { throw SynthesisError.failedToLoad }
        tts = created
        return created
    }

    enum SynthesisError: LocalizedError {
        case modelMissing
        case failedToLoad
        case nothingGenerated

        var errorDescription: String? {
            switch self {
            case .modelMissing: "The voice cloning model is not installed."
            case .failedToLoad: "The voice cloning model could not be loaded."
            case .nothingGenerated: "The voice model produced no audio for that sentence."
            }
        }
    }
}
