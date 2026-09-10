# Backlog

1. **Test on iPhone, iPad, and macOS.** Debug builds for macOS and the iOS Simulator both
   succeed on this branch. Run the app on each platform and check the full loop: listen →
   translate → speak, the voice menu (Personal Voice and system voices), mute, and stop.
   Note: the paired iPad (A16) is not Apple Intelligence eligible
   (`scripts/check_apple_intelligence_eligible.py`), so iPad testing needs an M1/A17 Pro or
   later iPad; the paired iPhone 15 Pro Max is eligible.
2. **User testing.** Put a TestFlight build in front of a few people and collect feedback on
   the translations, the voice, and first-launch permission prompts.
3. **Get the current code onto the App Store, and add the iOS platform.** macOS 1.0 went
   live on 2026-09-10 (approved 02:41, released automatically) — but the build attached to
   that version is **1.0 (1)**, uploaded Sep 4. Builds 2 and 3 were uploaded and never
   attached, so the Personal Voice default, the translation speed-up and Kokoro are all
   absent from the shipped app. Two separate jobs:
   - **A new macOS version.** Create 1.0.1 (or 1.1) in App Store Connect, bump
     `CFBundleVersion` past 3, archive, upload, attach, submit. The review notes in
     `RELEASING.md` §4 cleared review once and should be reused.
   - **The iOS platform, which has never been submitted.** The App Store record is macOS-only
     ("Add Platform" on the version page; the listing reads "Only for Mac"), even though iOS
     is the primary platform. It needs its own screenshots, its own screen recording (the
     iPhone 15 Pro Max is the only paired device that can make one), and its own review.
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

## Won't build

- **Downloading voices from HuggingFace on demand.** Keeps the app small, but PRIVACY.md and the
  README both promise no network connections at all, and that promise is in the App Store review
  notes. Bundle the model instead. If size ever forces the issue, Apple's On-Demand Resources is
  the fallback, not a third-party fetch.
