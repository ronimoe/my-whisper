// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MyWhisper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MyWhisper", path: "Sources/MyWhisper"),
        .testTarget(name: "MyWhisperTests", dependencies: ["MyWhisper"], path: "Tests/MyWhisperTests")
    ]
)
