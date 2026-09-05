#!/bin/sh
# Builds the probe app, installs it on an iPhone, runs it, and streams its results.
#   run_probe.sh [--runs N] [--device ID] [--build-only] [--keep]
# The phone must be unlocked and kept awake for the whole run (about a minute per variant per
# run); iOS suspends the probe the moment the screen locks and the output just stops.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
RUNS=1; DEVICE=""; BUILD_ONLY=0; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --build-only) BUILD_ONLY=1; shift ;;
    --keep) KEEP=1; shift ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

# Stage under the repo's ignored build/ dir: CoreDevice refuses to install from /tmp.
STAGE="$REPO/build/Probe/src"
rm -rf "$STAGE"; mkdir -p "$STAGE/Probe"
cp "$HERE/Probe/Probe.swift" "$HERE/Probe/Variants.swift" "$STAGE/Probe/"
cp "$REPO/Corpospeak/CorpospeakStyle.swift" "$STAGE/Probe/CorpospeakStyle.swift"
git -C "$REPO" show HEAD:Corpospeak/CorpospeakStyle.swift | sed 's/enum CorpospeakStyle/enum OldStyle/' > "$STAGE/Probe/OldStyle.swift"
TEAM="$(grep -m1 'DEVELOPMENT_TEAM' "$REPO/project.yml" | sed 's/.*DEVELOPMENT_TEAM: *//')"
sed "s/__TEAM__/$TEAM/" "$HERE/project.yml" > "$STAGE/project.yml"

cd "$STAGE"
xcodegen generate > /dev/null
echo "Building probe…"
# A generic destination never waits on the phone; the build is the same.
xcodebuild -project Probe.xcodeproj -scheme Probe -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath "$REPO/build/Probe/DerivedData" \
  -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | sort -u
APP="$REPO/build/Probe/DerivedData/Build/Products/Debug-iphoneos/Probe.app"
[ -d "$APP" ] || { echo "Build failed." >&2; exit 1; }
[ "$BUILD_ONLY" = 1 ] && { echo "Built $APP"; exit 0; }

if [ -z "$DEVICE" ]; then
  DEVICE="$(xcrun devicectl list devices 2>/dev/null | grep -i iphone | head -1 | awk '{for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-/) print $i}')"
fi
[ -n "$DEVICE" ] || { echo "No iPhone found. Pass --device ID." >&2; exit 1; }
echo "Installing on $DEVICE…"
xcrun devicectl device install app --device "$DEVICE" "$APP" 2>&1 | grep -iE "error|App installed" | head -2

echo "Running (unlock the phone and keep it awake)…"
xcrun devicectl device process launch --console --terminate-existing --device "$DEVICE" \
  com.alexcollins.CorpSpeak.probe "$RUNS" 2>&1 \
  | grep -E "^(OK|FAILED|SUMMARY|availability|DONE)|ERROR|Locked" \
  | sed -E 's/.*reason: Locked.*/LOCKED: unlock the phone and rerun./' | cut -c1-170

[ "$KEEP" = 1 ] || xcrun devicectl device uninstall app --device "$DEVICE" com.alexcollins.CorpSpeak.probe > /dev/null 2>&1 || true
