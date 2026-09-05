// Scores the English → Corpospeak prompt on the on-device model: does the speaker's information
// survive, does the model paste example text into replies, does it run away? Compiled together
// with CorpospeakStyle.swift, Translator.swift and Speaker.swift by scripts/eval_prompt.sh so
// it always tests the prompt the app ships, cleaned the way the app cleans it.

struct Case { let text: String; let facts: [[String]] }

/// Each fact is a list of substrings, any of which counts as the fact surviving.
let cases: [Case] = [
    Case(text: "Please fix the login bug before the demo tomorrow, and send me the Q2 numbers before lunch.",
         facts: [["login"], ["demo"], ["tomorrow"], ["q2"], ["lunch"]]),
    Case(text: "I don't think we should hire Sam. He was late to both interviews.",
         facts: [["sam"], ["interview"], ["late", "punctual", "tardi", "on time", "timeliness"], ["hir", "recruit", "onboard", "candida"]]),
    Case(text: "Can we push the launch to March? The API isn't ready.",
         facts: [["march"], ["api"], ["launch"]]),
    Case(text: "The server crashed twice last night and Maria is still fixing it.",
         facts: [["maria"], ["twice", "two", "double"], ["last night", "overnight", "evening", "nocturnal"], ["server"]]),
    Case(text: "We're out of budget for this quarter, so no new hires until January.",
         facts: [["budget"], ["quarter"], ["january"], ["hir", "headcount", "recruit"]]),
    Case(text: "I'm going to lunch. Do you want anything from the taco place?",
         facts: [["lunch"], ["taco"]]),
    Case(text: "Kevin broke the build again. Can someone else review his pull requests from now on?",
         facts: [["kevin"], ["build"], ["review"], ["pull request", "pr"]]),
    Case(text: "The client in Denver wants a 10 percent discount or they walk.",
         facts: [["denver"], ["10", "ten"], ["discount"], ["client", "customer"]]),
]

let prefix = "Rewrite the text between the markers. Reply with the rewritten text only.\n\n<<<\n"

/// Five-word runs from the examples' Corpospeak. If one shows up in a reply, the model copied
/// the example rather than rewriting the input.
let fingerprints: [String] = CorpospeakStyle.shortExamples.flatMap { example -> [String] in
    let words = example.corpospeak.lowercased().split(separator: " ").map(String.init)
    guard words.count >= 5 else { return [] }
    return (0...(words.count - 5)).map { words[$0..<($0 + 5)].joined(separator: " ") }
}

struct Score {
    var facts = 0.0, n = 0, copied = 0, long = 0, words = 0.0, refused = 0
}

@MainActor
func check(_ c: Case, _ out: String, _ s: inout Score) -> String {
    let lower = out.lowercased()
    var kept = 0
    for alts in c.facts where alts.contains(where: { lower.contains($0) }) { kept += 1 }
    s.facts += Double(kept) / Double(c.facts.count)
    s.n += 1
    let copied = fingerprints.contains { lower.contains($0) }
    if copied { s.copied += 1 }
    let ratio = Double(out.split(separator: " ").count) / Double(c.text.split(separator: " ").count)
    s.words += ratio
    if ratio > 3.5 { s.long += 1 }
    let flat = out.replacingOccurrences(of: "\n", with: " ")
    return "\(kept)/\(c.facts.count)\(copied ? " COPIED" : "")\(ratio > 3.5 ? " LONG" : "") | \(flat.prefix(160))"
}

@main
struct Main {
    @MainActor
    static func main() async throws {
        let args = CommandLine.arguments
        let runs = args.dropFirst().compactMap { Int($0) }.first ?? 3
        let verbose = args.contains("-v")
        guard case .available = SystemLanguageModel.default.availability else {
            print("The on-device model is not available on this Mac."); exit(1)
        }
        var s = Score()
        for c in cases {
            if verbose { print(">> \(c.text)") }
            for _ in 0..<runs {
                let session = LanguageModelSession(instructions: CorpospeakStyle.englishToCorpospeakInstructions)
                do {
                    let r = try await session.respond(
                        to: prefix + c.text + "\n>>>",
                        options: GenerationOptions(temperature: 0.45, maximumResponseTokens: 160)
                    )
                    let line = check(c, Translator.clean(r.content), &s)
                    if verbose { print("   \(line)") }
                } catch {
                    s.refused += 1; s.n += 1
                    if verbose { print("   REFUSED by the model's guardrail") }
                }
            }
        }
        let pct = Int(100 * s.facts / Double(s.n))
        let avg = String(format: "%.1f", s.words / Double(s.n))
        print("facts kept \(pct)%   copied examples \(s.copied)   runaway \(s.long)   avg length x\(avg)   refused \(s.refused)   (n=\(s.n))")
    }
}
