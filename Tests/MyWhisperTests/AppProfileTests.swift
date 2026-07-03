import XCTest
@testable import MyWhisper

final class AppProfileStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppProfileStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try super.tearDownWithError()
    }

    private func write(_ contents: String, name: String = "profiles.json") -> URL {
        let url = tempDir.appendingPathComponent(name)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - load(from:) decoding

    func testFullRuleDecodesAllFields() {
        let url = write("""
        [
          {"app": "Slack", "bundleId": "com.tinyspeck.slackmacgap", "language": "id",
           "mode": "Message", "spokenPunctuation": false, "translate": true}
        ]
        """)
        let profiles = AppProfileStore.load(from: url)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].app, "Slack")
        XCTAssertEqual(profiles[0].bundleId, "com.tinyspeck.slackmacgap")
        XCTAssertEqual(profiles[0].language, "id")
        XCTAssertEqual(profiles[0].mode, "Message")
        XCTAssertEqual(profiles[0].spokenPunctuation, false)
        XCTAssertEqual(profiles[0].translate, true)
    }

    func testPartialRuleDecodesOnlySpecifiedFieldsRestNil() {
        let url = write("""
        [
          {"app": "Terminal", "spokenPunctuation": false}
        ]
        """)
        let profiles = AppProfileStore.load(from: url)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].app, "Terminal")
        XCTAssertNil(profiles[0].bundleId)
        XCTAssertNil(profiles[0].language)
        XCTAssertNil(profiles[0].mode)
        XCTAssertEqual(profiles[0].spokenPunctuation, false)
        XCTAssertNil(profiles[0].translate)
    }

    func testEmptyArrayDecodesToEmpty() {
        let url = write("[]")
        XCTAssertEqual(AppProfileStore.load(from: url), [])
    }

    func testMissingFileReturnsEmptyArray() {
        let url = tempDir.appendingPathComponent("does-not-exist.json")
        XCTAssertEqual(AppProfileStore.load(from: url), [])
    }

    func testMalformedJSONReturnsEmptyArray() {
        let url = write("{ this is not valid json ")
        XCTAssertEqual(AppProfileStore.load(from: url), [])
    }

    // MARK: - ensureFileExists

    func testEnsureFileExistsWritesExampleRules() {
        let url = tempDir.appendingPathComponent("profiles.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        AppProfileStore.ensureFileExists(at: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let profiles = AppProfileStore.load(from: url)
        XCTAssertEqual(profiles.count, 3)
        XCTAssertEqual(profiles[0].app, "Slack")
        XCTAssertEqual(profiles[0].mode, "Message")
        XCTAssertEqual(profiles[1].bundleId, "com.apple.mail")
        XCTAssertEqual(profiles[1].mode, "Email")
        XCTAssertEqual(profiles[2].app, "Terminal")
        XCTAssertEqual(profiles[2].spokenPunctuation, false)
    }

    func testEnsureFileExistsDoesNotOverwriteExistingFile() {
        let url = write("""
        [
          {"app": "Custom"}
        ]
        """)
        AppProfileStore.ensureFileExists(at: url)
        let profiles = AppProfileStore.load(from: url)
        XCTAssertEqual(profiles.map(\.app), ["Custom"])
    }

    // MARK: - match

    func testMatchByAppNameCaseInsensitive() {
        let profiles = [AppProfile(app: "Slack", bundleId: nil, language: nil, mode: "Message",
                                   spokenPunctuation: nil, translate: nil)]
        let match = AppProfileStore.match(appName: "SLACK", bundleId: nil, in: profiles)
        XCTAssertEqual(match, profiles[0])
    }

    func testMatchByBundleId() {
        let profiles = [AppProfile(app: nil, bundleId: "com.apple.mail", language: nil, mode: "Email",
                                   spokenPunctuation: nil, translate: nil)]
        let match = AppProfileStore.match(appName: nil, bundleId: "com.apple.mail", in: profiles)
        XCTAssertEqual(match, profiles[0])
    }

    func testMatchByBundleIdCaseInsensitive() {
        let profiles = [AppProfile(app: nil, bundleId: "com.apple.mail", language: nil, mode: "Email",
                                   spokenPunctuation: nil, translate: nil)]
        let match = AppProfileStore.match(appName: nil, bundleId: "COM.APPLE.MAIL", in: profiles)
        XCTAssertEqual(match, profiles[0])
    }

    func testBundleIdMatchWorksWhenAppNameDiffers() {
        // Rule's `app` doesn't match the given appName, but bundleId does —
        // rule should still match since either field matching is sufficient.
        let profiles = [AppProfile(app: "Mail", bundleId: "com.apple.mail", language: nil,
                                   mode: "Email", spokenPunctuation: nil, translate: nil)]
        let match = AppProfileStore.match(appName: "Something Else", bundleId: "com.apple.mail",
                                          in: profiles)
        XCTAssertEqual(match, profiles[0])
    }

    func testFirstMatchWinsOrdering() {
        let first = AppProfile(app: "Slack", bundleId: nil, language: "id", mode: nil,
                               spokenPunctuation: nil, translate: nil)
        let second = AppProfile(app: "Slack", bundleId: nil, language: "en", mode: nil,
                                spokenPunctuation: nil, translate: nil)
        let match = AppProfileStore.match(appName: "Slack", bundleId: nil, in: [first, second])
        XCTAssertEqual(match, first)
    }

    func testNilAppNameAndBundleIdNeverMatchesNonNilPattern() {
        let profiles = [AppProfile(app: "Slack", bundleId: "com.tinyspeck.slackmacgap",
                                   language: nil, mode: "Message", spokenPunctuation: nil,
                                   translate: nil)]
        let match = AppProfileStore.match(appName: nil, bundleId: nil, in: profiles)
        XCTAssertNil(match)
    }

    func testNoMatchingRuleReturnsNil() {
        let profiles = [AppProfile(app: "Slack", bundleId: nil, language: nil, mode: "Message",
                                   spokenPunctuation: nil, translate: nil)]
        let match = AppProfileStore.match(appName: "Mail", bundleId: "com.apple.mail", in: profiles)
        XCTAssertNil(match)
    }

    func testEmptyRulesReturnsNil() {
        let match = AppProfileStore.match(appName: "Slack", bundleId: nil, in: [])
        XCTAssertNil(match)
    }
}

final class EffectiveDictationTests: XCTestCase {
    func testNoProfileReturnsBaseValues() {
        let eff = EffectiveDictation.resolve(language: "en", modeName: "Raw",
                                             spokenPunctuation: true, translate: false,
                                             profile: nil)
        XCTAssertEqual(eff.language, "en")
        XCTAssertEqual(eff.modeName, "Raw")
        XCTAssertEqual(eff.spokenPunctuation, true)
        XCTAssertEqual(eff.translate, false)
    }

    func testProfileOverridingOnlyLanguageKeepsOthers() {
        let profile = AppProfile(app: "Slack", bundleId: nil, language: "id", mode: nil,
                                 spokenPunctuation: nil, translate: nil)
        let eff = EffectiveDictation.resolve(language: "en", modeName: "Raw",
                                             spokenPunctuation: true, translate: false,
                                             profile: profile)
        XCTAssertEqual(eff.language, "id")
        XCTAssertEqual(eff.modeName, "Raw")
        XCTAssertEqual(eff.spokenPunctuation, true)
        XCTAssertEqual(eff.translate, false)
    }

    func testProfileOverridingEverything() {
        let profile = AppProfile(app: "Slack", bundleId: nil, language: "id", mode: "Message",
                                 spokenPunctuation: false, translate: true)
        let eff = EffectiveDictation.resolve(language: "en", modeName: "Raw",
                                             spokenPunctuation: true, translate: false,
                                             profile: profile)
        XCTAssertEqual(eff.language, "id")
        XCTAssertEqual(eff.modeName, "Message")
        XCTAssertEqual(eff.spokenPunctuation, false)
        XCTAssertEqual(eff.translate, true)
    }

    func testExplicitRawModeOverrideApplies() {
        // Base mode is a non-Raw mode; the profile explicitly forces "Raw".
        let profile = AppProfile(app: "Terminal", bundleId: nil, language: nil, mode: "Raw",
                                 spokenPunctuation: nil, translate: nil)
        let eff = EffectiveDictation.resolve(language: "en", modeName: "Email",
                                             spokenPunctuation: true, translate: false,
                                             profile: profile)
        XCTAssertEqual(eff.modeName, "Raw")
    }
}
