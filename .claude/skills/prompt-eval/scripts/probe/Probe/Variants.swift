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

// 2026-09-09: the iOS 27 model started refusing the *work* examples too, which the 09-05 notes
// recorded as passing — so the OS split alone no longer saves us (confirmed on the phone: it is
// getting "work (OS 27+)" and the model reports itself available).
//
// These variants test one hypothesis: it is not the examples at all, it is the instructions
// describing deliberate obfuscation. "Evasive", "the ask gets buried", and "it should take the
// listener a moment to work out what was actually asked" read, to a tightened safety classifier,
// like coaching someone to be deceptive. Each variant below softens exactly one thing, so a
// refusal rate that drops points at the cause rather than at a vibe.
//
// Everything else — the phrasebook, the rules, the example set — is held constant, because
// trimming those is already measured as costing ~20 points of facts kept (2026-09-09, Mac) while
// leaving refusals flat.

/// The shipped instructions with one phrase swapped, so only that phrase is under test.
private func shipped(replacing original: String, with replacement: String) -> String {
    let text = CorpospeakStyle.englishToCorpospeakInstructions
    let edited = text.replacingOccurrences(of: original, with: replacement)
    // A phrase that no longer matches would silently leave the variant identical to `current`,
    // and the run would compare five copies of the same prompt on someone's unlocked phone.
    precondition(edited != text, "Variants.swift: no match for \(original.prefix(48))...")
    return edited
}

/// Drops the "evasive" framing from the opening sentence.
private let notEvasive = shipped(
    replacing: "polished, upbeat, jargon-heavy, and evasive",
    with: "polished, upbeat, and jargon-heavy")

/// Reframes burying the ask as long-windedness rather than concealment.
private var longWinded: String {
    var text = shipped(
        replacing: "the action or question is wrapped in so much process language that "
            + "it takes a moment to find it.",
        with: "the action or question is stated at great and cheerful length.")
    text = text.replacingOccurrences(
        of: "- The ask gets buried.",
        with: "- The ask gets padded out.")
    text = text.replacingOccurrences(
        of: "It should take the listener a moment to work out what was actually asked, "
            + "but it must still be in there. Bury it with wording, not with extra sentences.",
        with: "The request stays perfectly clear, just far wordier than it needs to be. "
            + "Pad it with wording, not with extra sentences.")
    return text
}

/// Says plainly that this is parody, which gives a classifier a reason to allow it.
private var namedAsParody: String {
    let opening = "You write parody. It is a comedy bit about corporate meeting-speak, for the "
        + "amusement of the person who said the line — they are rewriting their own words. "
    return opening + CorpospeakStyle.englishToCorpospeakInstructions
}

/// Both of the above together, for when neither alone is enough.
private var parodyAndLongWinded: String {
    let opening = "You write parody. It is a comedy bit about corporate meeting-speak, for the "
        + "amusement of the person who said the line — they are rewriting their own words. "
    return opening + longWinded
}

let variants: [Variant] = [
    Variant(name: "current", instructions: CorpospeakStyle.englishToCorpospeakInstructions),
    Variant(name: "not-evasive", instructions: notEvasive),
    Variant(name: "long-winded", instructions: longWinded),
    Variant(name: "parody", instructions: namedAsParody),
    Variant(name: "parody+long-winded", instructions: parodyAndLongWinded),
]
