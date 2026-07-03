import AVFoundation

/// Decodes an arbitrary audio file (wav, aiff, mp3, m4a, caf…) to 16 kHz mono
/// Float32 samples — whisper's input format — for the "Transcribe Audio
/// File…" feature and the CLI's non-WAV fallback path.
enum AudioFileDecoder {
    struct DecodeError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    /// Reads the whole file in chunks, converts each chunk to the target
    /// format (mirrors `Recorder`'s converter usage), and drains the
    /// converter at EOF so trailing buffered frames aren't lost.
    static func samples(fromFileAt url: URL) throws -> [Float] {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw DecodeError(message: "couldn't read audio file: \(error.localizedDescription)")
        }

        let sourceFormat = file.processingFormat
        guard sourceFormat.sampleRate > 0, sourceFormat.channelCount > 0 else {
            throw DecodeError(message: "unsupported audio file: no readable audio track")
        }
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw DecodeError(message: "couldn't create audio converter for this file")
        }

        var result: [Float] = []
        let chunkFrames: AVAudioFrameCount = 32768
        var reachedEOF = false

        // Pulls the next chunk from the file on demand; the converter calls
        // this block whenever it needs more input. Returns nil (endOfStream)
        // once the file is exhausted so the converter can drain and stop.
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if reachedEOF {
                outStatus.pointee = .endOfStream
                return nil
            }
            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: chunkFrames) else {
                outStatus.pointee = .endOfStream
                return nil
            }
            do {
                try file.read(into: inputBuffer, frameCount: chunkFrames)
            } catch {
                outStatus.pointee = .endOfStream
                return nil
            }
            if inputBuffer.frameLength == 0 {
                reachedEOF = true
                outStatus.pointee = .endOfStream
                return nil
            }
            outStatus.pointee = .haveData
            return inputBuffer
        }

        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(chunkFrames) * ratio) + 64

        // Repeatedly pull converted output until the converter reports
        // endOfStream with nothing left to drain, mirroring Recorder's
        // per-tap convert() call but looped to consume the whole file.
        convertLoop: while true {
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
                throw DecodeError(message: "couldn't allocate conversion buffer")
            }
            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError, withInputFrom: inputBlock)

            if let conversionError {
                throw DecodeError(message: "audio conversion failed: \(conversionError.localizedDescription)")
            }
            if outputBuffer.frameLength > 0, let channel = outputBuffer.floatChannelData {
                let converted = UnsafeBufferPointer(start: channel[0], count: Int(outputBuffer.frameLength))
                result.append(contentsOf: converted)
            }

            switch status {
            case .haveData, .inputRanDry:
                continue convertLoop
            case .endOfStream:
                break convertLoop
            case .error:
                throw DecodeError(message: "audio conversion failed")
            @unknown default:
                break convertLoop
            }
        }

        guard !result.isEmpty else {
            throw DecodeError(message: "audio file contains no decodable samples")
        }
        return result
    }
}
