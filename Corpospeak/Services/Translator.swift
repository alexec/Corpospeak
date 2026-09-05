import Foundation
import FoundationModels
import Observation
import os

/// Rewrites text with the on-device Apple Intelligence model.
///
/// Two things keep it quick. The instructions are most of every prompt, so a session is
/// prepared while the app is idle (`prewarm`) and the model reads them before the user has
/// finished talking. And the reply is streamed (`translate`) so the first sentence can be spoken
/// while the rest is still being written.
@MainActor
@Observable
final class Translator {
    enum Availability: Equatable {
        case checking
        case available
        case unavailable(String)
    }

    private(set) var availability: Availability = .checking

    /// A session that has already loaded the model and read the instructions, waiting for the
    /// next utterance.
    @ObservationIgnored private var warmSession: LanguageModelSession?

    private static let logger = Logger(subsystem: "com.alexcollins.CorpSpeak", category: "Translator")
    private static let promptPrefix = "Rewrite the text between the markers. Reply with the rewritten text only.\n\n<<<\n"

    func checkAvailability() {
        switch SystemLanguageModel.default.availability {
        case .available:
            availability = .available
        case .unavailable(let reason):
            availability = .unavailable(Self.describe(reason))
        }
    }

    /// Gets a session ready for the next utterance while the model is otherwise idle: loads it
    /// and has it read the instructions and the fixed start of the prompt, so that once the user
    /// stops talking only their own words are left to process. Safe to call often.
    func prewarm() {
        guard availability == .available, warmSession == nil else { return }
        let session = Self.makeSession()
        session.prewarm(promptPrefix: Prompt(Self.promptPrefix))
        warmSession = session
    }

    /// Rewrites `text`, delivering the reply as it grows: each element is the whole reply so
    /// far, cleaned up. Stop iterating to cancel the generation.
    func translate(_ text: String) -> AsyncThrowingStream<String, Error> {
        // A fresh session per utterance keeps each rewrite independent of the last; the warm
        // one, if there is one, has already done the slow part.
        let session = warmSession ?? Self.makeSession()
        warmSession = nil
        let prompt = Self.promptPrefix + text + "\n>>>"
        return AsyncThrowingStream { continuation in
            let task = Task {
                let clock = ContinuousClock()
                let started = clock.now
                var firstToken: ContinuousClock.Instant?
                var length = 0
                do {
                    let stream = session.streamResponse(
                        to: prompt,
                        options: GenerationOptions(temperature: 0.45, maximumResponseTokens: 160)
                    )
                    for try await snapshot in stream {
                        if firstToken == nil { firstToken = clock.now }
                        length = snapshot.content.count
                        continuation.yield(Self.clean(snapshot.content))
                    }
                    let finished = clock.now
                    Self.logger.info("Translated \(text.count) chars into \(length): first token after \(Self.milliseconds((firstToken ?? finished) - started)) ms, finished after \(Self.milliseconds(finished - started)) ms")
                    continuation.finish()
                } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                    continuation.finish(throwing: TranslationError.tooLong)
                } catch LanguageModelSession.GenerationError.guardrailViolation {
                    continuation.finish(throwing: TranslationError.refused)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: CorpospeakStyle.englishToCorpospeakInstructions)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let (seconds, attoseconds) = duration.components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }

    /// The small model occasionally echoes the prompt's markers around its answer, opens with a
    /// "Certainly! Here is the rewritten text:" line, or gets stuck repeating a sentence until
    /// it runs out of tokens. All three are removed. Works on partial output too: a sentence is
    /// only ever dropped after its first appearance, so text already handed on stays put.
    static func clean(_ output: String) -> String {
        var lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !["<<<", ">>>"].contains($0) }
        if lines.count > 1, let first = lines.first,
           first.hasSuffix(":"),
           first.range(of: "rewritten|rewrite|here is|version", options: [.regularExpression, .caseInsensitive]) != nil {
            lines.removeFirst()
        }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return dropRepeatedSentences(text)
    }

    /// Removes any sentence that already appeared earlier in the text, keeping the first.
    private static func dropRepeatedSentences(_ text: String) -> String {
        let sentences = Speaker.split(text)
        guard sentences.count > 1 else { return text }
        var seen: Set<String> = []
        let kept = sentences.filter { seen.insert($0.lowercased()).inserted }
        return kept.count == sentences.count ? text : kept.joined(separator: " ")
    }

    enum TranslationError: LocalizedError {
        case tooLong
        /// The model's own safety guardrail declined; happens now and then on ordinary work
        /// sentences about hiring or people.
        case refused

        var errorDescription: String? {
            switch self {
            case .tooLong: "That was too long for the on-device model. Try a shorter sentence."
            case .refused: "The on-device model wouldn't touch that one. Try saying it another way."
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
