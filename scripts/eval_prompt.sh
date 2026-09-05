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
  grep -hv '^import ' Corpospeak/CorpospeakStyle.swift Corpospeak/Services/Translator.swift Corpospeak/Services/Speaker.swift scripts/eval_prompt.swift
} > "$out/eval.swift"
swiftc -Onone -parse-as-library -o "$out/eval" "$out/eval.swift"
"$out/eval" "$@"
