import Foundation

/// User-editable vocabulary hints and text replacements, loaded fresh from
/// `replacements.json` on each transcription so edits apply immediately.
struct Lexicon {
    struct Replacement: Codable {
        let find: String
        let replace: String
    }

    private struct File: Codable {
        let vocabulary: [String]?
        let replacements: [Replacement]?
    }

    private let vocabulary: [String]
    private let replacements: [Replacement]

    static var fileURL: URL {
        Settings.appSupportDir.appendingPathComponent("replacements.json")
    }

    private init(vocabulary: [String], replacements: [Replacement]) {
        self.vocabulary = vocabulary
        self.replacements = replacements
    }

    /// mtime-based cache for the default production file, so preview ticks
    /// (~1.5s) and finals don't re-read/re-decode replacements.json every call.
    /// `cachedMTime` is nil when the file was missing at cache time; a cache
    /// entry always exists once `load()` has run once (so repeated misses
    /// just compare nil == nil instead of re-attempting a decode).
    private static var cachedLexicon: Lexicon?
    private static var cachedMTime: Date?
    private static var hasCached = false
    private static let cacheLock = NSLock()

    static func load() -> Lexicon {
        let url = fileURL
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let currentMTime = attributes?[.modificationDate] as? Date

        cacheLock.lock()
        if hasCached, cachedMTime == currentMTime, let cached = cachedLexicon {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let fresh = load(from: url)
        cacheLock.lock()
        cachedLexicon = fresh
        cachedMTime = currentMTime
        hasCached = true
        cacheLock.unlock()
        return fresh
    }

    static func load(from url: URL) -> Lexicon {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            return Lexicon(vocabulary: [], replacements: [])
        }
        return Lexicon(vocabulary: file.vocabulary ?? [], replacements: file.replacements ?? [])
    }

    /// Vocabulary joined for use as a whisper `prompt` hint, nil when empty.
    var vocabularyPrompt: String? {
        vocabulary.isEmpty ? nil : vocabulary.joined(separator: ", ")
    }

    func apply(to text: String) -> String {
        var result = text
        for replacement in replacements {
            result = result.replacingOccurrences(of: replacement.find, with: replacement.replace,
                                                  options: [.caseInsensitive])
        }
        return result
    }

    static func ensureFileExists(at url: URL = fileURL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let example = """
        {
          "vocabulary": ["MyWhisper", "whisper.cpp"],
          "replacements": [{"find": "my whisper", "replace": "MyWhisper"}]
        }
        """
        try? example.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Appends a user-derived find→replace rule to `url`'s replacements,
    /// preserving existing vocabulary and rules. A rule with the same find
    /// (case-insensitive) is updated in place rather than duplicated. Missing
    /// or malformed files are (re)created with just this one rule — data that
    /// couldn't be read is treated as absent, not as a reason to drop the
    /// user's correction. Writes pretty-printed JSON with 0600 perms, matching
    /// HistoryStore's pattern. Returns false (and logs) on write failure; the
    /// mtime cache used by `load()` invalidates automatically since the
    /// file's modification date changes on write.
    @discardableResult
    static func appendReplacement(find: String, replace: String, to url: URL = fileURL) -> Bool {
        var vocabulary: [String] = []
        var replacements: [Replacement] = []
        if let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(File.self, from: data) {
            vocabulary = file.vocabulary ?? []
            replacements = file.replacements ?? []
        }

        if let index = replacements.firstIndex(where: { $0.find.caseInsensitiveCompare(find) == .orderedSame }) {
            replacements[index] = Replacement(find: find, replace: replace)
        } else {
            replacements.append(Replacement(find: find, replace: replace))
        }

        let file = File(vocabulary: vocabulary, replacements: replacements)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(file)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch {
            NSLog("MyWhisper: failed to save replacement: %@", error.localizedDescription)
            return false
        }
    }
}
