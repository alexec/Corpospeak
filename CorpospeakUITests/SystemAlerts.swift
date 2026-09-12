import XCTest

/// Answering the permission alerts, which is the part that decides whether any of this can run
/// unattended.
///
/// Two routes, because they fail in different ways and neither is reliable alone:
///
/// - **Springboard, driven directly.** The microphone and speech-recognition alerts belong to
///   SpringBoard, not to the app, so they can be queried and tapped like any other element.
///   This is synchronous: ask for the button, tap it, know whether it worked. It is the one
///   used here.
/// - **`addUIInterruptionMonitor`.** Still present in Xcode 26 and not deprecated, but it only
///   fires when the test next interacts with the *app*, which means an alert that arrives while
///   nothing else is happening sits there until something pokes it. It is kept below as a
///   fallback for alerts nobody predicted.
enum SystemAlerts {

    static let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// Every button label that means yes, most permissive first. Order matters: the microphone
    /// alert on iOS 27 offers "Allow" alone, while location-style alerts offer three choices.
    static let affirmative = [
        "Allow While Using App",
        "Allow",
        "OK",
        "Continue",
        "Yes",
    ]

    /// Dismisses system alerts until none appear for `quietPeriod` seconds, and returns the
    /// labels of the buttons it tapped, in order.
    ///
    /// Returning the labels rather than a Bool is deliberate: a run that answered
    /// `["Allow", "Allow"]` and a run that answered `["Allow"]` are different situations, and
    /// the second one is how you find out that speech recognition was already granted.
    @discardableResult
    static func dismissAll(timeout: TimeInterval, quietPeriod: TimeInterval = 2) -> [String] {
        var tapped: [String] = []
        let deadline = Date().addingTimeInterval(timeout)
        var lastAlert = Date()

        while Date() < deadline {
            if let label = tapAffirmative() {
                tapped.append(label)
                lastAlert = Date()
                continue
            }
            if Date().timeIntervalSince(lastAlert) > quietPeriod, !tapped.isEmpty { break }
            if Date().timeIntervalSince(lastAlert) > quietPeriod, tapped.isEmpty { break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return tapped
    }

    /// Taps the first affirmative button in whatever alert is on screen, if there is one.
    private static func tapAffirmative() -> String? {
        for source in [springboard.alerts, XCUIApplication().alerts] {
            guard source.firstMatch.exists else { continue }
            let alert = source.firstMatch
            for label in affirmative {
                let button = alert.buttons[label]
                if button.exists, button.isHittable {
                    button.tap()
                    return label
                }
            }
        }
        return nil
    }

    /// The older route, for alerts this file does not know the shape of. Register it before the
    /// interaction that triggers the alert, and remember that it only runs on the *next*
    /// interaction with the app — so follow the triggering tap with `app.tap()`.
    static func registerInterruptionMonitor(on testCase: XCTestCase) -> NSObjectProtocol {
        testCase.addUIInterruptionMonitor(withDescription: "system permission alert") { alert in
            for label in affirmative where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }
}

extension XCUIElement {
    /// `waitForExistence` has no opposite in XCTest, and "the first-run view went away" is the
    /// only honest assertion that the tap landed.
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !exists { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return !exists
    }
}
