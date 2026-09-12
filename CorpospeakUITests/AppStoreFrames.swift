import XCTest

/// The four iPhone frames CAPTURE.md asks for, taken off Alex's own phone because no simulator
/// can produce them: frames 1 and 4 need a real transcript, and frame 3 needs a real Personal
/// Voice in the menu.
///
/// The sentences arrive through the air. `scripts/device_capture.sh` plays them from the Mac's
/// speakers with `kokoro` while this test runs, so the app hears them through its own microphone
/// and the whole pipeline — recogniser, rewrite, voice — is the shipping one. Nothing here seeds
/// an utterance: `DemoOptions` exists for the iPad, which has no Apple Intelligence eligible
/// hardware in the house, and this target deliberately does not use it.
///
/// **One test method, not four.** XCTest runs methods in alphabetical order and relaunches the
/// app between them, and the first attempt at this split the four frames into four tests: two
/// failed because the Mac was still talking from the previous test, so the app was never in the
/// empty state they were waiting for. The frames are one ordered sequence against one schedule
/// of speech, so they are one test.
final class AppStoreFrames: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTheFourFrames() throws {
        app = XCUIApplication()
        app.launch()
        SystemAlerts.dismissAll(timeout: 8)
        let start = app.buttons["Start listening"]
        if start.waitForExistence(timeout: 8) {
            start.tap()
            SystemAlerts.dismissAll(timeout: 20)
        }

        // ---- Frame 2: waiting for a sentence -------------------------------------------------
        // This one has to be taken before the Mac says anything, which is why the script holds
        // its first line until well after the test starts.
        let empty = app.staticTexts["Say something in plain English."]
        XCTAssertTrue(empty.waitForExistence(timeout: 30), "never reached the empty state")
        Attachment.save(XCUIScreen.main.screenshot(), named: "2-waiting")

        // ---- Frame 1: mid-loop, the joke in one picture ---------------------------------------
        // `YOU SAID` exists only once an utterance has been through the recogniser, so waiting
        // for it is the proof that the phone's microphone heard the Mac across the room.
        XCTAssertTrue(
            app.staticTexts["YOU SAID"].waitForExistence(timeout: 120),
            "nothing was transcribed in 120s — pill said '\(pillLabel ?? "?")'"
        )
        // Speech starts as soon as the first sentence of the reply is ready, so the pill reads
        // Speaking within a beat of the text appearing. Not an assertion: the frame is worth
        // having either way, and a run that missed the window should say so rather than throw
        // the whole sequence away. The first attempt did assert here and lost three good frames
        // to a pill that had already moved back to Listening.
        let frame1 = screenshotWhilePillReads("Speaking", timeout: 60)
        Attachment.save(frame1.image, named: "1-midloop")
        XCTContext.runActivity(named: "frame 1 — pill read '\(frame1.pill ?? "?")'") { _ in }
        _ = Attachment.recordSize(of: frame1.image)

        // ---- Frame 4: a long reply mid-read ---------------------------------------------------
        // The script's second line is deliberately long, so the reply runs to several sentences
        // and one of them is lit while the rest sit under it. Wait for this reply to finish and
        // the next one to start, rather than for a clock.
        // Wait for the long line's reply by watching the transcript change, which is steadier
        // than watching the pill: the text stays put while the phase moves under it.
        let firstReply = app.staticTexts["YOU SAID"].firstMatch.label
        let changed = waitForTranscriptToChange(from: firstReply, timeout: 150)
        XCTContext.runActivity(named: "frame 4 — second utterance arrived: \(changed)") { _ in }
        let frame4 = screenshotWhilePillReads("Speaking", timeout: 60, settle: 4)
        Attachment.save(frame4.image, named: "4-midread")
        XCTContext.runActivity(named: "frame 4 — pill read '\(frame4.pill ?? "?")'") { _ in }

        // ---- Frame 3: the voice menu ----------------------------------------------------------
        // The frame is supposed to show his own voice at the top, not the offer to turn one on.
        // On a freshly installed app the status is `.notDetermined`, so the offer is what is
        // there until someone taps it — which raises a system alert, which is answerable from
        // here like any other. `PersonalVoiceProbe` is where that was worked out.
        let voice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Voice: '")).firstMatch
        XCTAssertTrue(voice.waitForExistence(timeout: 20), "voice menu button never appeared")
        XCTContext.runActivity(named: "voice button reads '\(voice.label)'") { _ in }
        voice.tap()
        XCTAssertTrue(app.staticTexts["System Voices"].waitForExistence(timeout: 10), "voice menu never opened")

        let offer = app.buttons["Use my Personal Voice…"]
        if offer.exists {
            offer.tap()
            let answered = SystemAlerts.dismissAll(timeout: 20)
            XCTContext.runActivity(named: "Personal Voice authorisation answered: \(answered)") { _ in }
            if voice.waitForExistence(timeout: 10) { voice.tap() }
            _ = app.staticTexts["System Voices"].waitForExistence(timeout: 10)
        }

        let personalVoices = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] 'Personal Voice' AND NOT (label BEGINSWITH 'Use my')"))
            .count
        let needsCreating = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Create a Personal Voice'")).firstMatch.exists
        XCTContext.runActivity(
            named: "PERSONAL VOICE — \(personalVoices) in the menu, needs creating: \(needsCreating)"
        ) { _ in }
        XCTAssertFalse(
            needsCreating,
            "no Personal Voice exists on this phone — frame 3 cannot show one until Alex records one in Settings"
        )

        Attachment.save(XCUIScreen.main.screenshot(), named: "3-voice-menu")
    }

    // MARK: - The status pill, which is the only readable statement of what the app is doing

    /// The pill is the leftmost control in the toolbar and its label is the phase, except while
    /// the app is speaking, when it also becomes the stop button and its label picks up the
    /// stop wording. So this matches on a substring rather than on the exact phase name.
    private var pillLabel: String? {
        let pill = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'Listening' OR label CONTAINS[c] 'Speaking' "
                  + "OR label CONTAINS[c] 'Translating' OR label CONTAINS[c] 'Starting' "
                  + "OR label CONTAINS[c] 'Muted'"
        )).firstMatch
        return pill.exists ? pill.label : nil
    }

    /// Take the frame *while* the phase is the one the shot needs, rather than after waiting for
    /// it. The phases move faster than a wait-then-screenshot pair can follow: the first version
    /// of this waited for `Speaking`, took the picture a beat later, and caught the app already
    /// back on `Translating…` for the next thing the Mac had said. So screenshot first and read
    /// the pill from the same moment, keeping the first frame that matches and falling back to
    /// the last one taken.
    ///
    /// `settle` holds that long after the phase is first seen, for a frame that wants to be a
    /// little way into the reply rather than at its first word.
    private func screenshotWhilePillReads(
        _ text: String, timeout: TimeInterval, settle: TimeInterval = 0
    ) -> (image: XCUIScreenshot, pill: String?) {
        let deadline = Date().addingTimeInterval(timeout)
        var last = (image: XCUIScreen.main.screenshot(), pill: pillLabel)
        var settledAt: Date?
        while Date() < deadline {
            let pill = pillLabel
            if let pill, pill.localizedCaseInsensitiveContains(text) {
                if settle > 0 {
                    if settledAt == nil { settledAt = Date() }
                    if Date().timeIntervalSince(settledAt!) < settle {
                        Thread.sleep(forTimeInterval: 0.2)
                        continue
                    }
                }
                return (XCUIScreen.main.screenshot(), pill)
            }
            last = (XCUIScreen.main.screenshot(), pill)
            Thread.sleep(forTimeInterval: 0.2)
        }
        return last
    }

    private func waitForPill(containing text: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let l = pillLabel, l.localizedCaseInsensitiveContains(text) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    private func waitForTranscriptToChange(from original: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let now = app.staticTexts["YOU SAID"].firstMatch
            if now.exists, now.label != original { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }
}
