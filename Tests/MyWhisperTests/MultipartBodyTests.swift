import XCTest
@testable import MyWhisper

final class MultipartBodyTests: XCTestCase {
    private let wavData = Data([0x52, 0x49, 0x46, 0x46, 0x00, 0x01, 0x02, 0x03])

    func testContainsLanguageFieldWithValue() {
        let body = WhisperServerManager.multipartBody(
            boundary: "TESTBOUNDARY", wavData: wavData, language: "id")
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("name=\"language\""))
        XCTAssertTrue(text.contains("\r\n\r\nid\r\n"))
    }

    func testTranslateFieldPresentOnlyWhenTrue() {
        let withTranslate = WhisperServerManager.multipartBody(
            boundary: "B", wavData: wavData, language: "en", translate: true)
        XCTAssertTrue(String(decoding: withTranslate, as: UTF8.self).contains("name=\"translate\""))

        let withoutTranslate = WhisperServerManager.multipartBody(
            boundary: "B", wavData: wavData, language: "en", translate: false)
        XCTAssertFalse(String(decoding: withoutTranslate, as: UTF8.self).contains("name=\"translate\""))
    }

    func testPromptFieldPresentOnlyWhenNonNilAndNonEmpty() {
        let withPrompt = WhisperServerManager.multipartBody(
            boundary: "B", wavData: wavData, language: "en", prompt: "hello world")
        XCTAssertTrue(String(decoding: withPrompt, as: UTF8.self).contains("name=\"prompt\""))

        let nilPrompt = WhisperServerManager.multipartBody(
            boundary: "B", wavData: wavData, language: "en", prompt: nil)
        XCTAssertFalse(String(decoding: nilPrompt, as: UTF8.self).contains("name=\"prompt\""))

        let emptyPrompt = WhisperServerManager.multipartBody(
            boundary: "B", wavData: wavData, language: "en", prompt: "")
        XCTAssertFalse(String(decoding: emptyPrompt, as: UTF8.self).contains("name=\"prompt\""))
    }

    func testBodyEndsWithClosingBoundary() {
        let boundary = "mywhisper-XYZ"
        let body = WhisperServerManager.multipartBody(
            boundary: boundary, wavData: wavData, language: "en")
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.hasSuffix("--\(boundary)--\r\n"))
    }

    func testWavBytesContainedInBody() {
        let body = WhisperServerManager.multipartBody(
            boundary: "B", wavData: wavData, language: "en")
        XCTAssertNotNil(body.range(of: wavData))
    }
}
