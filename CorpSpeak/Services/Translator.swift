import Foundation
import FoundationModels
import Observation

enum TranslationDirection: CaseIterable {
    case englishToCorpSpeak
    case corpSpeakToEnglish

    var instructions: String {
        switch self {
        case .englishToCorpSpeak: CorpSpeakStyle.englishToCorpSpeakInstructions
        case .corpSpeakToEnglish: CorpSpeakStyle.corpSpeakToEnglishInstructions
        }
    }

    var label: String {
        switch self {
        case .englishToCorpSpeak: "English → CorpSpeak"
        case .corpSpeakToEnglish: "CorpSpeak → English"
        }
    }
}

/// Rewrites text with the on-device Apple Intelligence model.
@MainActor
@Observable
final class Translator {
    enum Availability: Equatable {
        case checking
        case available
        case unavailable(String)
    }

    private(set) var availability: Availability = .checking

    func checkAvailability() {
        switch SystemLanguageModel.default.availability {
        case .available:
            availability = .available
        case .unavailable(let reason):
            availability = .unavailable(Self.describe(reason))
        }
    }

    func translate(_ text: String, direction: TranslationDirection) async throws -> String {
        // A fresh session per utterance keeps each rewrite independent of the last.
        let session = LanguageModelSession(instructions: direction.instructions)
        let prompt = """
            Rewrite the text between the markers. Reply with the rewritten text only.

            <<<
            \(text)
            >>>
            """
        do {
            let response = try await session.respond(
                to: prompt,
                options: GenerationOptions(temperature: 0.6, maximumResponseTokens: 200)
            )
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            throw TranslationError.tooLong
        }
    }

    enum TranslationError: LocalizedError {
        case tooLong

        var errorDescription: String? {
            switch self {
            case .tooLong: "That was too long for the on-device model. Try a shorter sentence."
            }
        }
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "This Mac does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is turned off. Enable it in System Settings → Apple Intelligence & Siri."
        case .modelNotReady:
            "The on-device model is still downloading. Try again in a few minutes."
        @unknown default:
            "The on-device model is unavailable."
        }
    }
}
