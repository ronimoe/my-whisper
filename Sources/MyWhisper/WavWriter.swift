import Foundation

enum WavWriter {
    /// Encodes float samples in [-1, 1] as a 16-bit PCM mono WAV file.
    static func data(fromSamples samples: [Float], sampleRate: UInt32 = 16000) -> Data {
        var int16Samples = [Int16](repeating: 0, count: samples.count)
        for i in 0..<samples.count {
            let clamped = max(-1.0, min(1.0, samples[i]))
            int16Samples[i] = Int16(clamped * 32767).littleEndian
        }
        let pcm = int16Samples.withUnsafeBufferPointer { Data(buffer: $0) }
        var wav = Data(capacity: pcm.count + 44)
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.appendLE(UInt32(36 + pcm.count))
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8))
        wav.appendLE(UInt32(16))
        wav.appendLE(UInt16(1))              // linear PCM
        wav.appendLE(UInt16(1))              // mono
        wav.appendLE(sampleRate)
        wav.appendLE(sampleRate * 2)         // byte rate
        wav.appendLE(UInt16(2))              // block align
        wav.appendLE(UInt16(16))             // bits per sample
        wav.append(contentsOf: Array("data".utf8))
        wav.appendLE(UInt32(pcm.count))
        wav.append(pcm)
        return wav
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
