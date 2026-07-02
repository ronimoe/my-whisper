import Foundation

/// Silence-based auto-stop state machine, extracted from `Recorder.append(buffer:)`.
/// Tracks whether speech has been seen and how many silent frames have
/// accumulated since, firing auto-stop exactly once per armed cycle.
struct SilenceDetector {
    var speechThreshold: Float = 0.12
    var silenceThreshold: Float = 0.06
    var framesToStop: Int = 32000

    private var hasSpeech = false
    private var silentFrames = 0
    private var autoStopFired = false

    /// Feeds one buffer's smoothed level and frame count into the state
    /// machine. Returns true exactly once when auto-stop should fire.
    mutating func process(level: Float, frameCount: Int) -> Bool {
        var shouldFireAutoStop = false
        if level >= speechThreshold {
            hasSpeech = true
            silentFrames = 0
        } else if hasSpeech && level < silenceThreshold {
            silentFrames += frameCount
            if silentFrames >= framesToStop && !autoStopFired {
                autoStopFired = true
                shouldFireAutoStop = true
            }
        } else if hasSpeech {
            silentFrames = 0
        }
        return shouldFireAutoStop
    }

    mutating func reset() {
        hasSpeech = false
        silentFrames = 0
        autoStopFired = false
    }
}
