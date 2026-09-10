#!/usr/bin/env bash
# Downloads the Kokoro models the app bundles, into Corpospeak/KokoroModels.
#
# They are not in git: ~95MB of third-party binaries, reproducible from a pinned revision, and
# git history is forever. This is a build-time fetch on your Mac, like Swift Package Manager
# already does for FluidAudio itself — the *app* still makes no network connections at runtime,
# which is the promise that matters (see PRIVACY.md and docs/voice-engine.md).
#
# Only the English Neural Engine subset is fetched. The full repo is 4.7GB of variants we don't
# ship.
set -euo pipefail

REPO="FluidInference/kokoro-82m-coreml"
# Pinned so two machines get byte-identical models. Bump deliberately, with FluidAudio.
REVISION="main"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/Corpospeak/KokoroModels"

python3 - "$REPO" "$REVISION" "$DEST" <<'PY'
import json, os, sys, urllib.request

repo, revision, dest = sys.argv[1], sys.argv[2], sys.argv[3]
api = f"https://huggingface.co/api/models/{repo}/tree/{revision}?recursive=true"
tree = json.load(urllib.request.urlopen(api))

# The seven-stage ANE chain, its vocab and voice pack, and the shared G2P assets. The .mlpackage
# twins are the uncompiled form and are not needed.
ane_dirs = ["KokoroAlbert", "KokoroPostAlbert", "KokoroAlignment", "KokoroProsody",
            "KokoroNoise_v2", "KokoroVocoder", "KokoroTail"]
ane_files = {"ANE/vocab.json", "ANE/af_heart.bin", "ANE/LICENSE"}
root_dirs = ["G2PEncoder.mlmodelc", "G2PDecoder.mlmodelc"]
root_files = {"g2p_vocab.json", "us_lexicon_cache.json"}

wanted = []
for entry in tree:
    if entry["type"] != "file":
        continue
    path = entry["path"]
    size = entry.get("size") or (entry.get("lfs") or {}).get("size") or 0
    if path in ane_files or any(path.startswith(f"ANE/{d}.mlmodelc/") for d in ane_dirs):
        local = "Models/kokoro-82m-coreml/ANE/" + path.split("/", 1)[1]
    elif path in root_files or any(path.startswith(d + "/") for d in root_dirs):
        local = "Models/kokoro/" + path
    else:
        continue
    wanted.append((path, local, size))

total = sum(s for _, _, s in wanted)
print(f"{len(wanted)} files, {total / 1e6:.1f} MB")

base = f"https://huggingface.co/{repo}/resolve/{revision}/"
for i, (path, local, size) in enumerate(wanted, 1):
    out = os.path.join(dest, local)
    if os.path.exists(out) and os.path.getsize(out) == size:
        continue
    os.makedirs(os.path.dirname(out), exist_ok=True)
    print(f"  [{i}/{len(wanted)}] {path}")
    urllib.request.urlretrieve(base + path, out)

missing = [l for _, l, s in wanted
           if not os.path.exists(os.path.join(dest, l))
           or os.path.getsize(os.path.join(dest, l)) != s]
if missing:
    sys.exit(f"incomplete: {len(missing)} file(s) wrong size, re-run")
print(f"ok — {dest}")
PY
