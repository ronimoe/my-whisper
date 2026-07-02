import AppKit
import UserNotifications

enum Postprocess {
    /// Cleans whisper output for insertion: collapses whitespace and drops
    /// noise-only annotations such as [BLANK_AUDIO] or (music).
    static func clean(_ raw: String) -> String {
        let collapsed = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
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
