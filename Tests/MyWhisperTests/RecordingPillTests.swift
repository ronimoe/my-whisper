import XCTest
@testable import MyWhisper

final class RecordingPillTests: XCTestCase {
    func testFormatElapsedZeroSeconds() {
        XCTAssertEqual(RecordingPill.formatElapsed(0), "0:00")
    }

    func testFormatElapsedSevenSeconds() {
        XCTAssertEqual(RecordingPill.formatElapsed(7), "0:07")
    }

    func testFormatElapsedOneMinuteTwentyThreeSeconds() {
        XCTAssertEqual(RecordingPill.formatElapsed(83), "1:23")
    }

    func testFormatElapsedTwelveMinutesFiveSeconds() {
        XCTAssertEqual(RecordingPill.formatElapsed(725), "12:05")
    }
}
