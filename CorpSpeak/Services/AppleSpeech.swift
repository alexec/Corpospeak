import AVFoundation
import Foundation

/// Apple's built-in synthesizer. Used only until the cloning model and a recording exist.
@MainActor
final class AppleSpeech {
    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SynthesizerDelegate()
    private let voice: AVSpeechSynthesisVoice?

    init() {
        synthesizer.delegate = delegate
        voice = Self.bestVoice()
    }

    func speak(_ text: String) async {
        stop()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            delegate.onFinish = { [delegate] in
                delegate.onFinish = nil
                continuation.resume()
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    /// The best-quality English system voice installed, preferring the user's locale.
    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && $0.identifier.hasPrefix("com.apple.voice.") }
        return candidates.max { a, b in
            (a.quality.rawValue, a.language == preferred ? 1 : 0) < (b.quality.rawValue, b.language == preferred ? 1 : 0)
        } ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

private final class SynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onFinish?() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onFinish?() }
    }
}
