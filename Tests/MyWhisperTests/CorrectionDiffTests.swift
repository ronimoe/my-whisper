import XCTest
@testable import MyWhisper

final class CorrectionDiffTests: XCTestCase {
    func testSingleWordMiddleCorrection() {
        let rule = CorrectionDiff.suggestRule(
            original: "tolong follow up klien besok",
            corrected: "tolong follow up client besok")
        XCTAssertEqual(rule?.find, "klien")
        XCTAssertEqual(rule?.replace, "client")
    }

    func testSingleWordMiddleCorrectionShortWords() {
        let rule = CorrectionDiff.suggestRule(
            original: "kirim project dek ke tim",
            corrected: "kirim project deck ke tim")
        XCTAssertEqual(rule?.find, "dek")
        XCTAssertEqual(rule?.replace, "deck")
    }

    func testMultiWordMiddleSingleWord() {
        let rule = CorrectionDiff.suggestRule(
            original: "say hello wold now",
            corrected: "say hello world now")
        XCTAssertEqual(rule?.find, "wold")
        XCTAssertEqual(rule?.replace, "world")
    }

    func testMultiWordMiddleTwoWords() {
        let rule = CorrectionDiff.suggestRule(original: "a b c d", corrected: "a x y d")
        XCTAssertEqual(rule?.find, "b c")
        XCTAssertEqual(rule?.replace, "x y")
    }

    func testChangeAtVeryStart() {
        let rule = CorrectionDiff.suggestRule(original: "kolam is here", corrected: "column is here")
        XCTAssertEqual(rule?.find, "kolam")
        XCTAssertEqual(rule?.replace, "column")
    }

    func testChangeAtVeryEnd() {
        let rule = CorrectionDiff.suggestRule(original: "send to tim", corrected: "send to team")
        XCTAssertEqual(rule?.find, "tim")
        XCTAssertEqual(rule?.replace, "team")
    }

    func testIdenticalStringsReturnNil() {
        XCTAssertNil(CorrectionDiff.suggestRule(original: "same text here", corrected: "same text here"))
    }

    /// Pure insertion: the word-boundary algorithm backs the find window off
    /// until it is empty (there is no changed word, only a new one inserted),
    /// so an empty find — which would match everywhere — must be nil.
    func testPureInsertionMiddleReturnsNil() {
        XCTAssertNil(CorrectionDiff.suggestRule(original: "a b", corrected: "a x b"))
    }

    /// Same pure-insertion shape with real words: "it" is inserted between
    /// "send" and "now" with no corresponding original word to key off, so
    /// there is no reusable find text.
    func testPureInsertionOfWordReturnsNil() {
        XCTAssertNil(CorrectionDiff.suggestRule(original: "send now", corrected: "send it now"))
    }

    /// Deleting a word during correction must NOT produce a rule with an empty
    /// replace — that would silently delete the word from every future
    /// transcript ("it" here). Symmetric with the pure-insertion cases.
    func testPureDeletionOfWordReturnsNil() {
        XCTAssertNil(CorrectionDiff.suggestRule(original: "please send it now", corrected: "please send now"))
    }

    func testPureDeletionMiddleReturnsNil() {
        XCTAssertNil(CorrectionDiff.suggestRule(original: "a x b", corrected: "a b"))
    }

    func testFindLongerThan60CharsReturnsNil() {
        let original = String(repeating: "x", count: 70)
        let corrected = String(repeating: "y", count: 70)
        XCTAssertNil(CorrectionDiff.suggestRule(original: original, corrected: corrected))
    }

    func testFindExactly60CharsIsAllowed() {
        let original = String(repeating: "z", count: 60)
        let corrected = String(repeating: "w", count: 60)
        let rule = CorrectionDiff.suggestRule(original: original, corrected: corrected)
        XCTAssertEqual(rule?.find, original)
        XCTAssertEqual(rule?.replace, corrected)
    }

    func testWholeShortStringReplaced() {
        let rule = CorrectionDiff.suggestRule(original: "hi", corrected: "yo")
        XCTAssertEqual(rule?.find, "hi")
        XCTAssertEqual(rule?.replace, "yo")
    }

    /// Pinned behavior: the comma is not itself a word boundary, so it stays
    /// attached to the "halo" token on the find side; the word-boundary
    /// back-off only looks for spaces, not punctuation.
    func testPunctuationOnlyChangeIsPinned() {
        let rule = CorrectionDiff.suggestRule(original: "halo, apa kabar", corrected: "halo apa kabar")
        XCTAssertEqual(rule?.find, "halo,")
        XCTAssertEqual(rule?.replace, "halo")
    }

    func testFindEqualsReplaceReturnsNil() {
        // Same word on both sides surrounded by differing context that still
        // collapses back to an identical middle should not happen via normal
        // prefix/suffix trimming, but guard explicitly: identical middles are
        // not a reusable rule.
        XCTAssertNil(CorrectionDiff.suggestRule(original: "abc", corrected: "abc"))
    }
}
