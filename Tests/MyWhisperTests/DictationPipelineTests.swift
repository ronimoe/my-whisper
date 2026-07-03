import XCTest
@testable import MyWhisper

/// Unit tests for the pure, engine-free portion of the shared pipeline:
/// `DictationPipeline.process` (clean → lexicon → command-match → punctuation).
/// The full `run` orchestration (CodeSwitch params, transcribe, AI rewrite) is
/// exercised end-to-end by the CLI parity checks rather than here, since it
/// depends on a live transcription engine and Ollama.
final class DictationPipelineTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DictationPipelineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try super.tearDownWithError()
    }

    /// An empty/identity lexicon (no vocabulary, no replacements).
    private func emptyLexicon() -> Lexicon {
        Lexicon.load(from: tempDir.appendingPathComponent("missing.json"))
    }

    /// A lexicon that applies the given find/replace pairs.
    private func lexicon(replacements: [(find: String, replace: String)]) -> Lexicon {
        let pairs = replacements
            .map { "{\"find\": \"\($0.find)\", \"replace\": \"\($0.replace)\"}" }
            .joined(separator: ",")
        let url = tempDir.appendingPathComponent("replacements-\(UUID().uuidString).json")
        let json = "{ \"replacements\": [\(pairs)] }"
        try? json.write(to: url, atomically: true, encoding: .utf8)
        return Lexicon.load(from: url)
    }

    // MARK: - Plain text passthrough

    func testPlainTextPassthrough() {
        let outcome = DictationPipeline.process(rawTranscript: "hello world",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: false)
        XCTAssertEqual(outcome, .text("hello world"))
    }

    /// Postprocess.clean is applied before anything else: collapse whitespace,
    /// drop noise-only annotations.
    func testCleanIsApplied() {
        let outcome = DictationPipeline.process(rawTranscript: "  hello   world  ",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: false)
        XCTAssertEqual(outcome, .text("hello world"))
    }

    func testNoiseOnlyAnnotationBecomesEmpty() {
        let outcome = DictationPipeline.process(rawTranscript: "[BLANK_AUDIO]",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: false)
        XCTAssertEqual(outcome, .empty)
    }

    // MARK: - Lexicon replacement

    func testLexiconReplacementApplied() {
        let lex = lexicon(replacements: [(find: "my whisper", replace: "MyWhisper")])
        let outcome = DictationPipeline.process(rawTranscript: "I use my whisper daily",
                                                lexicon: lex,
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: false)
        XCTAssertEqual(outcome, .text("I use MyWhisper daily"))
    }

    // MARK: - Voice command interception

    func testVoiceCommandInterceptionReturnsCommand() {
        let outcome = DictationPipeline.process(rawTranscript: "scratch that",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: false)
        XCTAssertEqual(outcome, .command(.undoLastDictation))
    }

    /// A transcript that is exactly a punctuation command word must be caught as
    /// a command BEFORE spoken-punctuation runs — "new paragraph" alone stays a
    /// command and is not converted into "\n\n".
    func testCommandMatchWinsOverPunctuationWhenBothEnabled() {
        let outcome = DictationPipeline.process(rawTranscript: "new paragraph",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: true)
        XCTAssertEqual(outcome, .command(.newParagraph))
    }

    /// Command matching only happens when voice commands are enabled; with them
    /// off, "new paragraph" flows into the punctuation step instead.
    func testCommandNotMatchedWhenVoiceCommandsDisabled() {
        let outcome = DictationPipeline.process(rawTranscript: "new paragraph",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: false,
                                                spokenPunctuationEnabled: true)
        XCTAssertEqual(outcome, .text("\n\n"))
    }

    /// With voice commands off and punctuation also off, the same transcript is
    /// just plain text.
    func testCommandTextIsPlainTextWhenBothDisabled() {
        let outcome = DictationPipeline.process(rawTranscript: "new paragraph",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: false,
                                                spokenPunctuationEnabled: false)
        XCTAssertEqual(outcome, .text("new paragraph"))
    }

    /// A command word is only intercepted when the cleaned text is non-empty and
    /// entirely a command; inline usage flows through as text.
    func testInlineCommandWordIsNotIntercepted() {
        let outcome = DictationPipeline.process(rawTranscript: "please undo that",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: false)
        XCTAssertEqual(outcome, .text("please undo that"))
    }

    // MARK: - Spoken punctuation

    func testSpokenPunctuationAppliedWhenEnabled() {
        let outcome = DictationPipeline.process(rawTranscript: "halo koma apa kabar titik",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: false,
                                                spokenPunctuationEnabled: true)
        XCTAssertEqual(outcome, .text("halo, apa kabar."))
    }

    func testSpokenPunctuationNotAppliedWhenDisabled() {
        let outcome = DictationPipeline.process(rawTranscript: "halo koma apa kabar titik",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: false,
                                                spokenPunctuationEnabled: false)
        XCTAssertEqual(outcome, .text("halo koma apa kabar titik"))
    }

    // MARK: - Empty / whitespace transcripts

    func testEmptyTranscriptIsEmpty() {
        let outcome = DictationPipeline.process(rawTranscript: "",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: true)
        XCTAssertEqual(outcome, .empty)
    }

    func testWhitespaceOnlyTranscriptIsEmpty() {
        let outcome = DictationPipeline.process(rawTranscript: "    \n  ",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: true)
        XCTAssertEqual(outcome, .empty)
    }

    /// A punctuation-only transcript that collapses to empty after cleaning must
    /// not be matched as a command (guarded by the non-empty check) and stays
    /// empty.
    func testEmptyIsNotMatchedAsCommand() {
        let outcome = DictationPipeline.process(rawTranscript: "   ",
                                                lexicon: emptyLexicon(),
                                                voiceCommandsEnabled: true,
                                                spokenPunctuationEnabled: false)
        XCTAssertEqual(outcome, .empty)
    }
}
