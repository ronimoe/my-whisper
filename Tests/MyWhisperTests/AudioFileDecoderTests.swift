import XCTest
import AVFoundation
@testable import MyWhisper

final class AudioFileDecoderTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioFileDecoderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    // MARK: - Helpers

    /// Generates `seconds` of a 440 Hz sine wave at `sampleRate`.
    private func sineSamples(seconds: Double, sampleRate: Double, frequency: Double = 440) -> [Float] {
        let count = Int(seconds * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            samples[i] = Float(sin(2.0 * Double.pi * frequency * t)) * 0.8
        }
        return samples
    }

    private func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }

    // MARK: - Tests

    func testRoundTripWavAt16kHz() throws {
        let samples = sineSamples(seconds: 2.0, sampleRate: 16000)
        let wav = WavWriter.data(fromSamples: samples, sampleRate: 16000)
        let url = tempDir.appendingPathComponent("sine16k.wav")
        try wav.write(to: url)

        let decoded = try AudioFileDecoder.samples(fromFileAt: url)

        let expectedCount = 32000
        let tolerance = Int(Double(expectedCount) * 0.01)
        XCTAssertEqual(decoded.count, expectedCount, accuracy: tolerance,
                       "decoded sample count should be within ±1% of \(expectedCount)")

        let sourceRMS = rms(samples)
        let decodedRMS = rms(decoded)
        XCTAssertEqual(decodedRMS, sourceRMS, accuracy: sourceRMS * 0.1,
                       "decoded RMS should be within 10% of source RMS")
    }

    func testResamplesFrom44100Hz() throws {
        let samples = sineSamples(seconds: 2.0, sampleRate: 44100)
        let wav = WavWriter.data(fromSamples: samples, sampleRate: 44100)
        let url = tempDir.appendingPathComponent("sine44k.wav")
        try wav.write(to: url)

        let decoded = try AudioFileDecoder.samples(fromFileAt: url)

        let expectedCount = 32000
        let tolerance = Int(Double(expectedCount) * 0.02)
        XCTAssertEqual(decoded.count, expectedCount, accuracy: tolerance,
                       "decoded sample count should be within ±2% of \(expectedCount)")

        let sourceRMS = rms(samples)
        let decodedRMS = rms(decoded)
        XCTAssertEqual(decodedRMS, sourceRMS, accuracy: sourceRMS * 0.15,
                       "decoded RMS should be within 15% of source RMS")
    }

    func testDecodesLossyM4A() throws {
        let sampleRate = 44100.0
        let samples = sineSamples(seconds: 2.0, sampleRate: sampleRate)
        let url = tempDir.appendingPathComponent("sine.m4a")

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                   channels: 1, interleaved: false)!
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000,
        ]
        // Scope the writer so it deallocates (closing the underlying
        // ExtAudioFile) before AudioFileDecoder opens the same path for
        // reading — under the xctest host, reading back while the AAC
        // writer handle is still alive fails with
        // ExtAudioFileOpenURL error 1685348671, even though the bytes are
        // already flushed to disk.
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings,
                                       commonFormat: .pcmFormatFloat32, interleaved: false)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
            buffer.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { src in
                buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
            }
            try file.write(from: buffer)
        }

        let decoded = try AudioFileDecoder.samples(fromFileAt: url)

        XCTAssertFalse(decoded.isEmpty, "decoded AAC audio should not be empty")
        XCTAssertGreaterThan(rms(decoded), 0, "decoded AAC audio should have non-zero RMS")

        let expectedCount = 32000
        let tolerance = Int(Double(expectedCount) * 0.05)
        XCTAssertEqual(decoded.count, expectedCount, accuracy: tolerance,
                       "decoded duration should be within 5% of source (AAC padding tolerance)")
    }

    func testThrowsOnGarbageFile() throws {
        var bytes = [UInt8](repeating: 0, count: 4096)
        var generator = SystemRandomNumberGenerator()
        for i in 0..<bytes.count { bytes[i] = UInt8.random(in: 0...255, using: &generator) }
        // .wav (not .mp3): MP3 has no strong container magic bytes, so
        // AVAudioFile's MP3 frame-sync scan intermittently finds a
        // plausible-looking sync pattern by chance in 4 KB of random noise
        // and "successfully" decodes a garbled fragment — verified flaky
        // (opens ~30-50% of the time) across 200 random seeds. .wav requires
        // a well-formed "RIFF"/"WAVE" header, so garbage bytes reliably fail
        // to open (0/200 in the same trial).
        let url = tempDir.appendingPathComponent("garbage.wav")
        try Data(bytes).write(to: url)

        XCTAssertThrowsError(try AudioFileDecoder.samples(fromFileAt: url))
    }
}
