import Foundation

/// User-editable vocabulary hints and text replacements, loaded fresh from
/// `replacements.json` on each transcription so edits apply immediately.
struct Lexicon {
    struct Replacement: Decodable {
        let find: String
        let replace: String
    }

    private struct File: Decodable {
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

    static func load() -> Lexicon {
        guard let data = try? Data(contentsOf: fileURL),
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

    static func ensureFileExists() {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let example = """
        {
          "vocabulary": ["MyWhisper", "whisper.cpp"],
          "replacements": [{"find": "my whisper", "replace": "MyWhisper"}]
        }
        """
        try? example.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
