import AppKit
import Carbon

/// A small floating window that captures the next key combination pressed
/// and reports it as a (Carbon key code, Carbon modifiers, display string).
final class HotKeyRecorder: NSObject, NSWindowDelegate {
    static let shared = HotKeyRecorder()

    var onCapture: ((UInt32, UInt32, String) -> Void)?
    /// Called whenever the recorder window closes, captured or cancelled.
    var onClose: (() -> Void)?

    private var window: NSWindow?
    private var monitor: Any?

    func beginCapture() {
        if window == nil { buildWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        installMonitor()
    }

    private func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 130),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "Change Dictation Hotkey"
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.delegate = self

        let label = NSTextField(wrappingLabelWithString:
            "Press the new hotkey now.\n\nInclude at least one modifier (⌘ ⌥ ⌃ ⇧) or use an F-key.\nPress Esc to cancel.")
        label.alignment = .center
        label.frame = NSRect(x: 20, y: 20, width: 340, height: 90)
        w.contentView?.addSubview(label)
        window = w
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
            return nil // swallow the keystroke
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(event: NSEvent) {
        guard !event.isARepeat else { return }
        if event.keyCode == 53 { // Esc cancels
            window?.close()
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }

        // Bare keys would fire while typing; require a modifier unless F-key.
        guard carbon != 0 || Self.functionKeyNames[event.keyCode] != nil else {
            NSSound(named: "Basso")?.play()
            return
        }

        let display = Self.displayString(carbonModifiers: carbon, keyCode: event.keyCode,
                                         fallbackCharacters: event.charactersIgnoringModifiers)
        onCapture?(UInt32(event.keyCode), carbon, display)
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        removeMonitor()
        onClose?()
    }

    // MARK: - Display names

    private static let functionKeyNames: [UInt16: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19",
    ]

    private static let specialKeyNames: [UInt16: String] = [
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End",
        116: "PgUp", 121: "PgDn",
    ]

    static func displayString(carbonModifiers: UInt32, keyCode: UInt16, fallbackCharacters: String?) -> String {
        var parts = ""
        if carbonModifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { parts += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
        let key = functionKeyNames[keyCode]
            ?? specialKeyNames[keyCode]
            ?? (fallbackCharacters ?? "?").uppercased()
        return parts + key
    }
}
