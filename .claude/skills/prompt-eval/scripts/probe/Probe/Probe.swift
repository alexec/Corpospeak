// Runs each variant in Variants.swift against the phone's on-device model over the fixed test
// sentences below, scores every reply, and prints to stderr (unbuffered, so `devicectl
// --console` shows it live). Exits when done so the console detaches.
import SwiftUI
import FoundationModels

@main
struct ProbeApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                ProgressView()
                Text("Probing the on-device model…\nKeep the phone unlocked.").multilineTextAlignment(.center)
            }
            .task { await probe(); exit(0) }
        }
    }
}

func log(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

struct Case { let text: String; let facts: [[String]] }
/// Each fact is a list of substrings, any one of which counts as the fact surviving.
let cases: [Case] = [
    Case(text: "Please fix the login bug before the demo tomorrow, and send me the Q2 numbers before lunch.", facts: [["login"], ["demo"], ["tomorrow"], ["q2"], ["lunch"]]),
    Case(text: "I don't think we should hire Sam. He was late to both interviews.", facts: [["sam"], ["interview"], ["late", "punctual", "tardi", "on time", "timeliness"], ["hir", "recruit", "onboard", "candida"]]),
    Case(text: "Can we push the launch to March? The API isn't ready.", facts: [["march"], ["api"], ["launch"]]),
    Case(text: "The server crashed twice last night and Maria is still fixing it.", facts: [["maria"], ["twice", "two", "double"], ["last night", "overnight", "evening", "nocturnal"], ["server"]]),
    Case(text: "I'm going to lunch. Do you want anything from the taco place?", facts: [["lunch"], ["taco"]]),
    Case(text: "The client in Denver wants a 10 percent discount or they walk.", facts: [["denver"], ["10", "ten"], ["discount"], ["client", "customer"]]),
]
let prefix = "Rewrite the text between the markers. Reply with the rewritten text only.\n\n<<<\n"

/// Five-word runs from example replies; one turning up in a reply means the example was pasted.
func fingerprints(_ examples: [Ex]) -> [String] {
    examples.flatMap { ex -> [String] in
        let w = ex.corpospeak.lowercased().split(separator: " ").map(String.init)
        guard w.count >= 5 else { return [] }
        return (0...(w.count - 5)).map { w[$0..<($0 + 5)].joined(separator: " ") }
    }
}

func probe() async {
    let runs = CommandLine.arguments.dropFirst().compactMap { Int($0) }.first ?? 1
    log("availability: \(SystemLanguageModel.default.availability)")
    guard case .available = SystemLanguageModel.default.availability else { log("DONE"); return }
    let knownExamples: [Ex] = CorpospeakStyle.shortExamples + OldStyle.shortExamples
    for variant in variants {
        let fps = fingerprints(knownExamples + variant.examples)
        var factScore = 0.0, refused = 0, copied = 0, n = 0
        for c in cases {
            for _ in 0..<runs {
                let session = LanguageModelSession(instructions: variant.instructions)
                n += 1
                do {
                    let r = try await session.respond(
                        to: prefix + c.text + "\n>>>",
                        options: GenerationOptions(temperature: 0.45, maximumResponseTokens: 160)
                    )
                    let out = r.content.replacingOccurrences(of: "\n", with: " ")
                    let lower = out.lowercased()
                    var kept = 0
                    for alts in c.facts where alts.contains(where: { lower.contains($0) }) { kept += 1 }
                    factScore += Double(kept) / Double(c.facts.count)
                    let didCopy = fps.contains { lower.contains($0) }
                    if didCopy { copied += 1 }
                    log("OK      [\(variant.name)] \(kept)/\(c.facts.count)\(didCopy ? " COPIED" : "") | \(out.prefix(140))")
                } catch {
                    refused += 1
                    log("FAILED  [\(variant.name)] \(c.text.prefix(30))… REFUSED (\(String(describing: error).prefix(60)))")
                }
            }
        }
        let answered = max(1, n - refused)
        log("SUMMARY [\(variant.name)] facts \(Int(100 * factScore / Double(answered)))% of answered, refused \(refused)/\(n), copied \(copied)")
    }
    log("DONE")
}
