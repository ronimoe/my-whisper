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
}
