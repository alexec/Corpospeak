# Backlog

1. **Test on iPhone, iPad, and macOS.** Debug builds for macOS and the iOS Simulator both
   succeed on this branch. Run the app on each platform and check the full loop: listen →
   translate → speak, the voice menu (Personal Voice and system voices), mute, and stop.
   Note: the paired iPad (A16) is not Apple Intelligence eligible
   (`scripts/check_apple_intelligence_eligible.py`), so iPad testing needs an M1/A17 Pro or
   later iPad; the paired iPhone 15 Pro Max is eligible.
2. **User testing.** Put a TestFlight build in front of a few people and collect feedback on
   the translations, the voice, and first-launch permission prompts.
3. **Get the current code onto the App Store.** macOS 1.0 went live on 2026-09-10
   (approved 02:41, released automatically) but the build attached to that version is
   **1.0 (1)**, uploaded Sep 4. Builds 2 and 3 were uploaded and never attached, so the
   Personal Voice default, the translation speed-up and Kokoro are all absent from the
   shipped app.
   - **iOS is now on the record and waiting on screenshots.** The iOS platform was added
     on 2026-09-10 and **1.0 (4)** is uploaded and attached to iOS 1.0, with the
     description, keywords, support URL, copyright, contact details and App Review notes
     filled in, and release set to manual. It is deliberately not submitted; the version
     page still reads *Add for Review*, so this is a first submission and not a
     resubmission. Three things were outstanding when App Store Connect was checked on
     2026-09-10: **iPhone 6.5" screenshots (0 of 10)**, **iPad 13" screenshots (0 of 10)**,
     and the **Guideline 2.1 screen recording**, which is not attached (App Review
     Information → Attachment is empty). The iOS 27 guardrail that used to block these is
     fixed (item 5). **The iPad set is now shot** (next bullet) and needs uploading. The
     iPhone set and the recording still need the iPhone 15 Pro Max, which is the one
     Apple-Intelligence-eligible device in the house, because both want a real Personal
     Voice and a real microphone.
   - **The iPad set is shot: three frames, 2026-09-11.** `Corpospeak/AppStore/screenshots/en-US`
     holds `1-translated.png`, `2-listening.png` and `4-speaking.png`, each 2752 × 2064,
     landscape, from a **Release** build on an iPad Pro 13-inch (M5) simulator, iOS 26.5.
     They are in the repo and still have to be uploaded to App Store Connect.
     What unblocked it was seeding the utterance through a launch argument
     (`Corpospeak/DemoOptions.swift`), the Brushwise pattern: read from `UserDefaults`, **not**
     DEBUG-gated so a Release build honours it, feeding `handleUtterance()` rather than drawing
     anything. Only the recogniser is skipped; the rewrite, the panels, the status pill and the
     speech all run for real, and with no argument passed nothing about the app changes.
     `RELEASING.md`'s *Screenshots* section has the steps.
     Why the recogniser has to be skipped, measured 2026-09-10 and unchanged:
     - **On-device speech recognition does not work in the Simulator.** The microphone path
       is fine — the Mac's speakers playing `say` drive the app's level meter well above
       ambient — but `localspeechrecognition` fails to build a recognizer on every restart
       (`_EARSpeechRecognizer is nil`, `Failed to create recognizer from … mini.json`). The
       en_US ASR model ships as `UC_SIRI_ASR_ASSISTANT_…_Cryptex.dmg`, and the simulator
       never mounts cryptexes, so `mini.json` is unreachable. `SpeechListener` sets
       `requiresOnDeviceRecognition = true` (Services/SpeechListener.swift:235) and will not
       fall back, by design. So no transcript is possible there, whoever is talking.
     - **The rewrite itself works.** `SystemLanguageModel.default.availability` reports
       `available` inside that simulator, verified with a probe binary run through
       `simctl spawn`. Foundation Models was never the blocker; ASR was.
   - **There is no iPad frame 3, and there should not be one.** It wanted the voice menu with
     the user's Personal Voice at the top, which is the app's best feature. No simulator has a
     Personal Voice (`offersPersonalVoice` is false while the status is `.unsupported`) and
     Kokoro is switched off on the 26.4+ iOS line, so the menu there lists Apple's system
     voices alone — the opposite of what the frame is for. Faking the row would advertise
     something the app cannot do on the reviewer's device. App Store Connect accepts three, so
     the iPad set ships as three; the voice frame belongs to the iPhone set, shot on the
     iPhone 15 Pro Max where a real Personal Voice exists.
   - **Build 5 has never been uploaded.** `project.yml` says 1.0 (5) and the branch
     `claude/ship-build-5` carries the bump plus *Explain the app before asking for the
     microphone*. App Store Connect has builds 3 and 4 only. Decide before submitting
     whether iOS 1.0 goes out as build 4, which is attached now and does not have the
     permission explanation, or as build 5, which needs an archive and upload first.
   - **A new macOS version is still outstanding.** Create 1.0.1 (or 1.1), archive and
     upload build 4 or later for macOS, attach it, submit. The review notes in
     `RELEASING.md` §4 cleared review once, but they now say the app has no third-party
     SDKs and uses only Apple frameworks, which stopped being true when Kokoro landed. The
     iOS notes in App Store Connect have the corrected wording to copy from.
4. **Kokoro as the default voice when there's no Personal Voice.** Design, licence diligence and
   the bundling decision are in [docs/voice-engine.md](docs/voice-engine.md). Blocked on the
   Actionable streaming-diarization task choosing a Kokoro port, so both apps standardise on one
   dependency. Once it lands: add the package, write the text→PCM adapter, vendor the model
   subset into the bundle with network access off, change the default-voice ladder to
   Personal Voice → Kokoro → Apple, and synthesize sentence N+1 while N plays.
   - **Check the port doesn't link espeak-ng before adopting it** — it's GPL-3.0 and this app
     ships on the App Store. `mattmireles/kokoro-coreml` doesn't document its tokenizer; the
     other three use Misaki or a Core ML G2P.
   - Measure RTF on the iPhone 15 Pro Max (which is the oldest device the app supports, since
     Apple Intelligence sets the floor) *while a rewrite is streaming* — Kokoro and Foundation
     Models contend for the Neural Engine, so the 0.08 figure measured alone isn't the one that
     matters.
   - Budget well above the 80MB the ONNX figure suggests: FluidAudio's Core ML build is ~300MB
     all in, ~23MB of which is G2P lexicons.

5. **~~The iOS 27 model refuses rewrites.~~ Fixed 2026-09-09** by naming the task as parody
   of the speaker's own words in the opening line (phone refusals 2/12 → 0/11). Kept below
   for the reasoning, which still applies to any future prompt change.

   **The iOS 27 model refuses rewrites.** The phone reports the model available and the
   OS example split working ("work (OS 27+)"), so it is the guardrail rejecting the
   content, not a wrong example set. Simplifying the prompt is measurably the wrong fix:
   cutting the phrasebook from 95 terms to 20 took facts kept from 84% to 64% on the Mac
   model while refusals did not move (n=24 each). The untested hypothesis is that the
   *instructions* are the trigger, not the examples: "evasive", "the ask gets buried" and
   "it should take the listener a moment to work out what was actually asked" describe
   deliberate obfuscation. Five variants changing exactly one such phrase each are staged
   in `.claude/skills/prompt-eval/scripts/probe/Probe/Variants.swift`; run the phone probe
   with the iPhone unlocked and awake. This blocks the iOS screenshots and the App Review
   screen recording in item 3, so it is the next thing to do.

## Won't build

- **Downloading voices from HuggingFace on demand.** Keeps the app small, but PRIVACY.md and the
  README both promise no network connections at all, and that promise is in the App Store review
  notes. Bundle the model instead. If size ever forces the issue, Apple's On-Demand Resources is
  the fallback, not a third-party fetch.

## Minor review findings

- [x] ASR-metadata · 2026-09-10 · App Store Connect → App Information · subtitle read
  "Say it. Hear it in CorpSpeak", spelling the app the old way. Now "Say it. Hear it in
  Corpospeak" (29 of 30 characters). Goes out with the next version.
- [x] ASR-privacy · 2026-09-10 · App Store Connect → App Privacy · the privacy policy URL
  was pinned to commit 22c7dc3 under the old repo name (`alexec/CorpSpeak`), serving a
  Mac-only policy dated 4 September that said speech "may send audio to Apple for
  recognition". Now `https://github.com/alexec/Corpospeak/blob/main/PRIVACY.md`, so it
  tracks the policy instead of freezing a copy of it.
- [x] ASR-rights · 2026-09-10 · App Store Connect → App Information · Content Rights said
  the app contains no third-party content, while it bundles the Apache-2.0 Kokoro model.
  Now "Yes, this app has the necessary rights to its third-party content", which Apache 2.0
  grants and the App Review notes already disclose.
- [ ] ASR-settings · 2026-09-11 · `Corpospeak/Views/` · the app has no Settings screen at
  all, so there is no *How it works* row to re-read the first-run sheet from and no
  Debug-only Developer section to replay it. Every app has one, even when the middle is
  empty, in which case the entry point itself is Debug-only. Filed as T176.
- [ ] ASR-attribution · 2026-09-10 · repo root · nothing in the app or the repo carries the
  Apache-2.0 licence text for Kokoro or FluidAudio. Apache 2.0 §4 asks for it with any
  distribution. There is no Settings screen to put an acknowledgements row in yet.

## Privacy audit

_T103 · 2026-09-11 · cross-app audit of all fifteen policies. Full report in
`~/Tracking/PRIVACY-AUDIT.md`. Verdict for this app: **inconsistent**. Nothing
in `PRIVACY.md` is false._

- [ ] **The first-run sheet does not close on the house line.** `Views/FirstRun.swift:27`
  ends on "Nothing leaves your \(Platform.device). The rewriting and the voice
  both run here." That is true, well put, and not "Private and free forever",
  which every other app with a sheet closes on. Twelve of fifteen carry the
  line; this is the only app that has a sheet and ends it on something else. The
  existing sentence is worth keeping, so the fix is to follow it with the house
  line rather than replace it.

- [ ] **The YouTube link is undisclosed.** `Views/ContentView.swift:772` is a
  `Link` to `youtube.com/shorts/JNRDj799VK4`. Tapping it hands the user to
  Google. The app makes no request itself, so "Corpospeak makes no network
  connections" stays true, but a person who reads the policy and then taps the
  link has been surprised. Hard Stop discloses exactly this shape of behaviour
  in one sentence: "your Mac opens the meeting link in the app or browser you
  already use. What that app then does is between you and whoever runs the
  meeting." One line in the Network section does it.

- [ ] **"No third-party services" needs a word about FluidAudio.** The claim is
  defensible, because FluidAudio 0.15.6 is compiled in and `KokoroSynthesizer.swift:51`
  reads the models out of `Bundle.main` with no runtime download, which was
  checked. But it is the one claim in the set that asks the reader to know what
  "service" excludes, and the app does ship somebody else's code. A clause
  saying the model and the library that loads it are built in, which the Voices
  section already half says, closes it.

Not findings, recorded so they are not rechecked: `SpeechListener.swift:235`
sets `requiresOnDeviceRecognition = true` and `:87` refuses to listen at all
without `supportsOnDeviceRecognition`, so the no-fallback promise in the policy
is real and is one of the three that states it properly.
`PrivacyInfo.xcprivacy` is present and matches. App Store labels should read
"Data Not Collected", nothing else ticked.
