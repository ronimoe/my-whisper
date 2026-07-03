import Foundation

/// A single per-app override rule. Matched against the frontmost app at
/// dictation start; any non-nil field overrides the corresponding base
/// setting for that dictation only.
struct AppProfile: Codable, Equatable {
    /// Matches the frontmost app's localizedName, case-insensitive exact match.
    let app: String?
    /// Matches the frontmost app's bundle identifier, case-insensitive exact
    /// match; takes precedence over `app` matching in the same rule (either
    /// field matching is sufficient — see `AppProfileStore.match`).
    let bundleId: String?
    /// Overrides Settings.language for this dictation ("id", "auto", "mixed", …).
    let language: String?
    /// Overrides currentModeName ("Raw" is a valid override).
    let mode: String?
    let spokenPunctuation: Bool?
    let translate: Bool?
}

/// User-editable list of per-app dictation profiles, loaded fresh from
/// `profiles.json` on each dictation so edits apply immediately (mirrors
/// Lexicon/ModeStore's load(from:) pattern).
enum AppProfileStore {
    static var fileURL: URL {
        Settings.appSupportDir.appendingPathComponent("profiles.json")
    }

    static func load() -> [AppProfile] {
        load(from: fileURL)
    }

    static func load(from url: URL) -> [AppProfile] {
        guard let data = try? Data(contentsOf: url),
              let profiles = try? JSONDecoder().decode([AppProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    static func ensureFileExists(at url: URL = fileURL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let example = """
        [
          {"app": "Slack", "mode": "Message"},
          {"bundleId": "com.apple.mail", "mode": "Email"},
          {"app": "Terminal", "spokenPunctuation": false}
        ]
        """
        try? example.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Returns the first rule (in array order) whose `bundleId` matches the
    /// given `bundleId` (case-insensitive), OR whose `app` matches `appName`
    /// (case-insensitive) — a rule matches if EITHER of its set fields
    /// matches. nil inputs never match a non-nil pattern.
    static func match(appName: String?, bundleId: String?, in profiles: [AppProfile]) -> AppProfile? {
        profiles.first { profile in
            if let ruleBundleId = profile.bundleId, let bundleId,
               ruleBundleId.caseInsensitiveCompare(bundleId) == .orderedSame {
                return true
            }
            if let ruleApp = profile.app, let appName,
               ruleApp.caseInsensitiveCompare(appName) == .orderedSame {
                return true
            }
            return false
        }
    }
}

/// Pure merge of base dictation settings with an optional matched profile:
/// profile fields override the base value only when non-nil.
struct EffectiveDictation {
    let language: String
    let modeName: String
    let spokenPunctuation: Bool
    let translate: Bool

    static func resolve(language: String, modeName: String, spokenPunctuation: Bool,
                        translate: Bool, profile: AppProfile?) -> EffectiveDictation {
        EffectiveDictation(
            language: profile?.language ?? language,
            modeName: profile?.mode ?? modeName,
            spokenPunctuation: profile?.spokenPunctuation ?? spokenPunctuation,
            translate: profile?.translate ?? translate)
    }
}
