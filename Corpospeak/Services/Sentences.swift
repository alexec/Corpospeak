import Foundation
import NaturalLanguage

/// Cuts text into sentences.
///
/// This is the one thing the speaking side and the writing side both need — the speaker hands a
/// voice one sentence at a time, the translator uses it to notice the model looping on the same
/// sentence, and the view highlights the sentence being spoken. It lives on its own, rather than
/// on `Speaker`, so that none of them drags in the others: `scripts/eval_prompt.sh` scores the
/// prompt by compiling `Translator` on the Mac, and `Speaker` now reaches Kokoro and so
/// FluidAudio, which the harness has no way to resolve.
enum Sentences {
    /// Splits text into sentences, keeping punctuation. Falls back to the whole text.
    static func split(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { result.append(sentence) }
            return true
        }
        return result.isEmpty ? [text] : result
    }
}
