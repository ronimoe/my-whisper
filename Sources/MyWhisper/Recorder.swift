import AVFoundation

enum RecorderError: LocalizedError {
    case noInputDevice
    var errorDescription: String? { "No audio input device available" }
}

/// Captures microphone audio and resamples it to 16 kHz mono Float32,
/// the format whisper.cpp expects.
final class Recorder {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private var level: Float = 0
    private let lock = NSLock()
    private var hasSpeech = false
    private var silentFrames = 0
    private var autoStopFired = false
    /// Set by the caller before each recording; enables silence auto-stop.
    var autoStopEnabled = false
    var onAutoStop: (() -> Void)?

    /// Smoothed mic input level (0…1) for the menu bar level meter.
    var currentLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return level
    }
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    private(set) var isRecording = false

    func requestPermission(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    func start() throws {
        lock.lock()
        samples.removeAll()
        level = 0
        hasSpeech = false
        silentFrames = 0
        autoStopFired = false
        lock.unlock()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.noInputDevice
        }
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer: buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
        isRecording = false
        converter = nil

        lock.lock()
        defer { lock.unlock() }
        let result = samples
        samples = []
        return result
    }

    private func append(buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }
        var consumed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard conversionError == nil, output.frameLength > 0,
              let channel = output.floatChannelData else { return }
        let converted = UnsafeBufferPointer(start: channel[0], count: Int(output.frameLength))
        var sumOfSquares: Float = 0
        for value in converted { sumOfSquares += value * value }
        let rms = (sumOfSquares / Float(converted.count)).squareRoot()

        lock.lock()
        samples.append(contentsOf: converted)
        level = level * 0.5 + min(1.0, rms * 12) * 0.5
        var shouldFireAutoStop = false
        if level >= 0.12 {
            hasSpeech = true
            silentFrames = 0
        } else if hasSpeech && level < 0.06 {
            silentFrames += Int(output.frameLength)
            if silentFrames >= 32000 && !autoStopFired {
                autoStopFired = true
                shouldFireAutoStop = true
            }
        } else if hasSpeech {
            silentFrames = 0
        }
        lock.unlock()

        if shouldFireAutoStop && autoStopEnabled {
            DispatchQueue.main.async { self.onAutoStop?() }
        }
    }
}
