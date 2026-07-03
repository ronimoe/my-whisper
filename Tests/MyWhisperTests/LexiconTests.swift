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
}
