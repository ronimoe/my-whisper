import Foundation

/// A single past transcription.
struct Entry: Codable, Equatable {
    let date: Date
    let text: String
    let language: String
}

/// Persists transcription history as pretty-printed JSON on disk. Callers
/// use it synchronously from the main thread.
final class HistoryStore {
    static let shared = HistoryStore(fileURL: Settings.appSupportDir.appendingPathComponent("history.json"))

    private static let maxEntries = 200

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Loads all entries, oldest first (newest last). Returns an empty array
    /// when the file is missing or corrupt.
    func load() -> [Entry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entries = try? decoder.decode([Entry].self, from: data) else { return [] }
        return entries
    }

    /// Appends a new entry with the current date, capping storage at
    /// `maxEntries` by dropping the oldest entries first.
    func append(text: String, language: String) {
        var entries = load()
        entries.append(Entry(date: Date(), text: text, language: language))
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
        persist(entries)
    }

    /// Empties the history file.
    func clear() {
        persist([])
    }

    private func persist(_ entries: [Entry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
