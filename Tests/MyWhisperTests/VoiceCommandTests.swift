import XCTest
@testable import MyWhisper

final class VoiceCommandTests: XCTestCase {
    // MARK: - Each phrase maps to its command

    func testScratchThatMatchesUndo() {
        XCTAssertEqual(VoiceCommands.match("scratch that"), .undoLastDictation)
    }

    func testUndoThatMatchesUndo() {
        XCTAssertEqual(VoiceCommands.match("undo that"), .undoLastDictation)
    }

    func testBatalkanMatchesUndo() {
        XCTAssertEqual(VoiceCommands.match("batalkan"), .undoLastDictation)
    }

    func testBatalkanItuMatchesUndo() {
        XCTAssertEqual(VoiceCommands.match("batalkan itu"), .undoLastDictation)
    }

    func testNewLineMatchesNewLine() {
        XCTAssertEqual(VoiceCommands.match("new line"), .newLine)
    }

    func testBarisBaruMatchesNewLine() {
        XCTAssertEqual(VoiceCommands.match("baris baru"), .newLine)
    }

    func testNewParagraphMatchesNewParagraph() {
        XCTAssertEqual(VoiceCommands.match("new paragraph"), .newParagraph)
    }

    func testParagrafBaruMatchesNewParagraph() {
        XCTAssertEqual(VoiceCommands.match("paragraf baru"), .newParagraph)
    }

    // MARK: - Case-insensitive

    func testCaseInsensitiveScratchThat() {
        XCTAssertEqual(VoiceCommands.match("Scratch That"), .undoLastDictation)
    }

    // MARK: - Trailing punctuation stripped

    func testTrailingPeriodStripped() {
        XCTAssertEqual(VoiceCommands.match("scratch that."), .undoLastDictation)
    }

    func testTrailingExclamationStripped() {
        XCTAssertEqual(VoiceCommands.match("New line!"), .newLine)
    }

    func testTrailingEllipsisStripped() {
        XCTAssertEqual(VoiceCommands.match("batalkan..."), .undoLastDictation)
    }

    // MARK: - Leading/trailing whitespace tolerated

    func testLeadingTrailingWhitespaceTolerated() {
        XCTAssertEqual(VoiceCommands.match("   scratch that   "), .undoLastDictation)
    }

    // MARK: - Non-commands return nil

    func testInlineExtraWordsDoNotMatch() {
        XCTAssertNil(VoiceCommands.match("scratch that please"))
    }

    func testUnrelatedSentenceContainingNewLineDoesNotMatch() {
        XCTAssertNil(VoiceCommands.match("this is a new line of thinking"))
    }

    func testEmptyStringDoesNotMatch() {
        XCTAssertNil(VoiceCommands.match(""))
    }

    func testUndoAloneDoesNotMatch() {
        XCTAssertNil(VoiceCommands.match("undo"))
    }

    // MARK: - Inline usage does NOT match

    func testLeadingExtraWordsDoNotMatch() {
        XCTAssertNil(VoiceCommands.match("please undo that"))
    }
}
