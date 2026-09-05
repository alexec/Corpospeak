// The prompt variants the probe compares. Edit this file (it is copied fresh from the skill on
// every run, so edit the copy under build/Probe/ for a one-off, or this one to keep a variant).
//
// `CorpospeakStyle` is the working tree's Corpospeak/CorpospeakStyle.swift; `OldStyle` is the
// same file at the last commit. `examples` only feeds the copy detector: list any examples the
// variant's instructions contain that aren't in `CorpospeakStyle.shortExamples` or
// `OldStyle.shortExamples`.

typealias Ex = (english: String, corpospeak: String)

struct Variant {
    let name: String
    let instructions: String
    var examples: [Ex] = []
}

let variants: [Variant] = [
    Variant(name: "current", instructions: CorpospeakStyle.englishToCorpospeakInstructions),
    Variant(name: "HEAD", instructions: OldStyle.englishToCorpospeakInstructions),
]
