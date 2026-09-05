# Corpospeak

On the App Store as *Corpospeak: In Your Voice*. An app for Mac, iPhone, and iPad that listens
to you continuously, rewrites what you said as Corpospeak using the on-device Apple Intelligence
model, and reads the result back to you in your own voice.

Everything runs on the device: dictation (Speech framework, on-device recognition), the rewrite
(Foundation Models framework), and playback with your Personal Voice (AVSpeechSynthesizer).
The app never touches the network.

## Requirements

- macOS 26, iOS 26, or iPadOS 26 with Apple Intelligence turned on (Settings → Apple Intelligence & Siri).
  That means a Mac with Apple silicon, an iPhone 15 Pro or later, or an iPad with an M1 or A17 Pro chip or later.
- A Personal Voice (Settings → Accessibility → Personal Voice)
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

The simulator cannot create a Personal Voice, so on a simulator the app stops at the setup screen.
Use a real device to hear it speak.

## How it fits together

| File | Role |
| --- | --- |
| `Corpospeak/Services/SpeechListener.swift` | Always-on microphone → `SFSpeechRecognizer`. Emits one utterance per pause in speech. |
| `Corpospeak/Services/Translator.swift` | Sends an utterance to the on-device `LanguageModelSession` and returns the rewrite. |
| `Corpospeak/Services/Speaker.swift` | Reads text aloud with the user's Personal Voice one sentence at a time and reports which sentence is playing. |
| `Corpospeak/CorpospeakStyle.swift` | The Corpospeak glossary and prompt, taken from [The Corpospeak Field Guide](https://claude.ai/code/artifact/0a819392-f474-464f-8815-0073bd7845e9). |
| `Corpospeak/CorpospeakModel.swift` | Wires the three services together: listen → translate → speak → listen. |
| `Corpospeak/Views/ContentView.swift` | The single window. Tightens its spacing and type on narrow screens. |

Listening is paused while the app is speaking so it does not transcribe its own voice.

Corpospeak makes no network connections and keeps nothing. See [PRIVACY.md](PRIVACY.md).

## Voice

Corpospeak speaks only in your own voice, using the Personal Voice that the system creates.
Create one in Settings → Accessibility → Personal Voice (ten phrases, about a minute), turn on
*Allow Apps to Request to Use*, then choose *Use my Personal Voice…* in the app and allow it.
The app notices as soon as a voice appears, and nothing is spoken until then. You can withdraw
access, or record a new voice, in the same Settings pane.

Long replies are spoken one sentence at a time, and the window scrolls to keep the current
sentence in view. Tapping the status pill (or Escape) cuts a reply off; ⌘M mutes the microphone.
