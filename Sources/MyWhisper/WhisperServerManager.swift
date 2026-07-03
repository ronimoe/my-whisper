import Foundation

/// Owns a local whisper-server process (whisper.cpp) and talks to it over
/// localhost HTTP. The model stays loaded in memory between dictations.
final class WhisperServerManager: TranscriptionEngine {
    typealias State = EngineState

    /// Guards `_state` so the enum-with-String payload is never read or written
    /// concurrently by the main thread, the poll queue, and the Process
    /// termination thread. See `state`/`setState`/`transition` below.
    private let stateLock = NSLock()
    private var _state: State = .stopped
    var state: State {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _state
    }
    var onStateChange: ((State) -> Void)?

    /// Single synchronized writer: commits `newValue` to `_state` under the lock,
    /// captures the callback, then fires `onStateChange` OUTSIDE the lock so a
    /// callback that reads `state` cannot deadlock and callbacks are never
    /// delivered while the lock is held.
    private func setState(_ newValue: State) {
        stateLock.lock()
        _state = newValue
        let callback = onStateChange
        stateLock.unlock()
        callback?(newValue)
    }

    /// Compare-and-set: atomically applies `newValue` only if `predicate` holds
    /// for the current state, evaluated under the same lock as the write. Returns
    /// whether the transition happened. `onStateChange` fires outside the lock.
    /// A late writer (e.g. the termination handler) can therefore not resurrect a
    /// state that `stop()` already moved to `.stopped`.
    @discardableResult
    func transition(to newValue: State, onlyIf predicate: (State) -> Bool) -> Bool {
        stateLock.lock()
        guard predicate(_state) else {
            stateLock.unlock()
            return false
        }
        _state = newValue
        let callback = onStateChange
        stateLock.unlock()
        callback?(newValue)
        return true
    }

    let modelURL: URL
    private let serverBinary: URL
    private let port: Int
    private var process: Process?
    private let logURL = Settings.appSupportDir.appendingPathComponent("whisper-server.log")

    init(serverBinary: URL, modelURL: URL, port: Int) {
        self.serverBinary = serverBinary
        self.modelURL = modelURL
        self.port = port
    }

    static func locateServerBinary() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let override = ProcessInfo.processInfo.environment["MYWHISPER_SERVER"] {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("bin/whisper-server"))
        }
        if let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            // repo layout: .build/<config>/MyWhisper → vendor/whisper.cpp/build/bin
            candidates.append(executable.deletingLastPathComponent()
                .appendingPathComponent("../../vendor/whisper.cpp/build/bin/whisper-server")
                .standardized)
        }
        candidates.append(URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("vendor/whisper.cpp/build/bin/whisper-server"))
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/whisper-server"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/whisper-server"))
        return candidates.first { fm.isExecutableFile(atPath: $0.path) }
    }

    func start() {
        guard process == nil else { return }
        setState(.starting)

        let proc = Process()
        proc.executableURL = serverBinary
        proc.arguments = [
            "--model", modelURL.path,
            "--host", "127.0.0.1",
            "--port", String(port),
            "--threads", String(max(4, ProcessInfo.processInfo.activeProcessorCount - 2)),
        ]
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        if let log = try? FileHandle(forWritingTo: logURL) {
            proc.standardOutput = log
            proc.standardError = log
        }
        proc.terminationHandler = { [weak self] finished in
            guard let self else { return }
            // Only report a crash if stop() hasn't already claimed teardown; the
            // check + write are atomic under stateLock, so a stop() racing here
            // cannot be overwritten with .failed.
            let message =
                "whisper-server exited (code \(finished.terminationStatus)). \(self.logTail())"
            self.transition(to: .failed(message)) { current in
                if case .stopped = current { return false }
                return true
            }
        }
        do {
            try proc.run()
        } catch {
            setState(.failed("Could not launch whisper-server: \(error.localizedDescription)"))
            return
        }
        process = proc
        pollUntilReady()
    }

    func stop() {
        // Authoritative teardown: unconditionally set .stopped under the lock.
        setState(.stopped)
        process?.terminate()
        process = nil
    }

    private func pollUntilReady() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let deadline = Date().addingTimeInterval(300)
            while Date() < deadline {
                guard let self else { return }
                guard case .starting = self.state else { return }
                if self.ping() {
                    // Only promote to .ready if still .starting — a stop() or a
                    // termination-handler .failed that landed since the ping must
                    // win. The check + write are atomic under stateLock.
                    self.transition(to: .ready) { current in
                        if case .starting = current { return true }
                        return false
                    }
                    return
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
            guard let self else { return }
            self.transition(to: .failed("Timed out waiting for whisper-server to load the model")) {
                current in
                if case .starting = current { return true }
                return false
            }
        }
    }

    private func ping() -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)/") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        var reachable = false
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, response, _ in
            reachable = response is HTTPURLResponse
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return reachable
    }

    private func logTail(lines: Int = 5) -> String {
        guard let content = try? String(contentsOf: logURL, encoding: .utf8) else { return "" }
        return content.split(separator: "\n").suffix(lines).joined(separator: "\n")
    }

    struct TranscriptionError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// TranscriptionEngine conformance: encode the samples to a WAV in memory,
    /// then hand off to the HTTP path the server understands.
    func transcribe(samples: [Float], language: String, translate: Bool,
                    prompt: String?) async throws -> String {
        guard !samples.isEmpty else { return "" }
        let wav = WavWriter.data(fromSamples: samples)
        return try await transcribe(wavData: wav, language: language, translate: translate,
                                    prompt: prompt)
    }

    func transcribe(wavData: Data, language: String, translate: Bool = false,
                     prompt: String? = nil) async throws -> String {
        guard let url = URL(string: "http://127.0.0.1:\(port)/inference") else {
            throw TranscriptionError(message: "Bad server URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        let boundary = "mywhisper-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(boundary: boundary, wavData: wavData, language: language,
                                              translate: translate, prompt: prompt)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        struct ServerResponse: Decodable {
            let text: String?
            let error: String?
        }
        let decoded = try? JSONDecoder().decode(ServerResponse.self, from: data)
        if statusCode != 200 || decoded?.error != nil {
            let detail = decoded?.error ?? String(data: data, encoding: .utf8) ?? ""
            throw TranscriptionError(message: "Transcription failed (HTTP \(statusCode)): \(detail)")
        }
        return decoded?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func multipartBody(boundary: String, wavData: Data, language: String,
                               translate: Bool = false, prompt: String? = nil) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        var fields = [("response_format", "json"),
                      ("language", language),
                      ("temperature", "0.0")]
        if translate { fields.append(("translate", "true")) }
        if let prompt, !prompt.isEmpty { fields.append(("prompt", prompt)) }
        for (name, value) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(wavData)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}
