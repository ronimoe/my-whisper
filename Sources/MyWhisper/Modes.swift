import Foundation

/// A named post-processing transform applied to dictated text via a local
/// Ollama model. `model` overrides `Settings.shared.ollamaModel` when set.
struct Mode: Codable, Equatable {
    let name: String
    let prompt: String
    let model: String?
}

/// User-editable list of AI modes, loaded fresh from `modes.json` on each
/// use so edits apply immediately (mirrors Lexicon's load(from:) pattern).
struct ModeStore {
    static var fileURL: URL {
        Settings.appSupportDir.appendingPathComponent("modes.json")
    }

    static func load() -> [Mode] {
        load(from: fileURL)
    }

    static func load(from url: URL) -> [Mode] {
        guard let data = try? Data(contentsOf: url),
              let modes = try? JSONDecoder().decode([Mode].self, from: data) else {
            return []
        }
        return modes
    }

    static let defaultModes: [Mode] = [
        Mode(name: "Email",
             prompt: "Rewrite the dictated text as a clear, polite email body. "
                 + "Keep the language of the input. Output only the rewritten text.",
             model: nil),
        Mode(name: "Message",
             prompt: "Rewrite the dictated text as a short, casual chat message. "
                 + "Keep the language of the input. Output only the rewritten text.",
             model: nil),
        Mode(name: "Bullet Notes",
             prompt: "Rewrite the dictated text as concise bullet notes. "
                 + "Keep the language of the input. Output only the bullets.",
             model: nil),
    ]

    static func ensureFileExists(at url: URL = fileURL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(defaultModes) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Minimal client for a local Ollama server's chat completion endpoint.
enum Ollama {
    struct ResponseError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func chatRequest(baseURL: URL, model: String, systemPrompt: String,
                             userText: String) -> URLRequest {
        let url = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userText],
            ],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private struct ChatResponse: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message?
        let error: String?
    }

    static func parseChatResponse(_ data: Data) throws -> String {
        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw ResponseError(message: "Unrecognized response from Ollama")
        }
        if let error = decoded.error {
            throw ResponseError(message: error)
        }
        guard let content = decoded.message?.content else {
            throw ResponseError(message: "Unrecognized response from Ollama")
        }
        return content
    }

    private struct VersionResponse: Decodable {
        let version: String
    }

    /// Returns the version string only when `data` is a valid Ollama
    /// `/api/version` payload — a JSON object with a String `version` field.
    /// Returns nil for anything else (empty, non-JSON, HTML, `{"error":…}`,
    /// `{}`, or a non-string `version`). Pure and deterministic; no network.
    static func parseVersionResponse(_ data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(VersionResponse.self, from: data) else {
            return nil
        }
        return decoded.version
    }

    /// Verifies the endpoint at `baseURL` actually speaks Ollama before we send
    /// it any dictated/selected text: GET `/api/version` must return HTTP 200 AND
    /// a body that decodes as Ollama's `{"version": String}` shape. Any other
    /// responder on the port (or a network error) yields false.
    static func probeIsOllama(baseURL: URL) async -> Bool {
        let url = baseURL.appendingPathComponent("api/version")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return false
        }
        return parseVersionResponse(data) != nil
    }

    private struct TagsResponse: Decodable {
        struct ModelEntry: Decodable {
            let name: String
        }
        let models: [ModelEntry]
    }

    /// Parses a GET `/api/tags` payload (`{"models":[{"name":"llama3.2:latest",…},…]}`)
    /// into an array of model name strings. Returns `[]` for a genuinely empty
    /// list, and nil for anything that isn't that shape (missing "models",
    /// garbage, HTML). Pure and deterministic; no network.
    static func parseTagsResponse(_ data: Data) -> [String]? {
        guard let decoded = try? JSONDecoder().decode(TagsResponse.self, from: data) else {
            return nil
        }
        return decoded.models.map { $0.name }
    }

    /// Lists locally-available Ollama model names via GET `/api/tags`. nil on
    /// any failure (non-200, network error, unparseable body) — this is a
    /// best-effort UI probe, not a source of truth callers should throw on.
    /// Short timeout since this only ever targets localhost.
    static func listModelNames(baseURL: URL) async -> [String]? {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }
        return parseTagsResponse(data)
    }

    private struct PullProgressLine: Decodable {
        let status: String?
        let completed: Int64?
        let total: Int64?
        let error: String?
    }

    /// Parses ONE streamed JSON line from POST `/api/pull`. A normal line
    /// looks like `{"status":"pulling …","completed":123,"total":456}`
    /// (completed/total are often absent); the terminal line is
    /// `{"status":"success"}`. An error line, `{"error":"…"}`, is NOT
    /// discarded as nil — it's surfaced as a status of "error: <message>" so
    /// the caller (pullModel) can detect it and throw with the message.
    /// Returns nil only for lines that don't decode as any of these shapes.
    static func parsePullProgressLine(_ line: Data) -> (status: String, completed: Int64?, total: Int64?)? {
        guard let decoded = try? JSONDecoder().decode(PullProgressLine.self, from: line) else {
            return nil
        }
        if let error = decoded.error {
            return ("error: \(error)", nil, nil)
        }
        guard let status = decoded.status else {
            return nil
        }
        return (status, decoded.completed, decoded.total)
    }

    /// Streams a model pull from local Ollama, delivering progress on the
    /// main actor as each line arrives. Verifies the endpoint's identity
    /// first (same refusal as `rewrite`) so we never send a pull request to
    /// something squatting the port. Throws on a non-200 response, an
    /// "error: …" line from the stream, or a transport failure; returns
    /// normally once the stream ends after a "success" status.
    static func pullModel(name: String, baseURL: URL,
                           progress: @escaping @Sendable (String, Int64?, Int64?) -> Void) async throws {
        guard await probeIsOllama(baseURL: baseURL) else {
            throw ResponseError(
                message: "AI-mode endpoint at \(baseURL.absoluteString) did not identify as Ollama; "
                    + "refusing to send text")
        }

        let url = baseURL.appendingPathComponent("api/pull")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["name": name, "stream": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (byteStream, response) = try await URLSession.shared.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ResponseError(message: "Ollama returned an error while pulling \(name)")
        }

        for try await line in byteStream.lines {
            guard let parsed = parsePullProgressLine(Data(line.utf8)) else { continue }
            if parsed.status.hasPrefix("error:") {
                throw ResponseError(message: String(parsed.status.dropFirst("error: ".count)))
            }
            let status = parsed.status
            let completed = parsed.completed
            let total = parsed.total
            await MainActor.run {
                progress(status, completed, total)
            }
        }
    }

    static func rewrite(text: String, mode: Mode, defaultModel: String,
                         baseURL: URL) async throws -> String {
        // Verify identity BEFORE posting any text: if some other process is
        // squatting the Ollama port, refuse rather than leak the transcript
        // (and any {selection}) to it. Callers catch this and fall back to
        // pasting the raw transcript.
        guard await probeIsOllama(baseURL: baseURL) else {
            throw ResponseError(
                message: "AI-mode endpoint at \(baseURL.absoluteString) did not identify as Ollama; "
                    + "refusing to send text")
        }

        var request = chatRequest(baseURL: baseURL, model: mode.model ?? defaultModel,
                                  systemPrompt: mode.prompt, userText: text)
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)
        let content = try parseChatResponse(data)
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ResponseError(message: "Ollama returned an empty result")
        }
        return trimmed
    }
}
