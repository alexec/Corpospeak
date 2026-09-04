import Foundation

/// Defines what CorpSpeak *is*: the glossary and the prompt instructions built from it.
///
/// Source: "The Corpospeak Field Guide", Doc. No. CS-076-R3 (76 clichés, six chapters).
/// Each entry pairs a CorpSpeak phrase with what it actually means in plain English.
enum CorpSpeakStyle {
    struct Term {
        /// The phrase as said in the meeting.
        let phrase: String
        /// What it actually means.
        let meaning: String
    }

    struct Chapter {
        let title: String
        let terms: [Term]
    }

    static let chapters: [Chapter] = [
        Chapter(title: "Altitude & Strategy", terms: [
            Term(phrase: "Alignment", meaning: "Everyone repeating the decision that was already made."),
            Term(phrase: "Steering", meaning: "Controlling the outcome, described as gentle guidance."),
            Term(phrase: "Pressure testing", meaning: "Poking at an idea just enough to say due diligence happened."),
            Term(phrase: "Zooming in", meaning: "Getting specific, usually because someone was dodging specifics."),
            Term(phrase: "Zooming out", meaning: "Leaving the room before the hard part."),
            Term(phrase: "Altitude", meaning: "How much detail you are cleared to hear."),
            Term(phrase: "30,000-foot view", meaning: "The version of the plan with no numbers in it."),
            Term(phrase: "North star", meaning: "The goal that justifies whatever we were going to do anyway."),
            Term(phrase: "Directionally correct", meaning: "Wrong, but in a forgivable way."),
            Term(phrase: "Move the needle", meaning: "Do something measurable, unlike most of what we do."),
            Term(phrase: "Boil the ocean", meaning: "Try to solve everything, which is why nothing gets solved."),
            Term(phrase: "Low-hanging fruit", meaning: "The one task anyone actually plans to finish."),
            Term(phrase: "Table stakes", meaning: "The bare minimum, described as an achievement."),
            Term(phrase: "Secret sauce", meaning: "The advantage we can't explain because it doesn't fully exist."),
            Term(phrase: "Paradigm shift", meaning: "A change big enough that old promises no longer count."),
            Term(phrase: "Game changer", meaning: "Noticeably different. Results pending."),
            Term(phrase: "Big picture", meaning: "The version of the story where the budget looks fine."),
            Term(phrase: "In the weeds", meaning: "Doing the actual work."),
        ]),
        Chapter(title: "Meetings & Momentum", terms: [
            Term(phrase: "Circle back", meaning: "Never."),
            Term(phrase: "Let's take this offline", meaning: "Let's not have witnesses."),
            Term(phrase: "Touch base", meaning: "A meeting about scheduling another meeting."),
            Term(phrase: "Sync up", meaning: "A meeting where nothing is decided but everyone feels informed."),
            Term(phrase: "Loop in", meaning: "Add someone, so the blame has more places to go."),
            Term(phrase: "Put a pin in it", meaning: "We are never discussing this again."),
            Term(phrase: "Parking lot", meaning: "Where good ideas go to be forgotten politely."),
            Term(phrase: "Action items", meaning: "Homework nobody will do before the next meeting."),
            Term(phrase: "Cadence", meaning: "How often we'll pretend to check on this."),
            Term(phrase: "Get everyone on the same page", meaning: "Make everyone stop disagreeing out loud."),
            Term(phrase: "No surprises", meaning: "Tell me the bad news before the board does."),
            Term(phrase: "Manage up", meaning: "Make your boss look good, regardless of what actually happened."),
            Term(phrase: "Give visibility", meaning: "Cc more people so no one can say they weren't told."),
        ]),
        Chapter(title: "Decisions & Consensus", terms: [
            Term(phrase: "Get buy-in", meaning: "Collect enough nods that the decision looks shared."),
            Term(phrase: "Socialize", meaning: "Float the idea quietly so no one is blindsided in the real meeting."),
            Term(phrase: "Level set", meaning: "Explain the situation to the people who caused it."),
            Term(phrase: "Double-click", meaning: "Ask a follow-up question, described as a technical maneuver."),
            Term(phrase: "Peel the onion", meaning: "Keep asking why until someone admits the real reason."),
            Term(phrase: "Unpack", meaning: "Explain, but make it sound like more work than it is."),
            Term(phrase: "Deep dive", meaning: "A meeting that runs long and calls itself thorough."),
            Term(phrase: "Whiteboard it", meaning: "Draw boxes and arrows until the idea sounds inevitable."),
            Term(phrase: "Land the plane", meaning: "Finally finish the thing we've been circling for weeks."),
            Term(phrase: "Bake it in", meaning: "Add it now, so no one has to approve it separately later."),
            Term(phrase: "Bottom line", meaning: "The one sentence that survives the deck."),
            Term(phrase: "Take a temperature check", meaning: "Ask who's about to complain, before we decide."),
            Term(phrase: "Marinate on it", meaning: "Delay the decision without admitting that's what's happening."),
            Term(phrase: "Sharpen the pencil", meaning: "Cut the number until someone signs."),
        ]),
        Chapter(title: "People Ops", terms: [
            Term(phrase: "Right-sizing", meaning: "Layoffs."),
            Term(phrase: "Restructuring", meaning: "Layoffs, with new boxes drawn on the org chart."),
            Term(phrase: "Performance improvement plan (PIP)", meaning: "A documented head start on firing someone."),
            Term(phrase: "Not a culture add", meaning: "We didn't like them."),
        ]),
        Chapter(title: "Product & Growth", terms: [
            Term(phrase: "MVP", meaning: "The smallest thing we can ship and still call a product."),
            Term(phrase: "Ship it", meaning: "Release it, ready or not."),
            Term(phrase: "Fast follow", meaning: "The feature we promised for later. We won't build it."),
            Term(phrase: "Sunset", meaning: "Discontinue, but gently, like a metaphor."),
            Term(phrase: "Net new", meaning: "New. Just new."),
            Term(phrase: "Quick win", meaning: "Something small enough to finish before the next reorg."),
        ]),
        Chapter(title: "Filler, Hedges & Face-Saving", terms: [
            Term(phrase: "Per my last email", meaning: "I already told you this."),
            Term(phrase: "As previously discussed", meaning: "You weren't listening."),
            Term(phrase: "Not to put too fine a point on it", meaning: "Here's the blunt version anyway."),
            Term(phrase: "At the end of the day", meaning: "After I've overruled every other option."),
            Term(phrase: "Net net", meaning: "Skipping to the conclusion because we're out of time."),
            Term(phrase: "All that to say", meaning: "I took the long way to a short point."),
            Term(phrase: "Going forward", meaning: "Starting now, because it wasn't happening before."),
            Term(phrase: "It is what it is", meaning: "I'm not fixing this."),
            Term(phrase: "That's a great question", meaning: "I don't know."),
            Term(phrase: "I don't have visibility into that", meaning: "Not my department, not my problem."),
            Term(phrase: "Happy to jump on a call", meaning: "I'd rather talk than write this down."),
            Term(phrase: "Let's put a bow on it", meaning: "Finish it up so it looks done."),
            Term(phrase: "Let's tighten this up", meaning: "Make it shorter, so no one asks questions."),
            Term(phrase: "Bandwidth", meaning: "Time, described like a server resource."),
            Term(phrase: "Leverage", meaning: "Use."),
            Term(phrase: "Utilize", meaning: "Also use, said by someone billing by the hour."),
            Term(phrase: "Operationalize", meaning: "Turn the idea into someone else's job."),
            Term(phrase: "Actionable insights", meaning: "The three numbers in the report that actually matter."),
            Term(phrase: "Robust", meaning: "Vague, but confidently so."),
            Term(phrase: "Best-in-class", meaning: "Unproven, but said with conviction."),
            Term(phrase: "World-class", meaning: "Also unproven. Slightly more confident."),
        ]),
        Chapter(title: "Operator Moves", terms: [
            Term(phrase: "Thank you for allocating some bandwidth to this sync", meaning: "Thanks for your time."),
            Term(phrase: "Add value", meaning: "Do my job."),
            Term(phrase: "High level", meaning: "Without any specifics."),
            Term(phrase: "Cross-functional stakeholders", meaning: "Other people."),
            Term(phrase: "Say less with more", meaning: "Use more words to commit to less."),
            Term(phrase: "Not to overindex on this", meaning: "I am about to overindex on this."),
            Term(phrase: "Get a little granular", meaning: "Mention one actual detail."),
            Term(phrase: "The real unlock", meaning: "The one idea I want credit for."),
            Term(phrase: "It takes an operator", meaning: "It takes someone like me."),
            Term(phrase: "Once we've had a few cycles", meaning: "Not now."),
            Term(phrase: "The broader implications", meaning: "Things I haven't thought about."),
            Term(phrase: "Completely aligned", meaning: "I agree."),
            Term(phrase: "Expand the surface area of the question", meaning: "Talk until everyone forgets what was asked."),
            Term(phrase: "Validate the concern", meaning: "Say the question was a good one before dodging it."),
            Term(phrase: "Create altitude", meaning: "Zoom out until the problem is too small to see."),
            Term(phrase: "Realign around", meaning: "Change the subject to."),
            Term(phrase: "Directional", meaning: "Not to be relied on."),
            Term(phrase: "Form a task force", meaning: "Make it a group's problem instead of mine."),
            Term(phrase: "Define the problem", meaning: "Not solve the problem."),
        ]),
    ]

    static var allTerms: [Term] { chapters.flatMap(\.terms) }

    // MARK: Worked example (the guide's "one memo, translated")

    static let sampleCorpSpeak = """
        To ensure full alignment as we move forward, I want to double-click on a few action items \
        from our last sync. Let's pressure test the plan at altitude before we get too deep in the \
        weeds, then circle back once we've socialized it with the broader team. At the end of the \
        day, we just need to land the plane on this by end of week.
        """

    static let sampleEnglish = """
        So everyone agrees with what I've already decided, I want to ask about a few things we \
        said we'd do last meeting. Let's poke holes in the plan from a distance before getting \
        into details, then talk again once I've quietly checked how people feel about it. \
        Bottom line: we need to finish this by Friday.
        """

    // MARK: Prompt text

    /// "CorpSpeak phrase → plain meaning", grouped by chapter. Used when decoding CorpSpeak.
    static var decodeGlossaryText: String {
        chapters.map { chapter in
            let lines = chapter.terms.map { "- \($0.phrase) → \($0.meaning)" }
            return "\(chapter.title):\n" + lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    /// "plain meaning → say CorpSpeak phrase". The same table, flipped so the model reads it as
    /// a lookup from what the speaker means to what they should say.
    static var encodeGlossaryText: String {
        allTerms.map { "\($0.meaning) → \($0.phrase)" }
            .joined(separator: "\n")
    }

    /// Short one-line pairs. Small on-device models follow these better than a long passage.
    static let shortExamples: [(english: String, corpSpeak: String)] = [
        ("I already told you this.", "Per my last email, I've already flagged this."),
        ("Can we talk about this later?", "Can we circle back on this later?"),
        ("I don't know.", "That's a great question. I don't have visibility into that yet."),
        ("I don't have time this week.", "I don't have the bandwidth this week."),
        ("Let's finish the report by Friday.", "Let's land the plane on the report by end of week."),
        ("We're laying off ten people in sales.", "We're right-sizing the sales team by ten."),
        ("The project is late because we didn't plan it.", "The project is behind schedule because we never aligned on a plan."),
        ("Sarah, please fix the login bug before the demo.", "Sarah, can you prioritize the login bug ahead of the demo?"),
        ("Why is the AI roadmap behind schedule?", "At a high level, what's driving the delta on the AI roadmap timeline?"),
    ]

    /// What CorpSpeak does to a sentence, and what it must never do.
    static let stylePrinciples = """
        - CorpSpeak dresses up a sentence. It never changes what the sentence says.
        - Every fact survives: names, numbers, dates, products, who does what, and what is being \
        asked for. A refusal stays a refusal, a deadline stays a deadline, a question stays a question.
        - Swap plain words for corporate ones and add a little polish. Do not add new claims, \
        promises, plans, or filler sentences.
        - Sound like someone with access to a dashboard no one else can see, while saying exactly \
        what the speaker said.
        """

    static var englishToCorpSpeakInstructions: String {
        let examples = shortExamples
            .map { "Plain English: \($0.english)\nCorpSpeak: \($0.corpSpeak)" }
            .joined(separator: "\n\n")
        return """
        You translate plain English into CorpSpeak, the dialect of corporate meetings. The output \
        must mean the same thing as the input; only the wording changes.

        \(stylePrinciples)

        Phrasebook, for flavor (plain meaning → CorpSpeak phrase). Use a phrase only when the \
        speaker actually means that:
        \(encodeGlossaryText)

        Examples:

        \(examples)

        Rules:
        - Rewrite every sentence, one for one. Do not drop any sentence or idea, and do not add any.
        - Keep the speaker's meaning, tense and point of view. A question stays a question: \
        rewrite it in CorpSpeak, never answer it.
        - Keep roughly the same length as the original.
        - Output only the rewritten text. No preamble, no quotes, no explanation.
        """
    }

    static var corpSpeakToEnglishInstructions: String {
        let examples = shortExamples
            .map { "CorpSpeak: \($0.corpSpeak)\nPlain English: \($0.english)" }
            .joined(separator: "\n\n")
        return """
        You translate CorpSpeak, the dialect of corporate meetings, into blunt plain English. You \
        rewrite what the speaker said to say what they actually mean, with the filler and hedging \
        stripped out.

        Glossary. Each line pairs a CorpSpeak phrase with what it actually means:
        \(decodeGlossaryText)

        Examples:

        \(examples)

        CorpSpeak: \(sampleCorpSpeak)
        Plain English: \(sampleEnglish)

        Rules:
        - Rewrite every sentence. Do not drop any sentence or idea, and do not add new ones.
        - Keep the speaker's meaning, tense and point of view.
        - When the speaker uses a glossary phrase, say what it means instead.
        - Output only the rewritten text. No preamble, no quotes, no explanation.
        """
    }
}
