import XCTest
@testable import MyWhisper

final class WavReaderTests: XCTestCase {
    func testRoundTripPreservesSamplesWithinQuantizationError() throws {
        let originals: [Float] = [-1.0, -0.5, 0.0, 0.25, 0.5, 1.0, 2.0, -2.0]
        let wav = WavWriter.data(fromSamples: originals)
        let decoded = try WavReader.samples(fromWavData: wav)

        XCTAssertEqual(decoded.count, originals.count)
        for (original, roundTripped) in zip(originals, decoded) {
            // WavWriter clamps to [-1, 1] before quantizing to Int16; the
            // 32767-vs-32768 scale asymmetry keeps each value within one LSB.
            let clamped = max(-1.0, min(1.0, original))
            XCTAssertEqual(roundTripped, clamped, accuracy: 1.0 / 32768.0)
        }
    }

    func testDecodesFixedKeyValues() throws {
        let wav = WavWriter.data(fromSamples: [-1.0, 0.0, 0.5, 1.0])
        let decoded = try WavReader.samples(fromWavData: wav)
        XCTAssertEqual(decoded[1], 0.0, accuracy: 1.0 / 32768.0)
        XCTAssertEqual(decoded[2], 0.5, accuracy: 1.0 / 32768.0)
        XCTAssertEqual(decoded[3], 1.0, accuracy: 1.0 / 32768.0)
    }

    func testWalksChunksWhenDataDoesNotStartAtOffset44() throws {
        // Insert a junk "FLLR" padding chunk between "fmt " and "data",
        // mirroring the recorder's real WAV files.
        let wav = WavWriter.data(fromSamples: [0.25, -0.25, 0.5])
        var padded = wav.subdata(in: 0..<36)          // RIFF + WAVE + fmt chunk
        let filler: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD]
        padded.append(contentsOf: Array("FLLR".utf8))
        padded.append(contentsOf: [UInt8(filler.count), 0, 0, 0]) // little-endian size
        padded.append(contentsOf: filler)
        padded.append(wav.subdata(in: 36..<wav.count)) // original data chunk
        // Fix RIFF size field.
        let riffSize = UInt32(padded.count - 8)
        padded.replaceSubrange(4..<8, with: [
            UInt8(riffSize & 0xFF), UInt8((riffSize >> 8) & 0xFF),
            UInt8((riffSize >> 16) & 0xFF), UInt8((riffSize >> 24) & 0xFF)
        ])

        let decoded = try WavReader.samples(fromWavData: padded)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0], 0.25, accuracy: 1.0 / 32768.0)
        XCTAssertEqual(decoded[1], -0.25, accuracy: 1.0 / 32768.0)
        XCTAssertEqual(decoded[2], 0.5, accuracy: 1.0 / 32768.0)
    }

    func testRejectsWrongSampleRate() {
        let wav = handBuiltHeader(sampleRate: 8000, channels: 1, bitsPerSample: 16, format: 1)
        XCTAssertThrowsError(try WavReader.samples(fromWavData: wav))
    }

    func testRejectsStereo() {
        let wav = handBuiltHeader(sampleRate: 16000, channels: 2, bitsPerSample: 16, format: 1)
        XCTAssertThrowsError(try WavReader.samples(fromWavData: wav))
    }

    func testRejectsNon16Bit() {
        let wav = handBuiltHeader(sampleRate: 16000, channels: 1, bitsPerSample: 8, format: 1)
        XCTAssertThrowsError(try WavReader.samples(fromWavData: wav))
    }

    func testRejectsNonPCM() {
        let wav = handBuiltHeader(sampleRate: 16000, channels: 1, bitsPerSample: 16, format: 3)
        XCTAssertThrowsError(try WavReader.samples(fromWavData: wav))
    }

    func testRejectsGarbageData() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        XCTAssertThrowsError(try WavReader.samples(fromWavData: garbage))
    }

    func testRejectsEmptyData() {
        XCTAssertThrowsError(try WavReader.samples(fromWavData: Data()))
    }

    // MARK: - Helpers

    /// Builds a minimal but structurally valid WAV header with a small data
    /// chunk, letting each format field be overridden to exercise rejection.
    private func handBuiltHeader(sampleRate: UInt32, channels: UInt16,
                                 bitsPerSample: UInt16, format: UInt16) -> Data {
        let pcm = Data([0x00, 0x00, 0x00, 0x00])
        var wav = Data()
        func appendLE<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { wav.append(contentsOf: $0) }
        }
        let blockAlign = channels * bitsPerSample / 8
        let byteRate = sampleRate * UInt32(blockAlign)
        wav.append(contentsOf: Array("RIFF".utf8))
        appendLE(UInt32(36 + pcm.count))
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8))
        appendLE(UInt32(16))
        appendLE(format)
        appendLE(channels)
        appendLE(sampleRate)
        appendLE(byteRate)
        appendLE(blockAlign)
        appendLE(bitsPerSample)
        wav.append(contentsOf: Array("data".utf8))
        appendLE(UInt32(pcm.count))
        wav.append(pcm)
        return wav
    }
}
