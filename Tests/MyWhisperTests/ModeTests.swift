import XCTest
@testable import MyWhisper

final class ModeStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModeStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try super.tearDownWithError()
    }

    private func write(_ contents: String, name: String = "modes.json") -> URL {
        let url = tempDir.appendingPathComponent(name)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testValidFileDecodesNameAndPromptAndModel() {
        let url = write("""
        [
          {"name": "Email", "prompt": "rewrite as email", "model": "llama3.2"}
        ]
        """)
        let modes = ModeStore.load(from: url)
        XCTAssertEqual(modes.count, 1)
        XCTAssertEqual(modes[0].name, "Email")
        XCTAssertEqual(modes[0].prompt, "rewrite as email")
        XCTAssertEqual(modes[0].model, "llama3.2")
    }

    func testModelAbsentDecodesToNil() {
        let url = write("""
        [
          {"name": "Message", "prompt": "rewrite as chat message"}
        ]
        """)
        let modes = ModeStore.load(from: url)
        XCTAssertEqual(modes.count, 1)
        XCTAssertEqual(modes[0].name, "Message")
        XCTAssertNil(modes[0].model)
    }

    func testMissingFileReturnsEmptyArray() {
        let url = tempDir.appendingPathComponent("does-not-exist.json")
        XCTAssertEqual(ModeStore.load(from: url), [])
    }

    func testMalformedJSONReturnsEmptyArray() {
        let url = write("{ this is not valid json ")
        XCTAssertEqual(ModeStore.load(from: url), [])
    }

    func testEnsureFileExistsWritesDefaultModesInOrder() {
        let url = tempDir.appendingPathComponent("modes.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        ModeStore.ensureFileExists(at: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let modes = ModeStore.load(from: url)
        XCTAssertEqual(modes.map(\.name), ["Email", "Message", "Bullet Notes"])
    }

    func testEnsureFileExistsDoesNotOverwriteExistingFile() {
        let url = write("""
        [
          {"name": "Custom", "prompt": "custom prompt"}
        ]
        """)
        ModeStore.ensureFileExists(at: url)
        let modes = ModeStore.load(from: url)
        XCTAssertEqual(modes.map(\.name), ["Custom"])
    }
}

final class OllamaRequestTests: XCTestCase {
    private let baseURL = URL(string: "http://127.0.0.1:11434")!

    func testChatRequestTargetsChatEndpointWithPOST() {
        let request = Ollama.chatRequest(baseURL: baseURL, model: "llama3.2",
                                         systemPrompt: "system", userText: "user")
        XCTAssertEqual(request.url, baseURL.appendingPathComponent("api/chat"))
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testChatRequestSetsJSONContentType() {
        let request = Ollama.chatRequest(baseURL: baseURL, model: "llama3.2",
                                         systemPrompt: "system", userText: "user")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testChatRequestBodyContainsModelStreamFalseAndMessages() throws {
        let request = Ollama.chatRequest(baseURL: baseURL, model: "llama3.2",
                                         systemPrompt: "You are a helpful assistant.",
                                         userText: "hello there")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["model"] as? String, "llama3.2")
        XCTAssertEqual(json["stream"] as? Bool, false)

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "You are a helpful assistant.")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
        XCTAssertEqual(messages[1]["content"] as? String, "hello there")
    }
}

final class OllamaParseChatResponseTests: XCTestCase {
    func testValidResponseReturnsContent() throws {
        let data = Data("""
        {"message": {"role": "assistant", "content": "Rewritten text."}}
        """.utf8)
        let content = try Ollama.parseChatResponse(data)
        XCTAssertEqual(content, "Rewritten text.")
    }

    func testErrorFieldThrowsWithMessage() {
        let data = Data("""
        {"error": "model not found"}
        """.utf8)
        XCTAssertThrowsError(try Ollama.parseChatResponse(data)) { error in
            let description = String(describing: error)
            XCTAssertTrue(description.contains("model not found")
                || (error as? LocalizedError)?.errorDescription?.contains("model not found") == true)
        }
    }

    func testGarbageDataThrows() {
        let data = Data("not json at all".utf8)
        XCTAssertThrowsError(try Ollama.parseChatResponse(data))
    }

    func testEmptyDataThrows() {
        let data = Data()
        XCTAssertThrowsError(try Ollama.parseChatResponse(data))
    }

    func testUnrecognizedShapeThrows() {
        let data = Data("""
        {"unexpected": "shape"}
        """.utf8)
        XCTAssertThrowsError(try Ollama.parseChatResponse(data))
    }
}
