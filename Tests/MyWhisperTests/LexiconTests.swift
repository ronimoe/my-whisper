import XCTest
@testable import MyWhisper

final class LexiconTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LexiconTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try super.tearDownWithError()
    }

    private func write(_ contents: String, name: String = "replacements.json") -> URL {
        let url = tempDir.appendingPathComponent(name)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testValidFileAppliesCaseInsensitiveReplacement() {
        let url = write("""
        {
          "vocabulary": ["MyWhisper"],
          "replacements": [{"find": "my whisper", "replace": "MyWhisper"}]
        }
        """)
        let lexicon = Lexicon.load(from: url)
        XCTAssertEqual(lexicon.apply(to: "I use MY WHISPER daily"), "I use MyWhisper daily")
    }

    func testVocabularyPromptJoinsWithCommaSpace() {
        let url = write("""
        {
          "vocabulary": ["alpha", "beta", "gamma"]
        }
        """)
        let lexicon = Lexicon.load(from: url)
        XCTAssertEqual(lexicon.vocabularyPrompt, "alpha, beta, gamma")
    }

    func testVocabularyPromptNilForEmptyVocabulary() {
        let url = write("""
        {
          "vocabulary": []
        }
        """)
        let lexicon = Lexicon.load(from: url)
        XCTAssertNil(lexicon.vocabularyPrompt)
    }

    func testVocabularyPromptNilForMissingVocabulary() {
        let url = write("""
        {
          "replacements": [{"find": "a", "replace": "b"}]
        }
        """)
        let lexicon = Lexicon.load(from: url)
        XCTAssertNil(lexicon.vocabularyPrompt)
    }

    func testMissingFileIsIdentityAndNilPrompt() {
        let url = tempDir.appendingPathComponent("does-not-exist.json")
        let lexicon = Lexicon.load(from: url)
        XCTAssertEqual(lexicon.apply(to: "unchanged text"), "unchanged text")
        XCTAssertNil(lexicon.vocabularyPrompt)
    }

    func testMalformedJSONBehavesLikeMissingFile() {
        let url = write("{ this is not valid json ")
        let lexicon = Lexicon.load(from: url)
        XCTAssertEqual(lexicon.apply(to: "unchanged text"), "unchanged text")
        XCTAssertNil(lexicon.vocabularyPrompt)
    }

    func testLoadFromURLIsUncachedAcrossSuccessiveCalls() {
        // load(from:) must always re-read from disk (unlike the no-arg
        // load(), which caches the default production file by mtime).
        let url = write("""
        {
          "vocabulary": ["alpha"]
        }
        """)
        let first = Lexicon.load(from: url)
        XCTAssertEqual(first.vocabularyPrompt, "alpha")

        _ = write("""
        {
          "vocabulary": ["beta", "gamma"]
        }
        """, name: url.lastPathComponent)
        let second = Lexicon.load(from: url)
        XCTAssertEqual(second.vocabularyPrompt, "beta, gamma")
    }

    // MARK: - appendReplacement

    func testAppendToExistingFilePreservesVocabularyAndPriorRules() {
        let url = write("""
        {
          "vocabulary": ["MyWhisper"],
          "replacements": [{"find": "my whisper", "replace": "MyWhisper"}]
        }
        """)
        let ok = Lexicon.appendReplacement(find: "klien", replace: "client", to: url)
        XCTAssertTrue(ok)

        let lexicon = Lexicon.load(from: url)
        XCTAssertEqual(lexicon.vocabularyPrompt, "MyWhisper")
        XCTAssertEqual(lexicon.apply(to: "MY WHISPER project klien besok"),
                        "MyWhisper project client besok")
    }

    func testAppendToMissingFileCreatesItWithRule() {
        let url = tempDir.appendingPathComponent("does-not-exist.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))

        let ok = Lexicon.appendReplacement(find: "dek", replace: "deck", to: url)
        XCTAssertTrue(ok)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let lexicon = Lexicon.load(from: url)
        XCTAssertNil(lexicon.vocabularyPrompt)
        XCTAssertEqual(lexicon.apply(to: "kirim dek sekarang"), "kirim deck sekarang")
    }

    func testAppendToMalformedFileRecreatesWithRule() {
        let url = write("{ this is not valid json ")

        let ok = Lexicon.appendReplacement(find: "wold", replace: "world", to: url)
        XCTAssertTrue(ok)

        let lexicon = Lexicon.load(from: url)
        XCTAssertNil(lexicon.vocabularyPrompt)
        XCTAssertEqual(lexicon.apply(to: "hello wold"), "hello world")
    }

    func testDuplicateFindCaseInsensitiveUpdatesInsteadOfDuplicating() {
        let url = write("""
        {
          "vocabulary": [],
          "replacements": [{"find": "klien", "replace": "client"}]
        }
        """)
        let ok = Lexicon.appendReplacement(find: "KLIEN", replace: "customer", to: url)
        XCTAssertTrue(ok)

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let replacements = json["replacements"] as? [[String: String]] else {
            return XCTFail("expected valid replacements JSON")
        }
        XCTAssertEqual(replacements.count, 1)
        XCTAssertEqual(replacements.first?["replace"], "customer")

        let lexicon = Lexicon.load(from: url)
        XCTAssertEqual(lexicon.apply(to: "the klien called"), "the customer called")
    }

    func testWrittenFilePermsAre0600() {
        let url = tempDir.appendingPathComponent("perm-check.json")
        let ok = Lexicon.appendReplacement(find: "a", replace: "b", to: url)
        XCTAssertTrue(ok)

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let perms = attributes?[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.uint16Value, 0o600)
    }

    func testAppendedRuleRoundTripsThroughLoadAndApply() {
        let url = write("""
        {
          "vocabulary": ["existing"],
          "replacements": [{"find": "foo", "replace": "bar"}]
        }
        """)
        XCTAssertTrue(Lexicon.appendReplacement(find: "baz", replace: "qux", to: url))

        let lexicon = Lexicon.load(from: url)
        XCTAssertEqual(lexicon.apply(to: "foo and baz"), "bar and qux")
    }
}
