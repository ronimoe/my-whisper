import Foundation

enum VoiceCommand: Equatable {
    case undoLastDictation
    case newLine
    case newParagraph
}

enum VoiceCommands {
    private static let phrases: [String: VoiceCommand] = [
        "scratch that": .undoLastDictation,
        "undo that": .undoLastDictation,
        "batalkan": .undoLastDictation,
        "batalkan itu": .undoLastDictation,
        "new line": .newLine,
        "baris baru": .newLine,
        "new paragraph": .newParagraph,
        "paragraf baru": .newParagraph
    ]

    /// Matches text that, once normalized, is *entirely* a known spoken
    /// command — no partial or inline matches (e.g. "please undo that" is nil).
    static func match(_ text: String) -> VoiceCommand? {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?…"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return phrases[normalized]
    }
}
