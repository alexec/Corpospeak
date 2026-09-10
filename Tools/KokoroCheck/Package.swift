// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KokoroCheck",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.6")
    ],
    targets: [
        .executableTarget(name: "KokoroCheck", dependencies: ["FluidAudio"])
    ]
)
