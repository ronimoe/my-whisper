import XCTest
@testable import MyWhisper

final class WavWriterTests: XCTestCase {
    func testDataSizeIs44PlusTwoTimesSampleCount() {
        let samples: [Float] = [0.0, 0.1, -0.1, 0.5, -0.5]
        let data = WavWriter.data(fromSamples: samples)
        XCTAssertEqual(data.count, 44 + 2 * samples.count)
    }

    func testHeaderMagicBytes() {
        let data = WavWriter.data(fromSamples: [0.0, 0.1])
        XCTAssertEqual(string(in: data, range: 0..<4), "RIFF")
        XCTAssertEqual(string(in: data, range: 8..<12), "WAVE")
        XCTAssertEqual(string(in: data, range: 12..<16), "fmt ")
        XCTAssertEqual(string(in: data, range: 36..<40), "data")
    }

    func testSampleRateLittleEndianAtOffset24() {
        let data = WavWriter.data(fromSamples: [0.0])
        let rate = data.withUnsafeBytes { raw -> UInt32 in
            let bytes = raw.bindMemory(to: UInt8.self)
            return UInt32(bytes[24]) | (UInt32(bytes[25]) << 8) | (UInt32(bytes[26]) << 16) | (UInt32(bytes[27]) << 24)
        }
        XCTAssertEqual(rate, 16000)
    }

    func testPositiveClipTo32767() {
        let data = WavWriter.data(fromSamples: [2.0])
        XCTAssertEqual(sampleInt16(data, index: 0), 32767)
    }

    func testNegativeClipToMinus32767() {
        let data = WavWriter.data(fromSamples: [-2.0])
        XCTAssertEqual(sampleInt16(data, index: 0), -32767)
    }

    func testHalfSampleEncodesTo16383() {
        let data = WavWriter.data(fromSamples: [0.5])
        XCTAssertEqual(sampleInt16(data, index: 0), 16383)
    }

    // MARK: - Helpers

    private func string(in data: Data, range: Range<Int>) -> String {
        let slice = data.subdata(in: range)
        return String(data: slice, encoding: .ascii) ?? ""
    }

    private func sampleInt16(_ data: Data, index: Int) -> Int16 {
        let offset = 44 + index * 2
        return data.withUnsafeBytes { raw -> Int16 in
            let bytes = raw.bindMemory(to: UInt8.self)
            let lo = UInt16(bytes[offset])
            let hi = UInt16(bytes[offset + 1])
            return Int16(bitPattern: lo | (hi << 8))
        }
    }
}
