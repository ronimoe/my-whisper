// swift-tools-version:5.9
import PackageDescription

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
            // whisper.pc only exposes the whisper Cellar lib dir, but libwhisper
            // depends on libggml/libggml-base, which Homebrew symlinks into
            // /opt/homebrew/lib. Add that search path and link them explicitly.
            linkerSettings: [
                .unsafeFlags(["-L/opt/homebrew/lib"]),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
            ]
        ),
        .testTarget(name: "MyWhisperTests", dependencies: ["MyWhisper"], path: "Tests/MyWhisperTests")
    ]
)
