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
    /// `maxEntries` by dropping the oldest entries first. Returns false
    /// (and logs) if the write failed; callers may ignore the result.
    @discardableResult
    func append(text: String, language: String) -> Bool {
        var entries = load()
        entries.append(Entry(date: Date(), text: text, language: language))
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
        return persist(entries)
    }

    /// Empties the history file.
    @discardableResult
    func clear() -> Bool {
        persist([])
    }

    /// Writes entries as owner-only-readable JSON (0600), since history.json
    /// holds cleartext dictation. Returns false and logs a diagnostic on
    /// failure instead of failing silently.
    @discardableResult
    private func persist(_ entries: [Entry]) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            return true
        } catch {
            NSLog("MyWhisper: failed to save history: %@", error.localizedDescription)
            return false
        }
    }
}
