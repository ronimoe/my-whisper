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

    // MARK: - Additional mixed-* pairs (Tagalog, Hindi, Spanish, Chinese)

    func testMixedTlWithNilVocabUsesTagalogPrimingAndFixedPrimary() {
        let result = CodeSwitch.requestParameters(language: "mixed-tl", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "tl")
        XCTAssertEqual(result.prompt, CodeSwitch.tlPrimingExample)
    }

    func testMixedHiWithNilVocabUsesHindiPrimingAndFixedPrimary() {
        let result = CodeSwitch.requestParameters(language: "mixed-hi", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "hi")
        XCTAssertEqual(result.prompt, CodeSwitch.hiPrimingExample)
    }

    func testMixedEsWithNilVocabUsesSpanishPrimingAndFixedPrimary() {
        let result = CodeSwitch.requestParameters(language: "mixed-es", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "es")
        XCTAssertEqual(result.prompt, CodeSwitch.esPrimingExample)
    }

    func testMixedZhWithNilVocabUsesChinesePrimingAndFixedPrimary() {
        let result = CodeSwitch.requestParameters(language: "mixed-zh", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "zh")
        XCTAssertEqual(result.prompt, CodeSwitch.zhPrimingExample)
    }

    func testMixedEsIgnoresPassedPrimaryUnlikeMixed() {
        // Unlike "mixed" (id+en), which honors the passed `primary`, the new
        // fixed pairs always return their table-defined primary regardless
        // of what's passed in.
        let result = CodeSwitch.requestParameters(language: "mixed-es", primary: "fr", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "es")
    }

    func testMixedEsWithVocabCombinesVocabAndSpanishPriming() {
        let result = CodeSwitch.requestParameters(language: "mixed-es", primary: "id", vocabularyPrompt: "vocab")
        XCTAssertEqual(result.language, "es")
        XCTAssertEqual(result.prompt, "vocab. " + CodeSwitch.esPrimingExample)
    }

    func testMixedTlWithEmptyVocabUsesPrimingExampleOnly() {
        let result = CodeSwitch.requestParameters(language: "mixed-tl", primary: "id", vocabularyPrompt: "")
        XCTAssertEqual(result.language, "tl")
        XCTAssertEqual(result.prompt, CodeSwitch.tlPrimingExample)
    }

    func testMixedHiWithVocabCombinesVocabAndHindiPriming() {
        let result = CodeSwitch.requestParameters(language: "mixed-hi", primary: "id", vocabularyPrompt: "MyWhisper, Jakarta")
        XCTAssertEqual(result.language, "hi")
        XCTAssertEqual(result.prompt, "MyWhisper, Jakarta. " + CodeSwitch.hiPrimingExample)
    }

    func testMixedZhWithVocabCombinesVocabAndChinesePriming() {
        let result = CodeSwitch.requestParameters(language: "mixed-zh", primary: "id", vocabularyPrompt: "vocab")
        XCTAssertEqual(result.language, "zh")
        XCTAssertEqual(result.prompt, "vocab. " + CodeSwitch.zhPrimingExample)
    }

    func testUnknownMixedCodeIsPassthroughUnchanged() {
        let result = CodeSwitch.requestParameters(language: "mixed-xx", primary: "id", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "mixed-xx")
        XCTAssertNil(result.prompt)
    }

    func testUnknownMixedCodeIsPassthroughWithVocabPrompt() {
        let result = CodeSwitch.requestParameters(language: "mixed-xx", primary: "id", vocabularyPrompt: "vocab")
        XCTAssertEqual(result.language, "mixed-xx")
        XCTAssertEqual(result.prompt, "vocab")
    }

    func testMixedStillHonorsPassedPrimaryParameter() {
        // Re-confirms the original "mixed" (id+en) code's dynamic-primary
        // behavior is untouched by the new fixed-primary pairs table.
        let result = CodeSwitch.requestParameters(language: "mixed", primary: "en", vocabularyPrompt: nil)
        XCTAssertEqual(result.language, "en")
        XCTAssertEqual(result.prompt, CodeSwitch.primingExample)
    }
}
