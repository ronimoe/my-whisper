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

    // MARK: - validateSize

    func testMatchingSizesAreOK() {
        XCTAssertNil(ModelDownloader.validateSize(actual: 5_000_000, expected: 5_000_000))
    }

    func testExpectedNilAndActualAtLeast1MBIsOK() {
        XCTAssertNil(ModelDownloader.validateSize(actual: 1_048_576, expected: nil))
        XCTAssertNil(ModelDownloader.validateSize(actual: 5_000_000, expected: nil))
    }

    func testMismatchReturnsMessage() {
        let message = ModelDownloader.validateSize(actual: 4_999_999, expected: 5_000_000)
        XCTAssertNotNil(message)
    }

    func testUnder1MBReturnsMessageEvenWhenExpectedMatches() {
        let tiny: Int64 = 500_000
        let message = ModelDownloader.validateSize(actual: tiny, expected: tiny)
        XCTAssertNotNil(message)
    }

    func testUnder1MBWithNilExpectedReturnsMessage() {
        let message = ModelDownloader.validateSize(actual: 999_999, expected: nil)
        XCTAssertNotNil(message)
    }

    func testExactly1MBWithNilExpectedIsOK() {
        XCTAssertNil(ModelDownloader.validateSize(actual: 1_048_576, expected: nil))
    }

    func testExpectedZeroOrLessIsTreatedLikeUnknownExpected() {
        // expected <= 0 means "no usable Content-Length" — only the 1MB floor applies.
        XCTAssertNil(ModelDownloader.validateSize(actual: 5_000_000, expected: 0))
        XCTAssertNotNil(ModelDownloader.validateSize(actual: 500_000, expected: 0))
    }
}
