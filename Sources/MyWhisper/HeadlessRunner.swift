import Foundation

/// CLI mode (`MyWhisper --transcribe file.wav`): runs the full pipeline —
/// spawn whisper-server, wait for the model, transcribe, print — without the
/// GUI. Used for testing and scripting.
final class HeadlessRunner {
    private final class ResultBox: @unchecked Sendable {
        var value: Result<String, Error>?
    }

    func run(wavPath: String, language: String, translate: Bool = false, modeName: String = "Raw") -> Int32 {
        let errOut = FileHandle.standardError
        func fail(_ message: String) -> Int32 {
            errOut.write(Data("error: \(message)\n".utf8))
            return 1
        }

        guard FileManager.default.fileExists(atPath: wavPath) else {
            return fail("file not found: \(wavPath)")
        }
        guard let binary = WhisperServerManager.locateServerBinary() else {
            return fail("whisper-server not found (brew install whisper-cpp, or make deps)")
        }
        guard let model = Settings.shared.resolveModelURL() else {
            return fail("no model in \(Settings.modelsDir.path) — run: make model")
        }
        errOut.write(Data("using model: \(model.lastPathComponent), language: \(language)\n".utf8))

        let server = WhisperServerManager(serverBinary: binary, modelURL: model,
                                          port: Settings.shared.serverPort)
        var startupError: String?
        let ready = DispatchSemaphore(value: 0)
        server.onStateChange = { state in
            switch state {
            case .ready: ready.signal()
            case .failed(let message):
                startupError = message
                ready.signal()
            case .starting, .stopped: break
            }
        }
        server.start()
        ready.wait()
        if let startupError { return fail(startupError) }
        defer { server.stop() }

        guard let wav = FileManager.default.contents(atPath: wavPath) else {
            return fail("could not read \(wavPath)")
        }

        let lexicon = Lexicon.load()
        let box = ResultBox()
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                let raw = try await server.transcribe(wavData: wav, language: language,
                                                       translate: translate,
                                                       prompt: lexicon.vocabularyPrompt)
                let candidate = lexicon.apply(to: Postprocess.clean(raw))
                var text = candidate
                if modeName != "Raw", let mode = ModeStore.load().first(where: { $0.name == modeName }) {
                    do {
                        text = try await Ollama.rewrite(text: candidate, mode: mode,
                                                        defaultModel: Settings.shared.ollamaModel,
                                                        baseURL: URL(string: "http://127.0.0.1:11434")!)
                    } catch {
                        errOut.write(Data("note: AI mode failed, printing raw text — \(error.localizedDescription)\n".utf8))
                        text = candidate
                    }
                }
                box.value = .success(text)
            }
            catch { box.value = .failure(error) }
            done.signal()
        }
        done.wait()

        switch box.value {
        case .success(let text):
            print(text)
            return 0
        case .failure(let error):
            return fail(error.localizedDescription)
        case nil:
            return fail("no result")
        }
    }
}
