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

    // MARK: - pickModel

    private let bundled = URL(fileURLWithPath: "/Applications/MyWhisper.app/Contents/Resources/models/ggml-small-q5_1.bin")

    func testPickModelExplicitPathWinsWhenItExists() {
        let explicit = "/Users/x/Library/Application Support/MyWhisper/models/ggml-tiny.bin"
        let userModels = [URL(fileURLWithPath: "/models/ggml-large-v3-turbo.bin")]
        let result = Settings.pickModel(
            explicitPath: explicit,
            explicitPathExists: true,
            userModels: userModels,
            bundledStarter: bundled)
        XCTAssertEqual(result, URL(fileURLWithPath: explicit))
    }

    func testPickModelIgnoresExplicitPathWhenItDoesNotExist() {
        let explicit = "/Users/x/Library/Application Support/MyWhisper/models/ggml-tiny.bin"
        let userModels = [URL(fileURLWithPath: "/models/ggml-large-v3-turbo.bin")]
        let result = Settings.pickModel(
            explicitPath: explicit,
            explicitPathExists: false,
            userModels: userModels,
            bundledStarter: bundled)
        XCTAssertEqual(result, URL(fileURLWithPath: "/models/ggml-large-v3-turbo.bin"))
    }

    func testPickModelPreferredOrderingMediumBeatsSmall() {
        let userModels = [
            URL(fileURLWithPath: "/models/ggml-small.bin"),
            URL(fileURLWithPath: "/models/ggml-medium.bin"),
        ]
        let result = Settings.pickModel(
            explicitPath: nil,
            explicitPathExists: false,
            userModels: userModels,
            bundledStarter: bundled)
        XCTAssertEqual(result, URL(fileURLWithPath: "/models/ggml-medium.bin"))
    }

    func testPickModelPreferredOrderingTurboBeatsEverything() {
        let userModels = [
            URL(fileURLWithPath: "/models/ggml-large-v3.bin"),
            URL(fileURLWithPath: "/models/ggml-large-v3-turbo.bin"),
            URL(fileURLWithPath: "/models/ggml-tiny.bin"),
        ]
        let result = Settings.pickModel(
            explicitPath: nil,
            explicitPathExists: false,
            userModels: userModels,
            bundledStarter: bundled)
        XCTAssertEqual(result, URL(fileURLWithPath: "/models/ggml-large-v3-turbo.bin"))
    }

    func testPickModelFallsBackToFirstUserModelWhenNoneMatchPreferredNames() {
        let userModels = [
            URL(fileURLWithPath: "/models/ggml-custom-fancy.bin"),
            URL(fileURLWithPath: "/models/ggml-another.bin"),
        ]
        let result = Settings.pickModel(
            explicitPath: nil,
            explicitPathExists: false,
            userModels: userModels,
            bundledStarter: bundled)
        XCTAssertEqual(result, userModels.first)
    }

    func testPickModelNoUserModelsReturnsBundledStarter() {
        let result = Settings.pickModel(
            explicitPath: nil,
            explicitPathExists: false,
            userModels: [],
            bundledStarter: bundled)
        XCTAssertEqual(result, bundled)
    }

    func testPickModelUserModelBeatsBundled() {
        let userModels = [URL(fileURLWithPath: "/models/ggml-tiny.bin")]
        let result = Settings.pickModel(
            explicitPath: nil,
            explicitPathExists: false,
            userModels: userModels,
            bundledStarter: bundled)
        XCTAssertEqual(result, userModels.first)
    }

    func testPickModelNothingAnywhereReturnsNil() {
        let result = Settings.pickModel(
            explicitPath: nil,
            explicitPathExists: false,
            userModels: [],
            bundledStarter: nil)
        XCTAssertNil(result)
    }

    func testPickModelNoExplicitPathAndNoUserModelsFallsBackToBundledEvenIfExplicitPathNil() {
        // explicitPath nil (no modelPath saved at all) — should skip straight
        // to userModels/bundled logic without consulting explicitPathExists.
        let result = Settings.pickModel(
            explicitPath: nil,
            explicitPathExists: true,
            userModels: [],
            bundledStarter: bundled)
        XCTAssertEqual(result, bundled)
    }

    // MARK: - isBundledStarter (pure helper, resourceURL injected)

    func testIsBundledStarterTrueForPathUnderResourceURL() {
        // Simulate: resourceURL = /Applications/MyWhisper.app/Contents/Resources
        let resourceURL = URL(fileURLWithPath: "/Applications/MyWhisper.app/Contents/Resources")
        let candidate = resourceURL.appendingPathComponent("models/ggml-small-q5_1.bin")
        XCTAssertTrue(Settings.isBundledStarter(candidate, under: resourceURL))
    }

    func testIsBundledStarterFalseForUserModelsPath() {
        let resourceURL = URL(fileURLWithPath: "/Applications/MyWhisper.app/Contents/Resources")
        let candidate = URL(fileURLWithPath: "/Users/x/Library/Application Support/MyWhisper/models/ggml-tiny.bin")
        XCTAssertFalse(Settings.isBundledStarter(candidate, under: resourceURL))
    }

    func testIsBundledStarterFalseWhenResourceURLNil() {
        let candidate = URL(fileURLWithPath: "/Applications/MyWhisper.app/Contents/Resources/models/ggml-small-q5_1.bin")
        XCTAssertFalse(Settings.isBundledStarter(candidate, under: nil))
    }

    /// Public single-arg API matches against the real Bundle.main.resourceURL.
    /// In the SPM test bundle that's nil, so bundled-starter detection is
    /// always false here — this just verifies the method exists and doesn't crash.
    func testIsBundledStarterPublicAPIDoesNotCrash() {
        let candidate = URL(fileURLWithPath: "/Applications/MyWhisper.app/Contents/Resources/models/ggml-small-q5_1.bin")
        _ = Settings.isBundledStarter(candidate)
    }
}
