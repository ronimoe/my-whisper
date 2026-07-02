import XCTest
@testable import MyWhisper

final class PostprocessTests: XCTestCase {
    func testMidWordJoinAcrossNewline() {
        XCTAssertEqual(Postprocess.clean("berj\nalan"), "berjalan")
    }

    func testNewlineDeletedSegmentLeadingSpaceKeptThenCollapsed() {
        XCTAssertEqual(Postprocess.clean("app\n that works"), "app that works")
    }

    func testMultipleSpacesCollapseToOne() {
        XCTAssertEqual(Postprocess.clean("hello   world"), "hello world")
    }

    func testLeadingAndTrailingWhitespaceTrimmed() {
        XCTAssertEqual(Postprocess.clean("   hello world   "), "hello world")
    }

    func testBlankAudioAnnotationRemoved() {
        XCTAssertEqual(Postprocess.clean("[BLANK_AUDIO]"), "")
    }

    func testMusicAnnotationRemoved() {
        XCTAssertEqual(Postprocess.clean("(music)"), "")
    }

    func testPlainSentencePassesThroughUnchanged() {
        XCTAssertEqual(Postprocess.clean("This is a plain sentence."), "This is a plain sentence.")
    }

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual(Postprocess.clean(""), "")
    }
}
