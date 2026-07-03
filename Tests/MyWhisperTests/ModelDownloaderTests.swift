import XCTest
@testable import MyWhisper

/// Deterministic, no-network tests for ModelDownloader's pure helpers.
final class ModelDownloaderTests: XCTestCase {
    func testModelURLForLargeV3Turbo() {
        let url = ModelDownloader.modelURL(for: "large-v3-turbo")
        XCTAssertEqual(
            url.absoluteString,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")
    }

    func testModelURLForBase() {
        let url = ModelDownloader.modelURL(for: "base")
        XCTAssertEqual(
            url.absoluteString,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")
    }

    func testDestinationIsInsideModelsDirAndNamedCorrectly() {
        let destination = ModelDownloader.destination(for: "large-v3-turbo")
        XCTAssertEqual(destination.deletingLastPathComponent().standardizedFileURL,
                       Settings.modelsDir.standardizedFileURL)
        XCTAssertEqual(destination.lastPathComponent, "ggml-large-v3-turbo.bin")
    }

    func testDestinationForBase() {
        let destination = ModelDownloader.destination(for: "base")
        XCTAssertEqual(destination.deletingLastPathComponent().standardizedFileURL,
                       Settings.modelsDir.standardizedFileURL)
        XCTAssertEqual(destination.lastPathComponent, "ggml-base.bin")
    }

    func testIsDownloadingDefaultsFalse() {
        // A fresh singleton (no download ever started in this process) must
        // report not-downloading.
        XCTAssertFalse(ModelDownloader.shared.isDownloading)
    }
}
