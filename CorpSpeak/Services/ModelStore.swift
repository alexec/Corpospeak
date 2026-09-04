import Foundation
import Observation

/// Downloads and unpacks the voice models into Application Support, once.
///
/// Packages, both from the sherpa-onnx GitHub releases: ZipVoice (distilled, int8) for cloning
/// the user's voice, plus the Vocos vocoder it needs.
@MainActor
@Observable
final class ModelStore {
    struct Package: Identifiable {
        let id: String
        let url: URL
        /// Folder (for archives) or file (for single files) that exists once installed.
        let installedPath: String
        /// A file inside `installedPath` proving the unpack completed. Nil for single files.
        let marker: String?
    }

    enum State: Equatable {
        case checking
        case downloading(String, Double)
        case unpacking(String)
        case ready
        case failed(String)
    }

    static let zipVoice = Package(
        id: "zipvoice",
        url: URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-zipvoice-distill-int8-zh-en-emilia.tar.bz2")!,
        installedPath: "sherpa-onnx-zipvoice-distill-int8-zh-en-emilia",
        marker: "decoder.int8.onnx"
    )
    static let vocoder = Package(
        id: "vocoder",
        url: URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/vocoder-models/vocos_24khz.onnx")!,
        installedPath: "vocos_24khz.onnx",
        marker: nil
    )
    static let all = [zipVoice, vocoder]

    private(set) var state: State = .checking
    private(set) var installed: Set<String> = []

    /// Application Support/CorpSpeak
    let root: URL

    private var installTask: Task<Void, Never>?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        root = support.appendingPathComponent("CorpSpeak", isDirectory: true)
        for package in Self.all where isInstalled(package) {
            installed.insert(package.id)
        }
    }

    func location(of package: Package) -> URL {
        root.appendingPathComponent(package.installedPath)
    }

    func isInstalled(_ package: Package) -> Bool {
        let base = location(of: package)
        let proof = package.marker.map { base.appendingPathComponent($0) } ?? base
        return FileManager.default.fileExists(atPath: proof.path)
    }

    /// Installs every missing package, in order. Safe to call repeatedly. Packages become
    /// usable one at a time: watch `installed`.
    func ensureInstalled() async {
        if let installTask {
            await installTask.value
            return
        }
        let task = Task { await installAll() }
        installTask = task
        await task.value
        installTask = nil
    }

    private func installAll() async {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for package in Self.all where !isInstalled(package) {
                try await install(package)
            }
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func install(_ package: Package) async throws {
        let isArchive = package.url.lastPathComponent.hasSuffix(".tar.bz2")
        let target = isArchive ? root.appendingPathComponent(package.url.lastPathComponent) : location(of: package)
        let temporary = target.appendingPathExtension("part")

        state = .downloading(package.id, 0)
        try await Downloader.download(package.url, to: temporary) { [weak self] progress in
            Task { @MainActor in self?.state = .downloading(package.id, progress) }
        }

        if isArchive {
            state = .unpacking(package.id)
            try await Self.unpack(temporary, into: root)
            try? FileManager.default.removeItem(at: temporary)
        } else {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: temporary, to: target)
        }

        guard isInstalled(package) else { throw InstallError.incomplete(package.id) }
        installed.insert(package.id)
    }

    private static func unpack(_ archive: URL, into destination: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xjf", archive.path, "-C", destination.path]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw InstallError.unpackFailed(process.terminationStatus) }
        }.value
    }

    enum InstallError: LocalizedError {
        case incomplete(String)
        case unpackFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .incomplete(let id): "The \(id) download was incomplete."
            case .unpackFailed(let code): "Could not unpack a voice model (tar exited with \(code))."
            }
        }
    }
}

/// A URLSession download with a progress callback, wrapped for async/await.
private final class Downloader: NSObject, URLSessionDownloadDelegate {
    private let onProgress: (Double) -> Void
    private let destination: URL
    private var continuation: CheckedContinuation<Void, Error>?

    private init(destination: URL, onProgress: @escaping (Double) -> Void) {
        self.destination = destination
        self.onProgress = onProgress
    }

    static func download(_ url: URL, to destination: URL, onProgress: @escaping (Double) -> Void) async throws {
        let downloader = Downloader(destination: destination, onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: downloader, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            downloader.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            if let status = (downloadTask.response as? HTTPURLResponse)?.statusCode, status >= 400 {
                throw URLError(.badServerResponse)
            }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            continuation?.resume()
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
