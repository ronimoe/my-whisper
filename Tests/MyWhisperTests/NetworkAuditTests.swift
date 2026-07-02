import XCTest

/// Privacy guarantee, enforced: app code may only reference localhost URLs.
/// See PRIVACY.md. If this test fails, a non-local endpoint entered the app.
final class NetworkAuditTests: XCTestCase {
    func testAppCodeOnlyTalksToLocalhost() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyWhisper")
        let files = try FileManager.default
            .contentsOfDirectory(at: sourcesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 5, "source scan found too few files — wrong path?")

        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n")
            where line.contains("http://") || line.contains("https://") {
                XCTAssertTrue(
                    line.contains("127.0.0.1") || line.contains("localhost"),
                    "\(file.lastPathComponent) references a non-local URL: \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }
}
