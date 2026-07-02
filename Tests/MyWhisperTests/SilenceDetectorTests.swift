import XCTest
@testable import MyWhisper

final class SilenceDetectorTests: XCTestCase {
    func testSilenceOnlyNeverFires() {
        var detector = SilenceDetector()
        var fired = false
        for _ in 0..<100 {
            if detector.process(level: 0.01, frameCount: 4096) { fired = true }
        }
        XCTAssertFalse(fired)
    }

    func testSpeechThenEnoughSilenceFiresExactlyOnce() {
        var detector = SilenceDetector()
        XCTAssertFalse(detector.process(level: 0.2, frameCount: 4096)) // speech

        var fireCount = 0
        var framesAccumulated = 0
        while framesAccumulated < 40000 {
            if detector.process(level: 0.01, frameCount: 4096) { fireCount += 1 }
            framesAccumulated += 4096
        }
        XCTAssertEqual(fireCount, 1)

        // Continuing to feed silence must not fire again without reset().
        for _ in 0..<10 {
            XCTAssertFalse(detector.process(level: 0.01, frameCount: 4096))
        }
    }

    func testSpeechSilenceSpeechResetsCounter() {
        var detector = SilenceDetector()
        XCTAssertFalse(detector.process(level: 0.2, frameCount: 4096)) // speech

        // Accumulate silence, but not enough to fire.
        XCTAssertFalse(detector.process(level: 0.01, frameCount: 20000))

        // Speech again resets the silence counter.
        XCTAssertFalse(detector.process(level: 0.2, frameCount: 4096))

        // Now needs the full framesToStop of silence again — 20000 more
        // should NOT be enough since the counter was reset.
        XCTAssertFalse(detector.process(level: 0.01, frameCount: 20000))

        // But accumulating a full 32000 from here should fire.
        XCTAssertTrue(detector.process(level: 0.01, frameCount: 12000))
    }

    func testMidZoneLevelAfterSpeechResetsCounter() {
        var detector = SilenceDetector()
        XCTAssertFalse(detector.process(level: 0.2, frameCount: 4096)) // speech

        // Partial silence accumulation.
        XCTAssertFalse(detector.process(level: 0.01, frameCount: 20000))

        // Mid-zone level (between silenceThreshold and speechThreshold) resets the counter.
        XCTAssertFalse(detector.process(level: 0.08, frameCount: 4096))

        // 20000 more silence should not be enough to fire (counter was reset).
        XCTAssertFalse(detector.process(level: 0.01, frameCount: 20000))

        // The remaining frames to reach 32000 total from the reset point should fire.
        XCTAssertTrue(detector.process(level: 0.01, frameCount: 12000))
    }

    func testResetReArmsDetectorFully() {
        var detector = SilenceDetector()
        XCTAssertFalse(detector.process(level: 0.2, frameCount: 4096)) // speech
        XCTAssertTrue(detector.process(level: 0.01, frameCount: 32000)) // fires

        detector.reset()

        // Silence alone (no speech seen yet) should not fire post-reset.
        XCTAssertFalse(detector.process(level: 0.01, frameCount: 40000))

        // Speech then full silence should fire again after reset.
        XCTAssertFalse(detector.process(level: 0.2, frameCount: 4096))
        XCTAssertTrue(detector.process(level: 0.01, frameCount: 32000))
    }
}
