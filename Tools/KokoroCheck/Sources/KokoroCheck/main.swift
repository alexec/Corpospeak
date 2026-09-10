import Foundation
import FluidAudio

/// stdout is block-buffered when it isn't a terminal, which hides progress until the process
/// exits. Everything here goes to stderr, which isn't.
func say(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}

// Proves the bundled-models path works with the network switched off, and reports how fast
// synthesis is relative to the audio it produces. Run from the repo root:
//     swift run --package-path Tools/KokoroCheck KokoroCheck
// It reads the same files the app bundles (Corpospeak/KokoroModels), staged into the cache
// directory FluidAudio's shared G2P assets are pinned to.

let sentences = [
    "Let's circle back on that and socialise it with the wider group.",
    "We need to double-click on the synergies before we boil the ocean.",
    "I'll take that offline and come back with a strawman.",
]

// No network, at all. Any attempt to download now throws instead of silently succeeding.
ModelHub.offlineMode = true

let manager = KokoroAneManager(variant: .english)
let loadStart = Date()
try await manager.initialize()
say(String(format: "load: %.2fs (offline)", Date().timeIntervalSince(loadStart)))

// First synthesis pays for Neural Engine warm-up, so it is run and thrown away. What we want
// is the steady-state cost of the next sentence while the app is already talking.
let warmStart = Date()
_ = try await manager.synthesizeDetailed(text: "Warming up.")
say(String(format: "warm-up: %.2fs (discarded)", Date().timeIntervalSince(warmStart)))

var totalAudio = 0.0
var totalWall = 0.0
for (i, sentence) in sentences.enumerated() {
    let start = Date()
    let result = try await manager.synthesizeDetailed(text: sentence)
    let wall = Date().timeIntervalSince(start)
    let seconds = Double(result.samples.count) / Double(result.sampleRate)
    totalAudio += seconds
    totalWall += wall
    say(String(format: "  [%d] %5.2fs audio in %5.2fs  RTF %.3f  (%dx faster than real time)",
                 i + 1, seconds, wall, wall / seconds, Int((seconds / wall).rounded())))
}
say(String(format: "overall RTF %.3f — %.1fx faster than real time",
             totalWall / totalAudio, totalAudio / totalWall))

let wav = try await manager.synthesize(text: sentences[0])
let out = URL(fileURLWithPath: "/tmp/kokoro-sample.wav")
try wav.write(to: out)
say("wrote \(out.path) (\(wav.count / 1024) KB)")
