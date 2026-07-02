import XCTest
@testable import MyWhisper

final class PartialSchedulerTests: XCTestCase {
    func testBelowMinSamplesNeverFires() {
        var scheduler = PartialScheduler()
        XCTAssertFalse(scheduler.shouldFire(now: 100.0, samplesAvailable: 15999, inFlight: false))
    }

    func testFirstEligibleCallFiresThenRespectsMinInterval() {
        var scheduler = PartialScheduler()

        // First eligible call fires.
        XCTAssertTrue(scheduler.shouldFire(now: 100.0, samplesAvailable: 16000, inFlight: false))

        // Immediate second call at the same `now` does not fire.
        XCTAssertFalse(scheduler.shouldFire(now: 100.0, samplesAvailable: 16000, inFlight: false))

        // Still within minInterval (1.0s elapsed < 1.5s) does not fire.
        XCTAssertFalse(scheduler.shouldFire(now: 101.0, samplesAvailable: 16000, inFlight: false))

        // Past minInterval (1.6s elapsed >= 1.5s) fires again.
        XCTAssertTrue(scheduler.shouldFire(now: 101.6, samplesAvailable: 16000, inFlight: false))
    }

    func testInFlightSuppressesFireAndDoesNotConsumeIt() {
        var scheduler = PartialScheduler()

        // inFlight true blocks firing even though otherwise eligible.
        XCTAssertFalse(scheduler.shouldFire(now: 100.0, samplesAvailable: 16000, inFlight: true))

        // Because the inFlight call did not record a fire, this call (still
        // the "first eligible" call) should fire immediately.
        XCTAssertTrue(scheduler.shouldFire(now: 100.0, samplesAvailable: 16000, inFlight: false))
    }

    func testResetReArmsSchedulerWithoutWaitingForMinInterval() {
        var scheduler = PartialScheduler()

        XCTAssertTrue(scheduler.shouldFire(now: 100.0, samplesAvailable: 16000, inFlight: false))
        XCTAssertFalse(scheduler.shouldFire(now: 100.2, samplesAvailable: 16000, inFlight: false))

        scheduler.reset()

        // Immediately eligible again post-reset, no need to wait minInterval.
        XCTAssertTrue(scheduler.shouldFire(now: 100.2, samplesAvailable: 16000, inFlight: false))
    }

    func testWindowedReturnsInputUnchangedWhenUnderOrAtMax() {
        let samples = [Float](repeating: 1, count: 100)
        let result = PartialScheduler.windowed(samples, maxSamples: 200)
        XCTAssertEqual(result, samples)
    }

    func testWindowedReturnsLastMaxSamplesWhenOverMax() {
        let samples = (0..<300).map { Float($0) }
        let result = PartialScheduler.windowed(samples, maxSamples: 200)
        XCTAssertEqual(result.count, 200)
        // Spot-check: first element of the window is original index 100.
        XCTAssertEqual(result.first, 100)
        XCTAssertEqual(result.last, 299)
    }
}
