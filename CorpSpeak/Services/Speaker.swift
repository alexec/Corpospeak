import AVFoundation
import Foundation
import Observation

/// Reads text aloud. `speak` suspends until the utterance has finished (or been cancelled).
@MainActor
@Observable
final class Speaker {
    struct VoiceOption: Identifiable, Hashable {
        enum Tier: Int, Comparable, CaseIterable {
            case premium, enhanced, standard, novelty

            static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

            var title: String {
                switch self {
                case .premium: "Premium"
                case .enhanced: "Enhanced"
                case .standard: "Standard"
                case .novelty: "Novelty"
                }
            }
        }

        let id: String
        let name: String
        let tier: Tier

        init(_ voice: AVSpeechSynthesisVoice) {
            id = voice.identifier
            let region = voice.language.split(separator: "-").last.map(String.init) ?? ""
            name = region.isEmpty || region == "US" ? voice.name : "\(voice.name) (\(region))"
            tier = switch voice.quality {
            case .premium: .premium
            case .enhanced: .enhanced
            default: voice.identifier.hasPrefix("com.apple.voice.") ? .standard : .novelty
            }
        }
    }

    private(set) var isSpeaking = false
    private(set) var voice: AVSpeechSynthesisVoice?
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SynthesizerDelegate()
    private static let selectedVoiceKey = "selectedVoiceIdentifier"

    init() {
        synthesizer.delegate = delegate
        if let saved = UserDefaults.standard.string(forKey: Self.selectedVoiceKey),
           let savedVoice = AVSpeechSynthesisVoice(identifier: saved) {
            voice = savedVoice
        } else {
            voice = Self.bestEnglishVoice()
        }
    }

    var voiceIdentifier: String { voice?.identifier ?? "" }

    func select(voiceIdentifier: String) {
        guard let chosen = AVSpeechSynthesisVoice(identifier: voiceIdentifier) else { return }
        voice = chosen
        UserDefaults.standard.set(voiceIdentifier, forKey: Self.selectedVoiceKey)
    }

    func speak(_ text: String) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        stop()
        isSpeaking = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            delegate.onFinish = { [delegate] in
                delegate.onFinish = nil
                continuation.resume()
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = rate
            synthesizer.speak(utterance)
        }
        isSpeaking = false
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: Voices

    /// Every English voice installed right now, best first. Re-queried on each call so voices
    /// downloaded while the app is running show up.
    static func availableVoices() -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .map(VoiceOption.init)
            .sorted { ($0.tier, $0.name) < ($1.tier, $1.name) }
    }

    /// Picks the highest-quality English voice available: Premium, then Enhanced, then the
    /// standard system voices. Novelty and Eloquence voices are ranked last. Premium and
    /// Enhanced voices are installed from System Settings → Accessibility → Read & Speak →
    /// System Voice → Manage Voices.
    static func bestEnglishVoice() -> AVSpeechSynthesisVoice? {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en-US"

        func score(_ voice: AVSpeechSynthesisVoice) -> (Int, Int, Int) {
            let quality: Int = switch voice.quality {
            case .premium: 3
            case .enhanced: 2
            default: 1
            }
            let family = voice.identifier.hasPrefix("com.apple.voice.") ? 1 : 0
            let locale = voice.language == preferredLanguage ? 2 : (voice.language == "en-US" ? 1 : 0)
            return (quality, family, locale)
        }

        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .max { score($0) < score($1) }
            ?? AVSpeechSynthesisVoice(language: "en-US")
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
