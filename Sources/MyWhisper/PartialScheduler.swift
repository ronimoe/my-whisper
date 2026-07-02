import Foundation

/// Decides when to fire a live-transcription preview while recording is in
/// progress: not before `minSamples` of audio exist, not while a preview
/// request is already in flight, and not more often than `minInterval`.
struct PartialScheduler {
    var minInterval: TimeInterval = 1.5
    var minSamples: Int = 16000            // 1 s of speech before first preview

    private var lastFire: TimeInterval?

    /// Returns true only when a preview should be requested right now. When
    /// it returns true, `now` is recorded as the last fire time.
    mutating func shouldFire(now: TimeInterval, samplesAvailable: Int, inFlight: Bool) -> Bool {
        guard !inFlight, samplesAvailable >= minSamples else { return false }
        if let lastFire, now - lastFire < minInterval { return false }
        lastFire = now
        return true
    }

    /// Clears fire history so the next eligible call fires immediately.
    mutating func reset() {
        lastFire = nil
    }

    /// Returns `samples` unchanged when within `maxSamples`, otherwise the
    /// last `maxSamples` elements.
    static func windowed(_ samples: [Float], maxSamples: Int) -> [Float] {
        guard samples.count > maxSamples else { return samples }
        return Array(samples.suffix(maxSamples))
    }
}
