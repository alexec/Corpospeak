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
> Privacy policy: https://github.com/alexec/Corpospeak/blob/main/PRIVACY.md

## Listing metadata

| Field | Value |
| --- | --- |
| Name | Corpospeak: In Your Voice |
| Category | Entertainment |
| Price | Free |
| Privacy | Data Not Collected |
| Privacy policy URL | https://github.com/alexec/Corpospeak/blob/main/PRIVACY.md |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false` in Info.plist, so no questionnaire |
| Minimum macOS | 26.0 |
