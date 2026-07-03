import XCTest

/// Privacy guarantee, enforced: app code may only reference localhost URLs,
/// with one documented exception. See PRIVACY.md. If this test fails, a
/// non-local endpoint entered the app somewhere it isn't supposed to be.
final class NetworkAuditTests: XCTestCase {
    /// Per-file allowlist of extra non-localhost URL literals. Keep this as
    /// narrow as possible: ModelDownloader.swift is the ONLY file allowed to
    /// reference huggingface.co, because it's the only place the app ever
    /// contacts a remote host — and only when the user explicitly clicks
    /// Download. Every other file must stay localhost-only; if huggingface
    /// (or any other remote URL) shows up anywhere else, this test must fail.
    private let allowlist: [String: [String]] = [
        "ModelDownloader.swift": ["https://huggingface.co"],
    ]

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
            let allowedPrefixes = allowlist[file.lastPathComponent] ?? []
            for line in text.split(separator: "\n")
            where line.contains("http://") || line.contains("https://") {
                let isLocal = line.contains("127.0.0.1") || line.contains("localhost")
                let isAllowedException = allowedPrefixes.contains { line.contains($0) }
                XCTAssertTrue(
                    isLocal || isAllowedException,
                    "\(file.lastPathComponent) references a non-local URL: \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }

    /// Proves the allowlist is genuinely per-file: a huggingface.co
    /// reference is fine in ModelDownloader.swift but must NOT be silently
    /// permitted anywhere else. This guards against someone widening the
    /// allowlist (e.g. to a blanket string match) instead of keeping it
    /// scoped to a single file.
    func testHuggingFaceAllowlistIsScopedToModelDownloaderOnly() {
        for (file, urls) in allowlist {
            XCTAssertEqual(file, "ModelDownloader.swift",
                           "Only ModelDownloader.swift may have a non-localhost allowlist entry, found: \(file)")
            XCTAssertEqual(urls, ["https://huggingface.co"])
        }
        XCTAssertEqual(allowlist.count, 1, "allowlist must not grow without an explicit, reviewed reason")
    }
}
