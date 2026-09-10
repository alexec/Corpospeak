#!/bin/sh
# Scores the shipping English → Corpospeak prompt for faithfulness on this Mac's on-device model.
#   scripts/eval_prompt.sh [runs per sentence, default 3] [-v to print every reply]
# Takes a few minutes. Compare the summary line before and after a prompt change.
set -e
cd "$(dirname "$0")/.."
out="$(mktemp -d)"
{
  echo 'import Foundation'
  echo 'import FoundationModels'
  echo 'import AVFoundation'
  echo 'import NaturalLanguage'
  echo 'import Observation'
  echo 'import os'
  # One file, so the app's file-private helpers are reachable from the harness.
  # Speaker.swift is deliberately not here: it reaches Kokoro, which reaches FluidAudio, which
  # swiftc can't resolve without the package — and the harness only scores text, so it never
  # needed the speaking stack.
  grep -hv '^import ' Corpospeak/CorpospeakStyle.swift Corpospeak/Services/Sentences.swift Corpospeak/Services/Translator.swift scripts/eval_prompt.swift
} > "$out/eval.swift"
swiftc -Onone -parse-as-library -o "$out/eval" "$out/eval.swift"
"$out/eval" "$@"
