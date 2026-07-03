import XCTest

/// Privacy guarantee, enforced: app code may only reference localhost URLs,
/// with documented exceptions. See PRIVACY.md. If this test fails, a
/// non-local endpoint entered the app somewhere it isn't supposed to be.
final class NetworkAuditTests: XCTestCase {
    /// Per-file allowlist of extra non-localhost URL literals. Keep this as
    /// narrow as possible:
    /// - ModelDownloader.swift is the only file allowed to reference
    ///   huggingface.co, because it's the only place the app ever contacts a
    ///   remote host directly — and only when the user explicitly clicks
    ///   Download.
    /// - OnboardingWindowController.swift is the only file allowed to
    ///   reference ollama.com — a single "Get Ollama" link opened via
    ///   NSWorkspace in the user's BROWSER. The app itself never fetches that
    ///   URL; see PRIVACY.md.
    /// Every other file must stay localhost-only; if huggingface.co,
    /// ollama.com, or any other remote URL shows up anywhere else, this test
    /// must fail.
    private let allowlist: [String: [String]] = [
        "ModelDownloader.swift": ["https://huggingface.co"],
        "OnboardingWindowController.swift": ["https://ollama.com"],
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

    /// Pins the allowlist EXACTLY: two entries, each scoped to one file and
    /// one URL. This guards against someone widening the allowlist (e.g. to a
    /// blanket string match, a third file, or a broadened URL) instead of
    /// keeping each exception narrow and reviewed. Any third entry, renamed
    /// file, or widened URL fails this test.
    func testAllowlistIsScopedExactlyToKnownExceptions() {
        XCTAssertEqual(allowlist.count, 2, "allowlist must not grow without an explicit, reviewed reason")
        XCTAssertEqual(allowlist["ModelDownloader.swift"], ["https://huggingface.co"],
                       "ModelDownloader.swift must be allowed exactly https://huggingface.co, nothing more")
        XCTAssertEqual(allowlist["OnboardingWindowController.swift"], ["https://ollama.com"],
                       "OnboardingWindowController.swift must be allowed exactly https://ollama.com, nothing more")
        let knownFiles: Set<String> = ["ModelDownloader.swift", "OnboardingWindowController.swift"]
        for file in allowlist.keys {
            XCTAssertTrue(knownFiles.contains(file),
                          "Unexpected allowlist entry for \(file) — every exception must be reviewed and named here")
        }
    }
}
