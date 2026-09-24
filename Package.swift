// swift-tools-version:5.9
import Foundation
import PackageDescription

// Homebrew's prefix: /opt/homebrew on Apple Silicon. Override with
// HOMEBREW_PREFIX (Homebrew's own shellenv exports it) for other installs.
let brewPrefix = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"] ?? "/opt/homebrew"

// whisper.pc only exposes the whisper Cellar include dir, but whisper.h
// includes ggml.h from the ggml formula, which Homebrew symlinks into
// $HOMEBREW_PREFIX/include. Every target that imports CWhisper needs it.
let brewIncludeFlags: [SwiftSetting] = [.unsafeFlags(["-Xcc", "-I\(brewPrefix)/include"])]

let package = Package(
    name: "MyWhisper",
    platforms: [.macOS(.v13)],
    targets: [
        .systemLibrary(name: "CWhisper", path: "Sources/CWhisper", pkgConfig: "whisper",
                       providers: [.brew(["whisper-cpp"])]),
        .executableTarget(
            name: "MyWhisper",
            dependencies: ["CWhisper"],
            path: "Sources/MyWhisper",
            swiftSettings: brewIncludeFlags,
            // Likewise libwhisper depends on libggml/libggml-base, which
            // Homebrew symlinks into $HOMEBREW_PREFIX/lib. Add that search
            // path and link them explicitly.
            linkerSettings: [
                .unsafeFlags(["-L\(brewPrefix)/lib"]),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
            ]
        ),
        .testTarget(name: "MyWhisperTests", dependencies: ["MyWhisper"], path: "Tests/MyWhisperTests",
                    swiftSettings: brewIncludeFlags)
    ]
)
