# Backlog

1. **Test on iPhone, iPad, and macOS.** Debug builds for macOS and the iOS Simulator both
   succeed on this branch. Run the app on each platform and check the full loop: listen →
   translate → speak, the voice menu (Personal Voice and system voices), mute, and stop.
   Note: the paired iPad (A16) is not Apple Intelligence eligible
   (`scripts/check_apple_intelligence_eligible.py`), so iPad testing needs an M1/A17 Pro or
   later iPad; the paired iPhone 15 Pro Max is eligible.
2. **User testing.** Put a TestFlight build in front of a few people and collect feedback on
   the translations, the voice, and first-launch permission prompts.
3. **Publish to the App Store.** Build 1.0 (3) is already uploaded; the Personal Voice
   default and translation speed-up landed after it, so bump `CFBundleVersion` to 4 and
   follow `RELEASING.md` to archive, upload, and submit both platforms.
