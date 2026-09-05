# Corpospeak

On the App Store as *Corpospeak: In Your Voice*. An app for Mac, iPhone, and iPad that listens
to you continuously, rewrites what you said as Corpospeak using the on-device Apple Intelligence
model, and reads the result back to you.

Everything runs on the device: dictation (Speech framework, on-device recognition), the rewrite
(Foundation Models framework), and playback (AVSpeechSynthesizer). The app never touches the
network.

## Requirements

- macOS 26, iOS 26, or iPadOS 26 with Apple Intelligence turned on (Settings → Apple Intelligence & Siri).
  That means a Mac with Apple silicon, an iPhone 15 Pro or later, or an iPad with an M1 or A17 Pro chip or later.
- Xcode 26
- [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the project file

## Build and run

```bash
xcodegen generate
open Corpospeak.xcodeproj
```

Then pick My Mac, an iPhone, or an iPad as the destination and press Run. The first launch asks
for Microphone and Speech Recognition permission.

Or from the terminal:

```bash
xcodebuild -project Corpospeak.xcodeproj -scheme Corpospeak -configuration Debug -destination 'platform=macOS' build
```

```bash
xcodebuild -project Corpospeak.xcodeproj -scheme Corpospeak -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The single target builds for all three platforms. `Corpospeak/Platform.swift` holds the few
things that differ between them (the settings app's name, the clipboard, and how to open the
Personal Voice settings), and `Corpospeak/Services/AudioSession.swift` configures the iOS audio
session so the microphone and playback share it.

Speaks with a system voice out of the box, so the Simulator works too — including hearing it
speak, since the Simulator ships system voices even though it cannot create a Personal Voice.

### Installing on a physical device

Neither the App Store nor `devicectl` checks a device's Apple Intelligence eligibility before
installing — there's no reliable Info.plist or App Store Connect setting for it (Apple's own DTS
engineers have confirmed as much: the closest key, `UIRequiredDeviceCapabilities`'
`iphone-performance-gaming-tier`, checks GPU tier, not the Neural Engine Foundation Models needs).
So an ineligible device (e.g. the base iPad's A16 chip, one tier short of what Apple Intelligence
needs) will happily accept an install and then simply never be able to rewrite anything. Check
before installing:

```bash
scripts/check_apple_intelligence_eligible.py               # lists every connected device
scripts/check_apple_intelligence_eligible.py <device-id>    # exits 1 if that device isn't eligible
```

## How it fits together

| File | Role |
| --- | --- |
| `Corpospeak/Services/SpeechListener.swift` | Always-on microphone → `SFSpeechRecognizer`. Emits one utterance per pause in speech. |
| `Corpospeak/Services/Translator.swift` | Sends an utterance to the on-device `LanguageModelSession` and returns the rewrite. |
| `Corpospeak/Services/Speaker.swift` | Reads text aloud one sentence at a time with the chosen voice (system, or the user's Personal Voice), starting as soon as the first sentence is written, and reports which sentence is playing. |
| `Corpospeak/CorpospeakStyle.swift` | The Corpospeak glossary and prompt, taken from [The Corpospeak Field Guide](https://claude.ai/code/artifact/0a819392-f474-464f-8815-0073bd7845e9). |
| `Corpospeak/CorpospeakModel.swift` | Wires the three services together: listen → translate → speak → listen. |
| `Corpospeak/Views/ContentView.swift` | The single window. Tightens its spacing and type on narrow screens. |

Listening is paused while the app is speaking so it does not transcribe its own voice.

Corpospeak makes no network connections and keeps nothing. See [PRIVACY.md](PRIVACY.md).
Speech recognition is on-device only; if your device cannot recognise your language by itself,
the app says so rather than sending audio to Apple.

To ship a build to the App Store, see [RELEASING.md](RELEASING.md).

## Voice

Corpospeak is at its best in your own voice, so it asks to use your Personal Voice on first
launch and speaks with it by default as soon as it can. Create one in Settings → Accessibility →
Personal Voice (ten phrases, about a minute), turn on *Allow Apps to Request to Use*, and allow
Corpospeak to use it; until then the app nudges you toward that and speaks with a system voice
picked for the current language, so it works right away regardless. The voice menu lists your
Personal Voice first, then every installed system voice; a voice you pick there is remembered
across launches. You can withdraw Corpospeak's access to the Personal Voice, or record a new
one, in the same Settings pane.

Long replies are spoken one sentence at a time, and the window scrolls to keep the current
sentence in view. Tapping the status pill (or Escape) cuts a reply off; ⌘M mutes the microphone.
