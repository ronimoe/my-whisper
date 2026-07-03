import Foundation

/// Pure decision logic for "fast finalize": when the user stops dictating
/// shortly after the last live-preview partial, and the audio recorded since
/// that partial is short and silent, the partial's raw transcript already
/// covers everything worth transcribing. Reusing it skips the full
/// re-transcription and its ~1 s wait, making paste instant. When the tail is
/// long or contains speech, the caller must fall back to the normal full
/// transcription — this never splices partial and tail text together.
enum FastFinalize {
    /// The last completed live-preview partial: the sample count of the
    /// recording at the moment the partial was requested, its raw
    /// (pre-Postprocess/lexicon) transcript, and the language/translate it was
    /// ACTUALLY transcribed under. The latter two guard against per-app
    /// profiles changing the effective language/translate between the
    /// preview tick and finishDictation — reusing a partial transcribed under
    /// the wrong language/translate would silently paste the wrong text.
    struct Partial {
        let sampleCount: Int
        let rawText: String
        let language: String
        let translate: Bool
    }

    /// Max samples of audio allowed after the partial's snapshot (0.75 s @16 kHz).
    static let maxTailSamples = 12_000

    /// RMS threshold for "the tail is silence" — matches SilenceDetector's
    /// silence level (level < 0.06 where level = min(1, rms*12) → rms < 0.005).
    static let silentTailRMS: Float = 0.005

    /// Root-mean-square of `samples[index...]`. Returns 0 when `index` is out
    /// of bounds (negative, or >= count) or the resulting range is empty.
    static func tailRMS(_ samples: [Float], from index: Int) -> Float {
        guard index >= 0, index < samples.count else { return 0 }
        var sumOfSquares: Float = 0
        var count = 0
        for value in samples[index...] {
            sumOfSquares += value * value
            count += 1
        }
        guard count > 0 else { return 0 }
        return (sumOfSquares / Float(count)).squareRoot()
    }

    /// True iff reusing `partial.rawText` as the final transcript is safe:
    /// a partial exists with non-empty text, the recording hasn't shrunk
    /// below the partial's snapshot, the audio recorded since then is within
    /// `maxTailSamples`, that tail is silent, AND the partial was transcribed
    /// under the same language/translate the final result is expected to use
    /// (belt-and-braces guard against per-app profiles changing the effective
    /// language/translate between the preview tick and finishDictation).
    static func shouldReuse(partial: Partial?, totalSamples: Int, tailRMS: Float,
                            expectedLanguage: String, expectedTranslate: Bool) -> Bool {
        guard let partial, !partial.rawText.isEmpty, totalSamples >= partial.sampleCount else {
            return false
        }
        guard partial.language == expectedLanguage, partial.translate == expectedTranslate else {
            return false
        }
        let tailSamples = totalSamples - partial.sampleCount
        guard tailSamples <= maxTailSamples else { return false }
        return tailRMS < silentTailRMS
    }
}
