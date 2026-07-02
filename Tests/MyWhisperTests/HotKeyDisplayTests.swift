import XCTest
import Carbon
@testable import MyWhisper

final class HotKeyDisplayTests: XCTestCase {
    func testModifiersComposeInControlOptionShiftCommandOrder() {
        let modifiers = UInt32(controlKey) | UInt32(optionKey) | UInt32(shiftKey) | UInt32(cmdKey)
        let display = HotKeyRecorder.displayString(
            carbonModifiers: modifiers, keyCode: 49, fallbackCharacters: nil)
        XCTAssertEqual(display, "⌃⌥⇧⌘Space")
    }

    func testKeyCode49IsSpace() {
        let display = HotKeyRecorder.displayString(
            carbonModifiers: 0, keyCode: 49, fallbackCharacters: nil)
        XCTAssertEqual(display, "Space")
    }

    func testKeyCode80IsF19() {
        let display = HotKeyRecorder.displayString(
            carbonModifiers: 0, keyCode: 80, fallbackCharacters: nil)
        XCTAssertEqual(display, "F19")
    }

    func testLetterFallbackUppercased() {
        let display = HotKeyRecorder.displayString(
            carbonModifiers: 0, keyCode: 0, fallbackCharacters: "a")
        XCTAssertEqual(display, "A")
    }
}
