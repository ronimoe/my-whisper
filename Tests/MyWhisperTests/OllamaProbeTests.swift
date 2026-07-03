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
}
