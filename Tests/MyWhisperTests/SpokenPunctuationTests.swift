import XCTest
@testable import MyWhisper

final class SpokenPunctuationTests: XCTestCase {

    // MARK: - English mappings

    func testEnglishComma() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello comma world"), "hello, world")
    }

    func testEnglishPeriod() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello period world"), "hello. World")
    }

    func testEnglishFullStop() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello full stop world"), "hello. World")
    }

    func testEnglishQuestionMark() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello question mark world"), "hello? World")
    }

    func testEnglishExclamationMark() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello exclamation mark world"), "hello! World")
    }

    func testEnglishColon() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello colon world"), "hello: world")
    }

    func testEnglishSemicolon() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello semicolon world"), "hello; world")
    }

    func testEnglishNewLine() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello new line world"), "hello\nWorld")
    }

    func testEnglishNewParagraph() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello new paragraph world"), "hello\n\nWorld")
    }

    // MARK: - Indonesian mappings

    func testIndonesianKoma() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo koma dunia"), "halo, dunia")
    }

    func testIndonesianTitikDua() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo titik dua dunia"), "halo: dunia")
    }

    func testIndonesianTitikKoma() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo titik koma dunia"), "halo; dunia")
    }

    func testIndonesianTitik() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo titik dunia"), "halo. Dunia")
    }

    func testIndonesianTandaTanya() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo tanda tanya dunia"), "halo? Dunia")
    }

    func testIndonesianTandaSeru() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo tanda seru dunia"), "halo! Dunia")
    }

    func testIndonesianBarisBaru() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo baris baru dunia"), "halo\nDunia")
    }

    func testIndonesianParagrafBaru() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo paragraf baru dunia"), "halo\n\nDunia")
    }

    // MARK: - Core example from spec

    func testCoreExampleSentence() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo koma apa kabar titik"), "halo, apa kabar.")
    }

    // MARK: - Capitalization only after sentence-enders

    func testNoUppercaseAfterComma() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "apa kabar koma saya baik"), "apa kabar, saya baik")
    }

    func testNoUppercaseAfterColon() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "daftar titik dua satu dua tiga"), "daftar: satu dua tiga")
    }

    func testUppercaseAfterPeriod() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "apa kabar titik saya baik"), "apa kabar. Saya baik")
    }

    func testUppercaseAfterQuestionMark() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "siapa kamu question mark saya budi"), "siapa kamu? Saya budi")
    }

    func testUppercaseAfterExclamationMark() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hore exclamation mark kita menang"), "hore! Kita menang")
    }

    func testNoTrailingSpaceAtEndOfString() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "apa kabar titik"), "apa kabar.")
    }

    func testNoTrailingSpaceAtEndOfStringForComma() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo koma"), "halo,")
    }

    // MARK: - Multi-word precedence

    func testTitikDuaTakesPrecedenceOverTitik() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "waktu titik dua tiga puluh"), "waktu: tiga puluh")
        XCTAssertFalse(SpokenPunctuation.apply(to: "waktu titik dua tiga puluh").contains(". dua"))
    }

    func testTitikKomaTakesPrecedenceOverTitikAndKoma() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "satu titik koma dua"), "satu; dua")
    }

    func testFullStopTakesPrecedenceOverStandaloneWords() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "the end full stop"), "the end.")
    }

    func testNewParagraphTakesPrecedenceOverNewLine() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "one new paragraph two"), "one\n\nTwo")
    }

    // MARK: - Newline spacing rules

    func testNewlineHasNoSpaceBeforeOrAfter() {
        let result = SpokenPunctuation.apply(to: "hello new line world")
        XCTAssertFalse(result.contains(" \n"))
        XCTAssertFalse(result.contains("\n "))
        XCTAssertEqual(result, "hello\nWorld")
    }

    func testNewParagraphHasNoSpaceBeforeOrAfter() {
        let result = SpokenPunctuation.apply(to: "hello new paragraph world")
        XCTAssertFalse(result.contains(" \n"))
        XCTAssertFalse(result.contains("\n "))
        XCTAssertEqual(result, "hello\n\nWorld")
    }

    // MARK: - Boundary safety: words merely containing a token stay untouched

    func testKomandanUntouched() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "dia adalah komandan kami"), "dia adalah komandan kami")
    }

    func testTitiknyaUntouched() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "lihat titiknya di sana"), "lihat titiknya di sana")
    }

    func testBerkomatKamitUntouched() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "dia berkomat-kamit sendiri"), "dia berkomat-kamit sendiri")
    }

    func testCommandantEnglishLikeWordUntouched() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "periodic table is fun"), "periodic table is fun")
    }

    // MARK: - Mixed sentence, multiple tokens

    func testMixedSentenceWithSeveralTokens() {
        let input = "halo koma apa kabar titik saya baik titik dua senang bertemu tanda seru"
        XCTAssertEqual(SpokenPunctuation.apply(to: input), "halo, apa kabar. Saya baik: senang bertemu!")
    }

    // MARK: - No-token passthrough

    func testPassthroughWithNoTokens() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "just a normal sentence"), "just a normal sentence")
    }

    // MARK: - Empty string

    func testEmptyString() {
        XCTAssertEqual(SpokenPunctuation.apply(to: ""), "")
    }

    // MARK: - Case-insensitivity

    func testUppercaseTokenInput() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello KOMA world"), "hello, world")
    }

    func testMixedCaseToken() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "hello Period World"), "hello. World")
    }

    // MARK: - Duplicate collapse when whisper already added punctuation

    func testDuplicateCommaCollapses() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo koma, apa"), "halo, apa")
    }

    func testDuplicatePeriodCollapses() {
        XCTAssertEqual(SpokenPunctuation.apply(to: "halo kabar titik. Sampai jumpa"), "halo kabar. Sampai jumpa")
    }
}
