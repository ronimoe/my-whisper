import AppKit
import ApplicationServices

/// Captures frontmost-app and selected-text context at dictation start so
/// AI-mode prompts can reference them via {app} / {selection} placeholders.
enum ModeContext {
    struct Captured {
        let appName: String?
        let selection: String?
    }

    private static let selectionCharacterLimit = 2000

    /// Replaces every "{app}" and "{selection}" occurrence in `prompt` with
    /// the given values (empty string when nil). Prompts without either
    /// placeholder are returned unchanged.
    static func substitute(prompt: String, appName: String?, selection: String?) -> String {
        prompt
            .replacingOccurrences(of: "{app}", with: appName ?? "")
            .replacingOccurrences(of: "{selection}", with: selection ?? "")
    }

    /// OS-bound capture of the frontmost app's name and the current
    /// Accessibility-API text selection. Not unit tested.
    static func capture() -> Captured {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName
        return Captured(appName: appName, selection: captureSelection())
    }

    private static func captureSelection() -> String? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemWide,
                                                           kAXFocusedUIElementAttribute as CFString,
                                                           &focusedElementRef)
        guard focusedResult == .success, let focusedElementRef,
              CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID() else { return nil }
        let focusedElement = focusedElementRef as! AXUIElement // swiftlint:disable:this force_cast

        var selectedTextRef: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(focusedElement,
                                                            kAXSelectedTextAttribute as CFString,
                                                            &selectedTextRef)
        guard selectedResult == .success, let text = selectedTextRef as? String else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count > selectionCharacterLimit {
            return String(trimmed.prefix(selectionCharacterLimit))
        }
        return trimmed
    }
}
