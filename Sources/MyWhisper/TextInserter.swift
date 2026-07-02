import AppKit
import ApplicationServices

enum TextInserter {
    /// Copies text to the pasteboard and, when Accessibility is granted,
    /// pastes it into the frontmost app. Returns true if a paste was sent.
    @discardableResult
    static func insert(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard AXIsProcessTrusted() else { return false }
        sendCmdV()

        // Give the target app a moment to read the pasteboard, then restore
        // whatever the user had copied before dictating.
        if let previous {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if pasteboard.string(forType: .string) == text {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
        return true
    }

    static func promptForAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Executes a recognized voice command in the frontmost app via synthetic
    /// key events. Returns false when Accessibility isn't granted.
    @discardableResult
    static func perform(_ command: VoiceCommand) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        switch command {
        case .undoLastDictation:
            sendKey(6, flags: .maskCommand) // kVK_ANSI_Z
        case .newLine:
            sendKey(36, flags: []) // kVK_Return
        case .newParagraph:
            sendKey(36, flags: [])
            sendKey(36, flags: [])
        }
        return true
    }

    private static func sendCmdV() {
        sendKey(9, flags: .maskCommand) // kVK_ANSI_V
    }

    private static func sendKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
