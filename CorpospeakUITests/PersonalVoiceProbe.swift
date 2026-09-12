import XCTest

/// Which of two situations the phone is in, because they cost very different amounts of Alex's
/// time and CAPTURE.md's frame 3 depends on the answer.
///
/// The voice menu shows **Your Voice → "Use my Personal Voice…"**, which is
/// `personalVoiceStatus == .notDetermined`: the app has never asked. Tapping it calls
/// `AVSpeechSynthesizer.requestPersonalVoiceAuthorization`, which raises a system alert. What
/// happens next separates the two:
///
/// - the menu gains a voice under **Your Voice** — a Personal Voice exists and was only
///   unauthorised, so frame 3 needs nobody, or
/// - the menu offers **"Create a Personal Voice in Settings…"** — no Personal Voice exists on
///   this phone, and only Alex can record one. That is about fifteen minutes of reading phrases
///   aloud in Settings, and no harness will ever shorten it.
///
/// The authorisation itself is the app's own first-use flow and is reversible in Settings →
/// Privacy & Security → Personal Voice.
final class PersonalVoiceProbe: XCTestCase {

    func testWhetherAPersonalVoiceExistsOnThisPhone() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        SystemAlerts.dismissAll(timeout: 8)
        let start = app.buttons["Start listening"]
        if start.waitForExistence(timeout: 8) {
            start.tap()
            SystemAlerts.dismissAll(timeout: 20)
        }

        let voice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Voice: '")).firstMatch
        XCTAssertTrue(voice.waitForExistence(timeout: 30), "voice menu button never appeared")
        voice.tap()

        let offer = app.buttons["Use my Personal Voice…"]
        guard offer.waitForExistence(timeout: 10) else {
            XCTContext.runActivity(named: "RESULT: the menu does not offer authorisation — already asked") { _ in }
            Attachment.save(XCUIScreen.main.screenshot(), named: "pv-already-decided")
            return
        }
        offer.tap()

        let answered = SystemAlerts.dismissAll(timeout: 20)
        XCTContext.runActivity(named: "authorisation alert answered: \(answered)") { _ in }

        // Reopen the menu; the status is re-read when the voice list refreshes.
        if voice.waitForExistence(timeout: 10) { voice.tap() }
        _ = app.staticTexts["System Voices"].waitForExistence(timeout: 10)

        let needsCreating = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Create a Personal Voice'")).firstMatch.exists
        let stillOffering = app.buttons["Use my Personal Voice…"].exists
        let deniedRoute = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Allow Personal Voice'")).firstMatch.exists

        let verdict: String
        if needsCreating {
            verdict = "NO PERSONAL VOICE ON THIS PHONE — Alex has to record one in Settings (~15 min). Frame 3 is his."
        } else if deniedRoute {
            verdict = "AUTHORISATION DENIED — the alert was answered with Don't Allow."
        } else if stillOffering {
            verdict = "STILL NOT DETERMINED — the alert did not appear or was not answered."
        } else {
            verdict = "A PERSONAL VOICE IS NOW IN THE MENU — frame 3 needs nobody."
        }
        XCTContext.runActivity(named: "RESULT: \(verdict)") { _ in }
        Attachment.save(XCUIScreen.main.screenshot(), named: "pv-after-authorisation")
    }
}
