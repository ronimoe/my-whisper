import XCTest
@testable import MyWhisper

final class SettingsTests: XCTestCase {
    func testDisplayNameStripsGgmlPrefixAndBinExtension() {
        let url = URL(fileURLWithPath: "/models/ggml-large-v3-turbo.bin")
        XCTAssertEqual(Settings.displayName(forModel: url), "large-v3-turbo")
    }

    func testDisplayNameLeavesNamesWithoutPrefixIntact() {
        let url = URL(fileURLWithPath: "/models/tiny.bin")
        XCTAssertEqual(Settings.displayName(forModel: url), "tiny")
    }
}
