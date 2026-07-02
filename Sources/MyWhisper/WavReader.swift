import Foundation

/// Decodes a 16 kHz mono 16-bit PCM WAV file into float samples in [-1, 1].
/// The inverse of `WavWriter.data(fromSamples:)`. Walks the RIFF chunk list
/// rather than assuming the data starts at byte 44, so files with padding
/// chunks (e.g. the recorder's "FLLR"-padded WAVs) decode correctly.
enum WavReader {
    struct DecodeError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func samples(fromWavData data: Data) throws -> [Float] {
        // Reject undersized data early; the header alone is 44 bytes.
        guard data.count >= 12 else {
            throw DecodeError(message: "WAV data too short")
        }
        guard readFourCC(data, at: 0) == "RIFF", readFourCC(data, at: 8) == "WAVE" else {
            throw DecodeError(message: "not a RIFF/WAVE file")
        }

        var fmt: (audioFormat: UInt16, channels: UInt16, sampleRate: UInt32, bitsPerSample: UInt16)?
        var dataRange: Range<Int>?

        // Walk chunks starting right after "WAVE" (offset 12).
        var offset = 12
        while offset + 8 <= data.count {
            let chunkID = readFourCC(data, at: offset)
            let chunkSize = Int(readUInt32LE(data, at: offset + 4))
            let bodyStart = offset + 8
            guard chunkSize >= 0, bodyStart + chunkSize <= data.count else {
                throw DecodeError(message: "corrupt WAV: chunk '\(chunkID)' overruns file")
            }
            switch chunkID {
            case "fmt ":
                guard chunkSize >= 16 else {
                    throw DecodeError(message: "corrupt WAV: fmt chunk too small")
                }
                fmt = (audioFormat: readUInt16LE(data, at: bodyStart),
                       channels: readUInt16LE(data, at: bodyStart + 2),
                       sampleRate: readUInt32LE(data, at: bodyStart + 4),
                       bitsPerSample: readUInt16LE(data, at: bodyStart + 14))
            case "data":
                dataRange = bodyStart..<(bodyStart + chunkSize)
            default:
                break
            }
            // Chunks are word-aligned: an odd size is followed by a pad byte.
            offset = bodyStart + chunkSize + (chunkSize & 1)
        }

        guard let fmt else { throw DecodeError(message: "WAV missing fmt chunk") }
        guard let dataRange else { throw DecodeError(message: "WAV missing data chunk") }

        guard fmt.audioFormat == 1 else {
            throw DecodeError(message: "unsupported WAV: expected PCM (format 1), got format \(fmt.audioFormat)")
        }
        guard fmt.channels == 1 else {
            throw DecodeError(message: "unsupported WAV: expected mono, got \(fmt.channels) channels")
        }
        guard fmt.bitsPerSample == 16 else {
            throw DecodeError(message: "unsupported WAV: expected 16-bit, got \(fmt.bitsPerSample)-bit")
        }
        guard fmt.sampleRate == 16000 else {
            throw DecodeError(message: "unsupported WAV: expected 16000 Hz, got \(fmt.sampleRate) Hz")
        }

        let frameCount = dataRange.count / 2
        var samples = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let byteOffset = dataRange.lowerBound + i * 2
            let lo = UInt16(data[byteOffset])
            let hi = UInt16(data[byteOffset + 1])
            let raw = Int16(bitPattern: lo | (hi << 8))
            samples[i] = Float(raw) / 32768.0
        }
        return samples
    }

    // MARK: - Little-endian readers

    private static func readFourCC(_ data: Data, at offset: Int) -> String {
        let bytes = [data[offset], data[offset + 1], data[offset + 2], data[offset + 3]]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private static func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }
}
