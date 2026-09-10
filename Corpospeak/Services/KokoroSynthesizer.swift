import Foundation
import FluidAudio

/// Text in, audio out — the whole of what Corpospeak wants from a speech model.
///
/// Keeping this small is the point. FluidAudio is early-version and its API moves, so it is
/// imported in this file and nowhere else in the app. Swapping it for another Kokoro port, or
/// for whatever Apple eventually ships, means writing one new conformance and touching nothing
/// else. Actionable holds its diarizer behind the same kind of seam.
protocol SpeechSynthesizing: Sendable {
    /// The sample rate of everything `synthesize` returns.
    var sampleRate: Double { get }
    /// Loads the model. Throws if it can't run here.
    func load() async throws
    /// One sentence to mono samples at `sampleRate`.
    func synthesize(_ text: String) async throws -> [Float]
}

/// Kokoro 82M, running on the Neural Engine.
///
/// The model ships inside the app rather than downloading on first run. Corpospeak promises,
/// in `PRIVACY.md` and in its App Review notes, that it makes no network connections at all,
/// and that promise is worth more than the ~95MB. `ModelHub.offlineMode` enforces it: with it
/// on, any attempt to fetch a missing file throws instead of quietly reaching HuggingFace.
final class KokoroSynthesizer: SpeechSynthesizing {
    let sampleRate: Double = 24_000

    /// Kokoro's one published English voice pack for the Neural Engine build.
    static let voiceName = "af_heart"

    private let manager: KokoroAneManager

    init() throws {
        ModelHub.offlineMode = true
        try Self.stageSharedAssets()
        manager = KokoroAneManager(variant: .english, directory: try Self.bundledModels())
    }

    func load() async throws {
        try await manager.initialize()
    }

    func synthesize(_ text: String) async throws -> [Float] {
        try await manager.synthesizeDetailed(text: text).samples
    }

    // MARK: Where the model lives

    /// The models copied into the app bundle by `project.yml`.
    private static func bundledModels() throws -> URL {
        guard let url = Bundle.main.url(forResource: "KokoroModels", withExtension: nil) else {
            throw KokoroUnavailable.modelsMissingFromBundle
        }
        return url.appendingPathComponent("Models")
    }

    /// The seven-stage Kokoro chain is read straight out of the app bundle. The shared
    /// grapheme-to-phoneme assets can't be: FluidAudio pins those to its own cache directory
    /// and ignores the directory we hand it, so they are copied there once, on first launch.
    /// Without this the first thing the app tried to say would fail, offline mode having
    /// correctly refused to download them.
    private static func stageSharedAssets() throws {
        let source = try bundledModels().appendingPathComponent("kokoro")
        let destination = try TtsCacheDirectory.ensure()
            .appendingPathComponent("Models")
            .appendingPathComponent("kokoro")
        let files = FileManager.default
        guard files.fileExists(atPath: source.path) else {
            throw KokoroUnavailable.modelsMissingFromBundle
        }
        try files.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !files.fileExists(atPath: destination.path) {
            try files.copyItem(at: source, to: destination)
            return
        }
        // A partly-copied directory from an interrupted first launch would otherwise be
        // permanent, and offline mode means nothing can repair it over the network.
        for item in try files.contentsOfDirectory(atPath: source.path) {
            let target = destination.appendingPathComponent(item)
            if !files.fileExists(atPath: target.path) {
                try files.copyItem(at: source.appendingPathComponent(item), to: target)
            }
        }
    }

    // MARK: Whether it can run at all

    /// False where Kokoro can't be trusted to run, so the voice list falls back to Apple's.
    ///
    /// The 26.4 and later OS line carries an Apple bug that intermittently crashes synthesis
    /// inside libBNNS, whatever compute units the work is routed to. macOS 26.6 fixed it; on
    /// iOS the whole line is still affected. Corpospeak deploys back to 26.0, so real users sit
    /// inside that window even though this Mac and phone don't — and a voice that might take
    /// the app down mid-sentence is worse than a voice that sounds dull.
    static var isSupportedHere: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        guard version.majorVersion == 26, version.minorVersion >= 4 else { return true }
        #if os(macOS)
        return version.minorVersion > 5
        #else
        return false
        #endif
    }
}

/// Why Kokoro isn't available, when it isn't.
enum KokoroUnavailable: Error {
    case modelsMissingFromBundle
}
