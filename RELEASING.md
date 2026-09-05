# Releasing to the App Store

The App Store record is **Corpospeak: In Your Voice** (bundle ID `com.alexcollins.CorpSpeak`,
which must never change, SKU `corpspeak`). Everything below runs from a terminal; Xcode's
signed-in Apple ID handles authentication.

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

The app is useless without three things a reviewer's Mac may not have. Put this in the
**App Review Information → Notes** field, and attach a short screen recording of the app
translating a sentence so the reviewer can see it working even if they cannot set up a voice:

> Corpospeak runs entirely on-device and needs two macOS 26 features turned on:
>
> 1. Apple Intelligence (System Settings → Apple Intelligence & Siri) on an Apple silicon Mac.
>    The app rewrites speech with the on-device Foundation Models framework.
> 2. Microphone and Speech Recognition permission, which the app requests on first launch.
>
> Then say a sentence in plain English and pause. The app rewrites it as corporate jargon and
> reads it back in a system voice — no further setup needed. The voice menu also offers the
> user's own Personal Voice (System Settings → Accessibility → Personal Voice) as an optional
> alternative; it is not required to use the app.
>
> No account, no network, no data collection. Privacy policy: https://github.com/alexec/Corpospeak/blob/main/PRIVACY.md

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
