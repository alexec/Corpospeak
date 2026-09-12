import Foundation

/// Launch arguments for App Store screenshots, e.g.
///
/// ```
/// xcrun simctl launch <udid> com.alexcollins.CorpSpeak \
///   -demoUtterance "Got the job. No one asked what it was."
/// ```
///
/// Values arrive through the UserDefaults argument domain, so with no argument passed nothing
/// about the app changes.
///
/// This exists because the Simulator cannot do the one thing a screenshot of this app needs.
/// On-device speech recognition never starts there: the en_US model ships as a cryptex disk
/// image the Simulator does not mount, so `localspeechrecognition` fails to build a recogniser
/// on every restart, and `SpeechListener` requires on-device and will not fall back. No iPad in
/// the house is Apple Intelligence eligible either, so the iPad set has nowhere else to come
/// from. Seeding the utterance skips the recogniser and nothing else — the rewrite, the panels,
/// the status pill and the speech all run for real, and this draws no UI of its own, so a frame
/// taken this way shows the shipping app.
struct DemoOptions {
    /// A sentence to push through the pipeline as though it had been heard, once, at launch.
    let utterance: String?
    /// Seconds to wait first, so the empty state can be photographed before the reply lands.
    let delay: Double

    static let current: DemoOptions = {
        let defaults = UserDefaults.standard
        return DemoOptions(
            utterance: defaults.string(forKey: "demoUtterance"),
            // `double(forKey:)` reads 0 for a missing key, which would fire before the app has
            // finished starting; only an argument actually passed should shorten the wait.
            delay: defaults.object(forKey: "demoDelay") == nil ? 2 : defaults.double(forKey: "demoDelay")
        )
    }()
}
