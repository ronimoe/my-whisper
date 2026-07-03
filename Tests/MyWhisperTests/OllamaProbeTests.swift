import XCTest
@testable import MyWhisper

/// Deterministic, no-network tests for `Ollama.parseVersionResponse` — the pure
/// core of the identity check that stops dictated/selected text from being sent
/// to a non-Ollama listener on the AI-mode port. Network probing and socket
/// binding are intentionally NOT tested here (non-deterministic in CI).
final class OllamaProbeTests: XCTestCase {
    func testValidVersionReturnsVersionString() {
        let data = Data(#"{"version":"0.1.2"}"#.utf8)
        XCTAssertEqual(Ollama.parseVersionResponse(data), "0.1.2")
    }

    func testNonStringVersionReturnsNil() {
        let data = Data(#"{"version":123}"#.utf8)
        XCTAssertNil(Ollama.parseVersionResponse(data))
    }

    func testErrorPayloadReturnsNil() {
        let data = Data(#"{"error":"model not found"}"#.utf8)
        XCTAssertNil(Ollama.parseVersionResponse(data))
    }

    func testEmptyDataReturnsNil() {
        XCTAssertNil(Ollama.parseVersionResponse(Data()))
    }

    func testNonJSONReturnsNil() {
        let data = Data("not json".utf8)
        XCTAssertNil(Ollama.parseVersionResponse(data))
    }

    func testHTMLReturnsNil() {
        let data = Data("<!doctype html><html><body>hi</body></html>".utf8)
        XCTAssertNil(Ollama.parseVersionResponse(data))
    }

    func testEmptyObjectReturnsNil() {
        let data = Data("{}".utf8)
        XCTAssertNil(Ollama.parseVersionResponse(data))
    }

    // MARK: - parseTagsResponse

    func testTagsResponseWithTwoModelsReturnsNames() {
        let data = Data(#"{"models":[{"name":"llama3.2:latest","size":123},{"name":"bge-m3:latest","size":456}]}"#.utf8)
        XCTAssertEqual(Ollama.parseTagsResponse(data), ["llama3.2:latest", "bge-m3:latest"])
    }

    func testTagsResponseWithEmptyModelsReturnsEmptyArray() {
        let data = Data(#"{"models":[]}"#.utf8)
        XCTAssertEqual(Ollama.parseTagsResponse(data), [])
    }

    func testTagsResponseMissingModelsKeyReturnsNil() {
        let data = Data("{}".utf8)
        XCTAssertNil(Ollama.parseTagsResponse(data))
    }

    func testTagsResponseGarbageReturnsNil() {
        let data = Data("not json".utf8)
        XCTAssertNil(Ollama.parseTagsResponse(data))
    }

    func testTagsResponseHTMLReturnsNil() {
        let data = Data("<!doctype html><html><body>hi</body></html>".utf8)
        XCTAssertNil(Ollama.parseTagsResponse(data))
    }

    // MARK: - parsePullProgressLine

    func testPullProgressStatusOnlyLine() {
        let line = Data(#"{"status":"pulling manifest"}"#.utf8)
        let result = Ollama.parsePullProgressLine(line)
        XCTAssertEqual(result?.status, "pulling manifest")
        XCTAssertNil(result?.completed)
        XCTAssertNil(result?.total)
    }

    func testPullProgressStatusWithCompletedAndTotal() {
        let line = Data(#"{"status":"pulling abc123","completed":123,"total":456}"#.utf8)
        let result = Ollama.parsePullProgressLine(line)
        XCTAssertEqual(result?.status, "pulling abc123")
        XCTAssertEqual(result?.completed, 123)
        XCTAssertEqual(result?.total, 456)
    }

    func testPullProgressSuccessLine() {
        let line = Data(#"{"status":"success"}"#.utf8)
        let result = Ollama.parsePullProgressLine(line)
        XCTAssertEqual(result?.status, "success")
        XCTAssertNil(result?.completed)
        XCTAssertNil(result?.total)
    }

    func testPullProgressErrorLineReturnsErrorPrefixedStatus() {
        let line = Data(#"{"error":"file not found"}"#.utf8)
        let result = Ollama.parsePullProgressLine(line)
        XCTAssertEqual(result?.status, "error: file not found")
        XCTAssertNil(result?.completed)
        XCTAssertNil(result?.total)
    }

    func testPullProgressGarbageLineReturnsNil() {
        let line = Data("not json".utf8)
        XCTAssertNil(Ollama.parsePullProgressLine(line))
    }
}
