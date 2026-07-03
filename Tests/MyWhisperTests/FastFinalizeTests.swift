import XCTest
@testable import MyWhisper

/// Unit tests for the pure fast-finalize decision logic: whether a live
/// preview's raw transcript can be reused as the final transcript instead of
/// re-transcribing the full recording.
final class FastFinalizeTests: XCTestCase {
    // MARK: - tailRMS

    func testTailRMSOfKnownVectorIsConstantAmplitude() {
        let samples = [Float](repeating: 0.1, count: 4000)
        XCTAssertEqual(FastFinalize.tailRMS(samples, from: 0), 0.1, accuracy: 0.0001)
    }

    func testTailRMSFromIndexBeyondCountIsZero() {
        let samples = [Float](repeating: 0.1, count: 100)
        XCTAssertEqual(FastFinalize.tailRMS(samples, from: 100), 0)
        XCTAssertEqual(FastFinalize.tailRMS(samples, from: 500), 0)
    }

    func testTailRMSOfEmptyArrayIsZero() {
        XCTAssertEqual(FastFinalize.tailRMS([], from: 0), 0)
    }

    func testTailRMSOfNegativeIndexTreatsRangeAsInvalid() {
        let samples = [Float](repeating: 0.1, count: 100)
        XCTAssertEqual(FastFinalize.tailRMS(samples, from: -1), 0)
    }

    func testTailRMSFromPartialIndexOnlyMeasuresSuffix() {
        // First half silent, second half loud — measuring from the midpoint
        // must reflect only the loud half.
        var samples = [Float](repeating: 0.0, count: 100)
        samples.append(contentsOf: [Float](repeating: 0.2, count: 100))
        XCTAssertEqual(FastFinalize.tailRMS(samples, from: 100), 0.2, accuracy: 0.0001)
    }

    // MARK: - shouldReuse

    func testNilPartialIsFalse() {
        XCTAssertFalse(FastFinalize.shouldReuse(partial: nil, totalSamples: 16000, tailRMS: 0,
                                                expectedLanguage: "en", expectedTranslate: false))
    }

    func testEmptyRawTextIsFalse() {
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "", language: "en", translate: false)
        XCTAssertFalse(FastFinalize.shouldReuse(partial: partial, totalSamples: 16000, tailRMS: 0,
                                                expectedLanguage: "en", expectedTranslate: false))
    }

    func testTailExactlyMaxTailSamplesAndSilentIsTrue() {
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "hello world",
                                           language: "en", translate: false)
        let total = 16000 + FastFinalize.maxTailSamples
        XCTAssertTrue(FastFinalize.shouldReuse(partial: partial, totalSamples: total,
                                               tailRMS: FastFinalize.silentTailRMS - 0.001,
                                               expectedLanguage: "en", expectedTranslate: false))
    }

    func testTailOneSampleOverMaxIsFalse() {
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "hello world",
                                           language: "en", translate: false)
        let total = 16000 + FastFinalize.maxTailSamples + 1
        XCTAssertFalse(FastFinalize.shouldReuse(partial: partial, totalSamples: total, tailRMS: 0,
                                                expectedLanguage: "en", expectedTranslate: false))
    }

    func testLoudTailIsFalse() {
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "hello world",
                                           language: "en", translate: false)
        let total = 16000 + 1000
        XCTAssertFalse(FastFinalize.shouldReuse(partial: partial, totalSamples: total,
                                                tailRMS: FastFinalize.silentTailRMS + 0.001,
                                                expectedLanguage: "en", expectedTranslate: false))
    }

    /// Buffer shrunk below the partial's snapshot count (shouldn't normally
    /// happen, but must be handled safely rather than trapping/underflowing).
    func testTotalSamplesLessThanPartialSampleCountIsFalse() {
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "hello world",
                                           language: "en", translate: false)
        XCTAssertFalse(FastFinalize.shouldReuse(partial: partial, totalSamples: 8000, tailRMS: 0,
                                                expectedLanguage: "en", expectedTranslate: false))
    }

    func testTailRMSAtThresholdIsFalse() {
        // tailRMS must be STRICTLY less than silentTailRMS.
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "hello world",
                                           language: "en", translate: false)
        XCTAssertFalse(FastFinalize.shouldReuse(partial: partial, totalSamples: 16000,
                                                tailRMS: FastFinalize.silentTailRMS,
                                                expectedLanguage: "en", expectedTranslate: false))
    }

    func testTotalSamplesEqualToPartialSampleCountWithSilentTailIsTrue() {
        // Zero-length tail: no extra audio at all since the snapshot.
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "hello world",
                                           language: "en", translate: false)
        XCTAssertTrue(FastFinalize.shouldReuse(partial: partial, totalSamples: 16000, tailRMS: 0,
                                               expectedLanguage: "en", expectedTranslate: false))
    }

    // MARK: - language/translate guard (Fix 1)

    func testLanguageMismatchIsFalse() {
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "hello world",
                                           language: "en", translate: false)
        XCTAssertFalse(FastFinalize.shouldReuse(partial: partial, totalSamples: 16000, tailRMS: 0,
                                                expectedLanguage: "id", expectedTranslate: false))
    }

    func testTranslateMismatchIsFalse() {
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "hello world",
                                           language: "en", translate: false)
        XCTAssertFalse(FastFinalize.shouldReuse(partial: partial, totalSamples: 16000, tailRMS: 0,
                                                expectedLanguage: "en", expectedTranslate: true))
    }

    func testLanguageAndTranslateBothMatchingWithSilentShortTailIsTrue() {
        let partial = FastFinalize.Partial(sampleCount: 16000, rawText: "hello world",
                                           language: "id", translate: true)
        let total = 16000 + 1000
        XCTAssertTrue(FastFinalize.shouldReuse(partial: partial, totalSamples: total,
                                               tailRMS: FastFinalize.silentTailRMS - 0.001,
                                               expectedLanguage: "id", expectedTranslate: true))
    }
}
