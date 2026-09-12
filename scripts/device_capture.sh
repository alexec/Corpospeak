#!/bin/bash
# Take Corpospeak's App Store frames and its Guideline 2.1 recording off Alex's own iPhone,
# with nobody at the desk.
#
# Why the phone and not a simulator: on-device speech recognition never starts in any iOS
# simulator (the en_US model ships as a cryptex the simulator does not mount), and no simulator
# has a Personal Voice. Both are in shot. See ~/Tracking/CAPTURE.md.
#
# The sentences arrive through the air: the Mac speaks them through its own speakers and the
# phone hears them through its own microphone. ~/Tracking/BENCH.md measured that path at 2% word
# error with the Mac's output volume at 32%, which is where this script puts it.
#
#   scripts/device_capture.sh recording   # T038: delete the app, film every permission prompt
#   scripts/device_capture.sh frames      # T037: the four App Store stills
#   scripts/device_capture.sh both
#
# Claim the phone first — this script drives it and does not claim for you:
#   SLOT=~/.claude/skills/simulator-testing/assets/sim-slot.sh
#   UDID=$("$SLOT" claim-device iphone --app Corpospeak)
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE="${CORPOSPEAK_DEVICE:-1A20DB49-E8EF-5931-B9CF-83F50B10CA1D}"   # Alex's iPhone 15 Pro Max
BUNDLE_ID="com.alexcollins.CorpSpeak"
DD="${CORPOSPEAK_DERIVED_DATA:-/tmp/corpospeak-device-capture}"
OUT="${CORPOSPEAK_OUT:-build/device-capture}"
SCHEME="CorpospeakUITests"

# BENCH.md's measured setting. 19% (his own) also works and is a few points worse; below 12%
# nothing survives. Put back on the way out, whatever happens.
CAPTURE_VOLUME="${CORPOSPEAK_VOLUME:-32}"
ORIGINAL_VOLUME="$(osascript -e 'output volume of (get volume settings)')"
SPEAKER_PID=""

cleanup() {
  [ -n "$SPEAKER_PID" ] && kill "$SPEAKER_PID" 2>/dev/null || true
  osascript -e "set volume output volume $ORIGINAL_VOLUME" 2>/dev/null || true
  "$KOKORO" --stop-server >/dev/null 2>&1 || true
}
trap cleanup EXIT

KOKORO="$(command -v kokoro || echo "$HOME/.local/bin/kokoro")"
if [ ! -x "$KOKORO" ]; then
  echo "kokoro not found — falling back to say, which transcribes worse (see the skill)" >&2
  KOKORO=""
fi

# What the app is asked to rewrite. Plain English on purpose: the joke only lands if the input
# is something a person would actually say. The first is short, because frame 1 wants the whole
# loop legible in one picture; the second is long, because frame 4 wants a reply of several
# sentences with one of them lit mid-read.
SHORT_LINE="We should talk about this properly before anyone commits to a date."
LONG_LINE="Nobody read the document before the meeting, so we spent an hour going over what was already written down, and we still have not decided who is actually doing the work or when it is due."

# am_michael, because ~/Kokoro measured it at 3.32% word error against this recogniser and
# af_heart at 4.74%. The model author's grades do not predict this and are not the thing to
# pick on; --list-voices carries the measured column.
VOICE="${CORPOSPEAK_VOICE:-am_michael}"

say_line() {
  if [ -n "$KOKORO" ]; then "$KOKORO" -v "$VOICE" "$1"; else say "$1"; fi
}

# The frames are one ordered sequence, so the speech is a schedule rather than a loop: frame 2
# is the empty state and has to be taken before anything is said. The test waits on the app's
# own status pill rather than on a clock, so these times only have to be roughly right.
start_speaking() {
  (
    sleep 30                 # launch, first run, and frame 2 taken
    say_line "$SHORT_LINE"   # frame 1
    # Long enough that the app has finished reading the first reply before the next line
    # arrives. A shorter gap put the app back into Translating while frame 1 was being taken.
    sleep 55
    say_line "$LONG_LINE"    # frame 4
    # Nothing after this: frame 3 is the voice menu and wants the app quiet behind it.
  ) &
  SPEAKER_PID=$!
}

# The recording is a different job: it is filming permission prompts, and the app should be
# heard doing its job at the end of it, so this one just keeps talking.
start_speaking_for_recording() {
  (
    sleep 20                 # launch, the first-run view, and both permission alerts
    for _ in 1 2 3; do
      say_line "$SHORT_LINE"
      sleep 18
    done
  ) &
  SPEAKER_PID=$!
}

export_results() {
  local bundle="$1" dest="$2"
  rm -rf "$dest" && mkdir -p "$dest"
  xcrun xcresulttool export attachments --path "$bundle" --output-path "$dest" >/dev/null
  # xcresulttool names files by uuid; the manifest carries the name the test gave them.
  python3 - "$dest" <<'PY'
import json, os, shutil, sys
dest = sys.argv[1]
manifest = os.path.join(dest, "manifest.json")
for test in json.load(open(manifest)):
    for att in test.get("attachments", []):
        src = os.path.join(dest, att["exportedFileName"])
        # "1-midloop_0_<uuid>.png" -> "1-midloop.png"
        name = att.get("suggestedHumanReadableName") or att["exportedFileName"]
        stem, ext = os.path.splitext(name)
        clean = stem.split("_0_")[0].replace(" ", "-") + ext
        if os.path.exists(src):
            shutil.move(src, os.path.join(dest, clean))
            print("  " + clean)
PY
}

build() {
  xcodegen generate >/dev/null
  echo "==> building for testing"
  xcodebuild build-for-testing -project Corpospeak.xcodeproj -scheme "$SCHEME" \
    -configuration Debug -destination "id=$DEVICE" -derivedDataPath "$DD" \
    -allowProvisioningUpdates >/dev/null
}

run_tests() {
  local only="$1" bundle="$2"
  rm -rf "$bundle"
  xcodebuild test-without-building -project Corpospeak.xcodeproj -scheme "$SCHEME" \
    -destination "id=$DEVICE" -derivedDataPath "$DD" -resultBundlePath "$bundle" \
    -only-testing:"$only" 2>&1 | grep -E "Test Case|answered|error:|PERSONAL VOICE|voice button|frame [0-9] —|frame is" || true
}

do_recording() {
  echo "==> T038: the Guideline 2.1 recording, from deleted"
  # The delete is the point. A reviewer sees every permission prompt as a new user meets them,
  # which is only true if iOS has no answers stored for this app.
  xcrun devicectl device uninstall app --device "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
  osascript -e "set volume output volume $CAPTURE_VOLUME"
  start_speaking_for_recording
  run_tests "CorpospeakUITests/FirstRunFromDeleted" "$DD/recording.xcresult"
  kill "$SPEAKER_PID" 2>/dev/null || true; SPEAKER_PID=""
  echo "==> exporting to $OUT/recording"
  export_results "$DD/recording.xcresult" "$OUT/recording"
}

do_frames() {
  echo "==> T037: the four App Store stills"
  osascript -e "set volume output volume $CAPTURE_VOLUME"
  start_speaking
  run_tests "CorpospeakUITests/AppStoreFrames" "$DD/frames.xcresult"
  kill "$SPEAKER_PID" 2>/dev/null || true; SPEAKER_PID=""
  echo "==> exporting to $OUT/frames"
  export_results "$DD/frames.xcresult" "$OUT/frames"
}

case "${1:-both}" in
  recording) build; do_recording ;;
  frames)    build; do_frames ;;
  both)      build; do_recording; do_frames ;;
  *) echo "usage: $0 [recording|frames|both]" >&2; exit 2 ;;
esac

echo
echo "Frames are 1290 x 2796, which App Store Connect accepts for the 6.9-inch iPhone slot."
echo "Upload them as they come off the phone; do not resample."
