# Contributing

## Requirements

- macOS 26, iOS 26, or iPadOS 26 with Apple Intelligence turned on
  (Settings → Apple Intelligence & Siri). That means a Mac with Apple silicon,
  an iPhone 15 Pro or later, or an iPad with an M1 or A17 Pro chip or later.
- Xcode 26
- [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the project file

## Build and run

```bash
xcodegen generate
open Corpospeak.xcodeproj
```

Then pick My Mac, an iPhone, or an iPad as the destination and press Run. The
first launch asks for Microphone and Speech Recognition permission.

Or from the terminal:

```bash
xcodebuild -project Corpospeak.xcodeproj -scheme Corpospeak -configuration Debug -destination 'platform=macOS' build
```

```bash
xcodebuild -project Corpospeak.xcodeproj -scheme Corpospeak -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The single target builds for all three platforms. `Corpospeak/Platform.swift`
holds the few things that differ between them (the settings app's name, the
clipboard, and how to open the Personal Voice settings), and
`Corpospeak/Services/AudioSession.swift` configures the iOS audio session so the
microphone and playback share it.

The app speaks with a system voice out of the box, so the Simulator works too —
including hearing it speak, since the Simulator ships system voices even though
it cannot create a Personal Voice.

## First run

Corpospeak is a **one prerequisite** app in `in-app-help`'s terms: the microphone *is* the
app, so it is primed on the first screen and nothing else is shown first.

`Corpospeak/Views/FirstRun.swift` says what the app does, that it listens the whole time it
is open, and that nothing leaves the device. One button, "Start listening", and it opens the
system alerts — Speech Recognition, then the Microphone. There is deliberately no way past
that view that skips the alert; the HIG forbids it and App Review checks.

It is **not a sheet**. A sheet is a tour you dismiss; this is the app asking for the one thing
it needs, with its own chrome already visible above it.

The Personal Voice is *not* asked here. It is offered in the voice menu, at the moment someone
goes looking for a better voice, so a new user meets one alert chain rather than three.

To see it again without deleting the app, `CorpospeakModel.forgetFirstRun()` is there in Debug
builds. To walk it properly as a new user:

```bash
xcrun simctl uninstall <udid> com.alexcollins.CorpSpeak
xcrun simctl privacy <udid> reset all com.alexcollins.CorpSpeak
```

## The voices

Corpospeak prefers the user's Personal Voice, then Kokoro, then one of Apple's
built-in voices. Apple's are a fallback rather than a choice: they sound bad,
Enhanced and Premium downloads included.

Kokoro ships **inside the app** — `Corpospeak/KokoroModels`, about 95MB — rather
than downloading on first run, because `PRIVACY.md` promises the app makes no
network connections at all and that promise is in the App Review notes.
`ModelHub.offlineMode` is switched on so a missing file throws instead of quietly
fetching one. Don't replace that with a download; see
[docs/voice-engine.md](docs/voice-engine.md) for why, and for the licence
diligence (Kokoro's usual phonemizer, espeak-ng, is GPL-3.0 — FluidAudio's Core ML
one is not, which is a large part of why it was chosen).

The FluidAudio version is pinned exactly, and Actionable pins the same one. Bump
them together.

To check Kokoro loads offline and measure how fast it synthesizes:

```bash
swift run --package-path Tools/KokoroCheck KokoroCheck
```

It prints to stderr. Run it on its own — two processes competing for the Neural
Engine produce numbers that look like a catastrophe and mean nothing.

## Installing on a physical device

Neither the App Store nor `devicectl` checks a device's Apple Intelligence
eligibility before installing — there's no reliable Info.plist or App Store
Connect setting for it (Apple's own DTS engineers have confirmed as much: the
closest key, `UIRequiredDeviceCapabilities`'
`iphone-performance-gaming-tier`, checks GPU tier, not the Neural Engine
Foundation Models needs). So an ineligible device (e.g. the base iPad's A16
chip, one tier short of what Apple Intelligence needs) will happily accept an
install and then simply never be able to rewrite anything. Check before
installing:

```bash
scripts/check_apple_intelligence_eligible.py               # lists every connected device
scripts/check_apple_intelligence_eligible.py <device-id>    # exits 1 if that device isn't eligible
```

## How it fits together

| File | Role |
| --- | --- |
| `Corpospeak/Services/SpeechListener.swift` | Always-on microphone → `SFSpeechRecognizer`. Emits one utterance per pause in speech. |
| `Corpospeak/Services/Translator.swift` | Sends an utterance to the on-device `LanguageModelSession` and returns the rewrite. |
| `Corpospeak/Services/Speaker.swift` | Reads text aloud one sentence at a time with the chosen voice, starting as soon as the first sentence is written, and reports which sentence is playing. Owns the voice list and the order it prefers them in: Personal Voice, then Kokoro, then Apple's built-in voices. |
| `Corpospeak/Services/KokoroSynthesizer.swift` | Kokoro 82M on the Neural Engine, through FluidAudio. The only file in the app that imports it. |
| `Corpospeak/Services/KokoroEngine.swift` | Plays what Kokoro synthesizes, making the next sentence while the current one is still playing. |
| `Corpospeak/CorpospeakStyle.swift` | The Corpospeak glossary and prompt, taken from [The Corpospeak Field Guide](https://claude.ai/code/artifact/0a819392-f474-464f-8815-0073bd7845e9). |
| `Corpospeak/CorpospeakModel.swift` | Wires the three services together: listen → translate → speak → listen. |
| `Corpospeak/Views/ContentView.swift` | The single window. Tightens its spacing and type on narrow screens. |

Listening is paused while the app is speaking so it does not transcribe its own
voice.

Speech recognition is on-device only; if the device cannot recognise the user's
language by itself, the app says so rather than sending audio to Apple. Keep it
that way — see [PRIVACY.md](PRIVACY.md).

## Releasing

To ship a build to the App Store, see [RELEASING.md](RELEASING.md).
