# Releasing to the App Store

The App Store record is **Corpospeak: In Your Voice** (bundle ID `com.alexcollins.CorpSpeak`,
which must never change, SKU `corpspeak`). Everything below runs from a terminal; Xcode's
signed-in Apple ID handles authentication.

Steps 1–3 are scripted: `scripts/ship.sh` (`preflight`, `bump`,
`archive <ios|mac>`, `upload <ios|mac>`, or `all`) runs each one with its checks and logs, and
the `ship-it` skill walks Claude Code through the whole release including the commit, PR, and
the App Store Connect checklist. The sections below remain the reference for what it does.

## 1. Bump the build number

Every upload needs a new `CFBundleVersion`. Edit it in `project.yml` (xcodegen writes it into
`Corpospeak/Info.plist`, which is committed so the two must stay in sync), then regenerate:

```bash
xcodegen generate
```

Bump `CFBundleShortVersionString` too when the version shown on the store should change.

## 2. Archive

```bash
xcodebuild -project Corpospeak.xcodeproj -scheme Corpospeak -configuration Release \
  -destination 'generic/platform=macOS' -archivePath build/Corpospeak.xcarchive \
  -allowProvisioningUpdates archive
```

The iPhone and iPad build is the same target archived for iOS. It shares the bundle ID, so it
joins the same App Store record as a second platform:

```bash
xcodebuild -project Corpospeak.xcodeproj -scheme Corpospeak -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Corpospeak-iOS.xcarchive \
  -allowProvisioningUpdates archive
```

## 3. Upload to App Store Connect

`ExportOptions.plist` in the repo root uploads straight to App Store Connect with automatic
signing:

```bash
xcodebuild -exportArchive -archivePath build/Corpospeak.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```

Repeat with `build/Corpospeak-iOS.xcarchive` for the iOS build.

The build appears under the app's TestFlight/Builds tab a few minutes later, after Apple's
processing. Select it on the version page and submit.

## 4. What App Review needs to know

The app is useless without Apple Intelligence, which a reviewer's device may not have turned
on, and on 2026-09-05 App Review asked (Guideline 2.1, Information Needed) for a screen
recording plus written answers to six questions. Put the text below in
**App Review Information → Notes**, attach the recording under **App Review Information →
Attachments**, and paste both into the Resolution Center reply when a submission is
questioned.

### After a rejection: replying is not resubmitting

Answering App Review in Resolution Center does **not** put the version back in the queue. A
rejected version stays rejected, and unread, until it is explicitly resubmitted — build 1.0 (1)
sat idle for three days in September 2026 because the Sep 5 reply was assumed to be enough.
Resubmitting is two clicks in two different places, and the first one is not on the submission
page:

1. On the **version page** (Distribution → the platform's version), click **Update Review**.
   The button on the submission page — *Resubmit to App Review* — is greyed out until this is
   done, which reads like a block but is just ordering. If a newer build has been uploaded,
   a *Newer Build Available* dialog asks whether to submit the older one anyway; to send the
   newer build instead, cancel, remove the earlier build from the version, and select the new
   one before clicking *Update Review*.
2. Back on the **submission page**, the item now reads *Ready for Review* and
   **Resubmit to App Review** is enabled. Click it. The status becomes *Waiting for Review*.

Check the apps list afterwards — the version must read *Waiting for Review*, not *Rejected*.

### Screen recording

Record on whichever platform is under review, running the current OS release, with the build
under review (rebuild its commit if the archive is gone: `git worktree add <dir> <commit>`,
`xcodegen generate`, then a Release build). Start the recording before launching the app so
it opens with the launch, and make sure the recording captures the microphone so the
reviewer hears the sentence you say and the app's reply.

- **macOS** (the 1.0 review): press ⇧⌘5, choose *Record Entire Screen*, and under *Options*
  pick the Mac's microphone. Start recording, then launch the app from Finder or the Dock.
- **iOS** (once the iPhone/iPad platform is submitted): the iPhone 15 Pro Max is the only
  paired device that can run Apple Intelligence (`scripts/check_apple_intelligence_eligible.py`).
  Delete the app first so the permission prompts appear, long-press the Control Center
  record button, turn the microphone on, and start from the Home Screen.

Then, in either case:

1. Launch Corpospeak.
2. Allow Microphone, Speech Recognition, and (if prompted) Personal Voice.
3. Say a plain English sentence and pause; let the app rewrite it and read it back.
4. Open the voice menu and pick a different voice; say one more sentence.
5. Tap the mute button, then tap the status pill while it is speaking to stop, then stop the
   recording.

The app has no accounts, no user-generated content, and no purchases, so nothing else needs to
be shown.

### Notes field text

> **Purpose and audience.** Corpospeak is a comedy toy for adults who work in offices. It
> listens through the microphone, rewrites whatever you just said as over-the-top corporate
> jargon ("Corpospeak"), and reads the rewrite back in a system voice or your own Personal
> Voice. The value is entertainment: hearing your own sentences turned into meeting-speak, in
> your own voice. There is no productivity purpose.
>
> **Setup and using the main feature.** No account, login, sample file, or in-app purchase.
> The device must have Apple Intelligence turned on (System Settings → Apple Intelligence &
> Siri on the Mac; Settings on iPhone/iPad) — an Apple silicon Mac on macOS 26, or an iPhone
> 15 Pro or later / an iPad with M1 or A17 Pro or later on iOS/iPadOS 26. On first launch the app asks for Microphone and Speech Recognition
> permission (required) and Personal Voice permission (optional; decline and it uses a system
> voice). Then say a sentence in plain English and pause. The app shows the transcript,
> rewrites it, and speaks the result. The voice menu and mute button are in the top bar;
> tapping the status pill (or pressing Escape) stops translation and speech. If Apple
> Intelligence is off or the device is not eligible, the app says so on screen instead of
> working.
>
> **External services.** None. Corpospeak makes no network connections of any kind.
> Everything runs on the device: Apple's Speech framework restricted to on-device recognition
> (it never falls back to Apple's servers), the Foundation Models framework (the on-device
> Apple Intelligence model) for the rewrite, and for playback either AVSpeechSynthesizer with
> built-in voices and the user's Personal Voice, or the open-weights Kokoro text-to-speech
> model run locally through Core ML. That model and the open-source FluidAudio library that
> loads it are bundled inside the app and are never downloaded. Nothing is written to disk
> except the identifier of the chosen voice. No analytics, no ads, no accounts, no payments,
> no tracking.
>
> **Regional differences.** The app's own features and content are identical in every
> region. It depends on Apple Intelligence, so it only works where Apple makes the on-device
> model available and in the languages Apple supports; where it is unavailable the app
> explains that on screen. Speech recognition uses the device's current language.
>
> **Regulated industry / third-party material.** Neither applies. The app operates in no
> regulated industry. All text, prompts, and the jargon glossary are original work by the
> developer. Voices are Apple's built-in voices, the user's own Personal Voice, or the
> Apache-2.0 licensed Kokoro model.
>
> Privacy policy: https://www.alexecollins.com/corpospeak/privacy.html

## Listing metadata

| Field | Value |
| --- | --- |
| Name | Corpospeak: In Your Voice |
| Category | Entertainment |
| Price | Free |
| Privacy | Data Not Collected |
| Privacy policy URL | https://www.alexecollins.com/corpospeak/privacy.html |
| Support URL | https://www.alexecollins.com/corpospeak/support.html |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false` in Info.plist, so no questionnaire |
| Minimum macOS | 26.0 |

## Screenshots

App Store Connect wants a 13-inch iPad set and a 6.5-inch iPhone set. The iPad set lives in
`Corpospeak/AppStore/screenshots/en-US` at **2752 × 2064**, landscape, shot from a **Release**
build on an **iPad Pro 13-inch (M5)** simulator.

### Why a launch argument is involved

A simulator cannot hear anything. On-device speech recognition never starts there: the en_US
model ships as a cryptex disk image the simulator does not mount, so `localspeechrecognition`
fails to build a recogniser on every restart, and `SpeechListener` requires on-device
recognition and will not fall back. No transcript is possible whoever speaks into the Mac.
Hardware is no answer either: the paired iPad (A16) cannot run Apple Intelligence and its
screen fits no App Store slot.

So the utterance is seeded instead, through `Corpospeak/DemoOptions.swift`. `-demoUtterance`
arrives in the `UserDefaults` argument domain and goes into `handleUtterance()` as though the
recogniser had heard it. It is deliberately **not** `#if DEBUG`-gated, because these frames have
to come from a Release build. Only the recogniser is skipped: the rewrite, the panels, the
status pill and the speech all run for real, and the file draws no UI of its own, so the frame
shows the shipping app. Pass no argument and nothing about the app changes.

### Shooting the set

```bash
UDID=<the iPad Pro 13-inch (M5) simulator>
xcodebuild -project Corpospeak.xcodeproj -scheme Corpospeak -configuration Release \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build/screenshots build
xcrun simctl install "$UDID" build/screenshots/Build/Products/Release-iphonesimulator/Corpospeak.app
```

1. Launch once with no argument and walk the first run: **Start listening**, then Allow for
   Speech Recognition and Allow for the Microphone. Both stick in the app's container, so every
   later launch opens straight into the app.
2. Rotate to landscape. Several simulators can be up at once, so make the right window the main
   one before touching the menu, or the rotation lands on someone else's device:

   ```bash
   osascript -e 'tell application "System Events" to tell process "Simulator"
     set w to first window whose name contains "iPad Pro 13-inch"
     perform action "AXRaise" of w
     set value of attribute "AXMain" of w to true
     click menu item "Rotate Left" of menu 1 of menu bar item "Device" of menu bar 1
   end tell'
   ```

3. Freeze the status bar:

   ```bash
   xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState discharging \
     --batteryLevel 100 --wifiBars 3 --cellularMode notSupported
   ```

4. Launch with the sentence and capture once the screen is where you want it:

   ```bash
   xcrun simctl launch "$UDID" com.alexcollins.CorpSpeak -demoUtterance "Nobody read the document before the meeting, so we wasted an hour."
   xcrun simctl io "$UDID" screenshot frame.png
   ```

   `-demoDelay` (seconds, 2 by default) sets how long the app waits before the sentence lands,
   which is how the empty state gets photographed before the reply arrives.

5. `simctl io screenshot` always writes the portrait framebuffer, whatever way round the device
   is, so turn the file the right way up and check it:

   ```bash
   sips -r 270 frame.png
   sips -g pixelWidth -g pixelHeight frame.png   # must read 2752 × 2064
   ```

The rewrite comes from the on-device model, so it is different every run. Shoot a few and keep
the funniest. Give it 30–60 seconds: the model is slower in a simulator than on a phone.

### The frames

| File | What it shows |
| --- | --- |
| `1-translated.png` | A finished rewrite, with the plain sentence above it and the pill back on Listening. |
| `2-listening.png` | The empty state: the level meter and *Say something in plain English.* |
| `4-speaking.png` | The rewrite being read back, the pill offering Stop. |

**There is no frame 3, by design.** It was to be the voice menu with the user's Personal Voice
at the top of it. No simulator has a Personal Voice (`offersPersonalVoice` is false while the
status is `.unsupported`), and Kokoro is switched off on the iOS 26.4+ line, so the menu there
lists Apple's system voices alone, which is the opposite of what that frame is for. Faking the
row would put something in the App Store that the app cannot do on the reviewer's device. App
Store Connect accepts three screenshots, so the iPad set ships as three, and the voice frame
goes in the iPhone set, shot on the iPhone 15 Pro Max where a real Personal Voice exists.
