import XCTest
@testable import MyWhisper

final class ModeContextSubstituteTests: XCTestCase {
    func testBothPlaceholdersReplacedWithGivenValues() {
        let result = ModeContext.substitute(prompt: "In {app}, selection was: {selection}",
                                            appName: "Mail", selection: "hello world")
        XCTAssertEqual(result, "In Mail, selection was: hello world")
    }

    func testMultipleOccurrencesOfPlaceholdersAllReplaced() {
        let result = ModeContext.substitute(prompt: "{app} {app} {selection} {selection}",
                                            appName: "Notes", selection: "abc")
        XCTAssertEqual(result, "Notes Notes abc abc")
    }

    func testNilAppNameReplacedWithEmptyString() {
        let result = ModeContext.substitute(prompt: "App: [{app}]",
                                            appName: nil, selection: "abc")
        XCTAssertEqual(result, "App: []")
    }

    func testNilSelectionReplacedWithEmptyString() {
        let result = ModeContext.substitute(prompt: "Selection: [{selection}]",
                                            appName: "Mail", selection: nil)
        XCTAssertEqual(result, "Selection: []")
    }

    func testBothNilReplacedWithEmptyStrings() {
        let result = ModeContext.substitute(prompt: "[{app}][{selection}]",
                                            appName: nil, selection: nil)
        XCTAssertEqual(result, "[][]")
    }

    func testPromptWithoutPlaceholdersReturnsIdenticalString() {
        let prompt = "Rewrite the dictated text as a clear, polite email body."
        let result = ModeContext.substitute(prompt: prompt, appName: "Mail", selection: "abc")
        XCTAssertEqual(result, prompt)
    }

    func testEmptyPromptReturnsEmpty() {
        let result = ModeContext.substitute(prompt: "", appName: "Mail", selection: "abc")
        XCTAssertEqual(result, "")
    }

    func testPlaceholderOnlyPromptReturnsSelectionValue() {
        let result = ModeContext.substitute(prompt: "{selection}", appName: nil, selection: "abc")
        XCTAssertEqual(result, "abc")
    }

    func testPlaceholderOnlyPromptReturnsAppValue() {
        let result = ModeContext.substitute(prompt: "{app}", appName: "Xcode", selection: nil)
        XCTAssertEqual(result, "Xcode")
    }
}
