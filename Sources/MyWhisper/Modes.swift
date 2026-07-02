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

    static func rewrite(text: String, mode: Mode, defaultModel: String,
                         baseURL: URL) async throws -> String {
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
