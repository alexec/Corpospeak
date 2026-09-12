import SwiftUI

/// The words of the first run: what Corpospeak is, how you use it, and why this one.
///
/// Held apart from `FirstRun` so Settings' "How it works" row can show the same copy without
/// the button that asks for the microphone. Re-reading what the app does must never open a
/// system alert, so the button lives in `FirstRun` and nowhere else, and the copy lives here
/// once rather than in two places that drift.
struct FirstRunContent: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            Text("Corpospeak listens, and says it back the way a meeting would.")
                .font(.system(size: compact ? 22 : 28, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Say something in plain English. It gets rewritten into the language of alignment, cadence and circling back, and read out loud.")
                Text("It listens the whole time it's open, so there's no button to hold.")
                Text("The rewriting and the voice both run on your \(Platform.device). Private and free forever.")
            }
            .font(.system(size: compact ? 15 : 16))
            .foregroundStyle(.white.opacity(0.62))
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// What a new user sees instead of two system alerts.
///
/// The microphone *is* Corpospeak, so this is primed on the first screen rather than at a
/// feature the user goes looking for, and it sits in place with the app's own chrome visible
/// behind it — not a sheet. A sheet is a tour you dismiss; this is the app asking for the one
/// thing it needs before it can do its job, in its own voice.
///
/// One button, and it opens the system alert. There is deliberately no way past this view that
/// skips the alert: the HIG forbids it and App Review checks for it.
struct FirstRun: View {
    let compact: Bool
    /// Runs the permission requests. The view is gone as the alert appears.
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            FirstRunContent(compact: compact)

            Button(action: onContinue) {
                Text("Start listening")
                    .font(.system(size: compact ? 16 : 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityHint("Corpospeak will ask for the microphone and speech recognition.")
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.horizontal, compact ? 24 : 40)
    }
}
