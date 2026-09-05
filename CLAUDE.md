# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Corpospeak (App Store: *Corpospeak: In Your Voice*) is a single SwiftUI app, built for Mac,
iPhone, and iPad from one target, that listens continuously, rewrites what you said into
"Corpospeak" (jargon-heavy corporate-speak) using the on-device Apple Intelligence model, and
reads the result back. Everything happens on-device — no network calls, nothing saved to disk.
That constraint is load-bearing throughout the code, not just a privacy footnote: dictation
requires on-device speech recognition and refuses to fall back to Apple's servers, and the
rewrite requires the on-device Foundation Models framework.

iOS is the primary platform — it's the fun one. macOS and iPadOS ride along on the same target
and should keep working, but when a choice needs to favor one platform, favor iOS/iPhone.

## Commands

The Xcode project is generated, not committed — `Corpospeak.xcodeproj` is gitignored. Regenerate
it after pulling or after any `project.yml` change:

```bash
xcodegen generate
```

Build (no separate lint step or test target exist in this repo):

```bash
xcodebuild -project Corpospeak.xcodeproj -scheme Corpospeak -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Corpospeak.xcodeproj -scheme Corpospeak -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Building for a real device needs `-destination 'id=<device-id>'` and `-allowProvisioningUpdates`.
**Before installing on a physical iPhone/iPad**, check it can actually run Apple Intelligence —
neither the App Store nor `devicectl` gates this, and there's no reliable Info.plist key for it
(confirmed via Apple's own developer forums: `UIRequiredDeviceCapabilities`'s
`iphone-performance-gaming-tier` checks GPU tier, not the Neural Engine Foundation Models needs):

```bash
scripts/check_apple_intelligence_eligible.py               # lists every connected device
scripts/check_apple_intelligence_eligible.py <device-id>   # exits 1 if that device isn't eligible
```

Releasing a build to the App Store (bumping `CFBundleVersion`, archiving both platforms,
exporting/uploading, App Review notes) is documented step-by-step in `RELEASING.md` — follow that
rather than reconstructing the process.

## Architecture

One pipeline, four services, wired together by one `@Observable` model:

```
SpeechListener → CorpospeakModel → Translator → CorpospeakModel → Speaker
   (mic → text)      (queues,          (on-device        (text → chosen voice,
                       drives phase)     rewrite)          sentence-by-sentence)
```

- **`Corpospeak/Services/SpeechListener.swift`** — keeps the microphone open for the app's
  lifetime via `SFSpeechRecognizer`, restarting recognition after each pause in speech and
  delivering one utterance per pause through `onUtterance`. Requires
  `recognizer.supportsOnDeviceRecognition`; if that's unavailable for the current language, it
  reports `.unavailable` rather than ever sending audio off-device.
- **`Corpospeak/Services/Translator.swift`** — one fresh `LanguageModelSession` per utterance
  (so rewrites don't carry context between sentences), built from the instructions/glossary in
  `CorpospeakStyle.swift`. Latency matters: the next session is `prewarm`ed while the app is
  idle so the instructions are already read when the user stops talking, and `translate`
  streams the reply so the first sentence is spoken while the rest is generated. Don't try to
  speed it up by trimming the instructions: on 2026-09-05, cutting the phrasebook to bare phrases
  (or the rules to a few lines) made the model copy example content, add preambles, and run on,
  in side-by-side runs against the full prompt. The prewarm hides the prompt's cost instead. `checkAvailability()` reflects `SystemLanguageModel.default.availability`
  so the UI can explain *why* (device ineligible, Apple Intelligence off, model still downloading)
  rather than just failing.
- **`Corpospeak/Services/Speaker.swift`** — speaks with a system voice by default (so it works
  in the Simulator, which can't create a Personal Voice) and offers every installed voice plus
  the user's own Personal Voice, once authorized, through a `voices: [VoiceOption]` list. The
  selected voice's identifier persists in `UserDefaults` across launches. Splits text into
  sentences (`NLTokenizer`), accepts them as a stream so speech can start before the reply is
  finished, and reports which sentence is currently playing so the UI can highlight it.
- **`Corpospeak/CorpospeakModel.swift`** — the only thing that talks to all three services. Owns
  a `Phase` enum the UI renders from (`starting`/`listening`/`muted`/`translating`/`speaking`/
  `error`), a small pending-utterance queue (so an utterance heard while still speaking isn't
  dropped), and pauses `SpeechListener` while `Speaker` is talking so the app doesn't transcribe
  its own voice.
- **`Corpospeak/CorpospeakStyle.swift`** — pure data: the Corpospeak glossary (phrase ↔ meaning,
  by chapter) and the prompt text built from it for both translation directions. This is the
  file to touch when changing the app's *voice* (the writing style, not the audio voice) rather
  than its mechanics. After any prompt change, run `scripts/eval_prompt.sh` (needs Apple
  Intelligence on this Mac): it scores how many of the speaker's facts survive, whether example
  text gets pasted into replies, and runaway length. Two things it has already caught: the
  few-shot examples must not be about work (the model pastes work examples into work
  sentences), and the prompt must not contain a list of jargon words (the model sometimes
  replies with the list). The on-device model differs between OS versions: the iOS 27 beta's
  guardrail refuses the prompt whenever the few-shot examples aren't about work, so
  `shortExamples` picks a set by OS version. The Mac harness only measures the Mac's model; to
  measure on a phone, build a throwaway app that runs the prompt and prints to stderr, and read
  it with `xcrun devicectl device process launch --console` (the phone must stay unlocked).
- **`Corpospeak/Views/ContentView.swift`** — the single window; `compact` (screen width < 600)
  tightens spacing/type for phones and narrow iPad splits.
- **`Corpospeak/Platform.swift`** — the few things that differ between macOS/iOS/iPadOS (the
  Settings app's name, opening Personal Voice settings, clipboard access) are isolated here
  rather than scattered behind `#if os()` checks elsewhere.

### Project generation

`project.yml` is the source of truth for build settings, target config, and the committed
`Info.plist`'s contents (`GENERATE_INFOPLIST_FILE: false` — xcodegen writes `Corpospeak/Info.plist`
from `project.yml`'s `info.properties`, and that generated file is committed, so editing one
without regenerating/re-syncing the other will drift). One target with
`supportedDestinations: [macOS, iOS]` builds all three platforms (iPadOS rides along with iOS);
platform-specific settings use xcodegen's `KEY[sdk=iphoneos*]` conditional syntax (see the
entitlements split between Mac sandbox and iOS in `project.yml`).
