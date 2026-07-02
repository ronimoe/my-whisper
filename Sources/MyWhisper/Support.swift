import AppKit
import UserNotifications

enum Postprocess {
    /// Cleans whisper output for insertion: collapses whitespace and drops
    /// noise-only annotations such as [BLANK_AUDIO] or (music).
    static func clean(_ raw: String) -> String {
        // Segments arrive newline-separated and may split mid-word; they carry
        // their own leading spaces, so newlines are deleted, not spaced.
        let collapsed = raw
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.range(of: "^[\\[\\(][^\\]\\)]*[\\]\\)]$", options: .regularExpression) != nil {
            return ""
        }
        return collapsed
    }
}

enum Notifier {
    static func show(title: String, body: String) {
        // UNUserNotificationCenter requires a real .app bundle; fall back to
        // logging when running as a bare executable during development.
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            NSLog("MyWhisper: %@ — %@", title, body)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                             content: content, trigger: nil))
        }
    }
}
