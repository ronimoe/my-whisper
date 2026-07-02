import XCTest
@testable import MyWhisper

final class CodeSwitchTests: XCTestCase {
    func testPassthroughKeepsExplicitLanguageAndVocabPrompt() {
        let result = CodeSwitch.requestParameters(language: "en", primary: "id", vocabularyPrompt: "vocab")
        XCTAssertEqual(result.language, "en")
        XCTAssertEqual(result.prompt, "vocab")
    }

    func testPassthroughKeepsAutoWithNilPrompt() {
        let result = CodeSwitch.requestParameters(language: "auto", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "auto")
        XCTAssertNil(result.prompt)
    }

    func testMixedWithNilVocabUsesPrimingExampleOnly() {
        let result = CodeSwitch.requestParameters(language: "mixed", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "id")
        XCTAssertEqual(result.prompt, CodeSwitch.primingExample)
    }

    func testMixedWithEmptyVocabUsesPrimingExampleOnly() {
        let result = CodeSwitch.requestParameters(language: "mixed", primary: "id", vocabularyPrompt: "")
        XCTAssertEqual(result.language, "id")
        XCTAssertEqual(result.prompt, CodeSwitch.primingExample)
    }

    func testMixedWithVocabCombinesVocabAndPrimingExample() {
        let result = CodeSwitch.requestParameters(language: "mixed", primary: "id", vocabularyPrompt: "MyWhisper, Jakarta")
        XCTAssertEqual(result.language, "id")
        XCTAssertEqual(result.prompt, "MyWhisper, Jakarta. " + CodeSwitch.primingExample)
    }

    func testMixedRespectsDifferentPrimaryLanguage() {
        let result = CodeSwitch.requestParameters(language: "mixed", primary: "ms", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "ms")
        XCTAssertEqual(result.prompt, CodeSwitch.primingExample)
    }

    // MARK: - Indonesian auto-punctuation priming

    func testIndonesianWithNilVocabUsesPunctuationPrimingOnly() {
        let result = CodeSwitch.requestParameters(language: "id", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "id")
        XCTAssertEqual(result.prompt, CodeSwitch.idPunctuationPriming)
    }

    func testIndonesianWithEmptyVocabUsesPunctuationPrimingOnly() {
        let result = CodeSwitch.requestParameters(language: "id", primary: "id", vocabularyPrompt: "")
        XCTAssertEqual(result.language, "id")
        XCTAssertEqual(result.prompt, CodeSwitch.idPunctuationPriming)
    }

    func testIndonesianWithVocabCombinesVocabAndPunctuationPriming() {
        let result = CodeSwitch.requestParameters(language: "id", primary: "en", vocabularyPrompt: "MyWhisper, Jakarta")
        XCTAssertEqual(result.language, "id")
        XCTAssertEqual(result.prompt, "MyWhisper, Jakarta. " + CodeSwitch.idPunctuationPriming)
    }

    func testEnglishPassthroughUnaffectedByIndonesianPriming() {
        let result = CodeSwitch.requestParameters(language: "en", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "en")
        XCTAssertNil(result.prompt)
    }

    func testAutoPassthroughUnaffectedByIndonesianPriming() {
        let result = CodeSwitch.requestParameters(language: "auto", primary: "id", vocabularyPrompt: "vocab")
        XCTAssertEqual(result.language, "auto")
        XCTAssertEqual(result.prompt, "vocab")
    }

    func testMixedBehaviorUnchangedByIndonesianPriming() {
        let result = CodeSwitch.requestParameters(language: "mixed", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "id")
        XCTAssertEqual(result.prompt, CodeSwitch.primingExample)
        XCTAssertNotEqual(result.prompt, CodeSwitch.idPunctuationPriming)
    }
}
