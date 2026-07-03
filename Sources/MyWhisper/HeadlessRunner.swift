import Foundation

/// CLI mode (`MyWhisper --transcribe file.wav`): runs the full pipeline —
/// spawn whisper-server, wait for the model, transcribe, print — without the
/// GUI. Used for testing and scripting.
final class HeadlessRunner {
    private final class ResultBox: @unchecked Sendable {
        var value: Result<String, Error>?
    }

    func run(wavPath: String, language: String, translate: Bool = false, modeName: String = "Raw",
             engineOverride: String? = nil) -> Int32 {
        let errOut = FileHandle.standardError
        func fail(_ message: String) -> Int32 {
            errOut.write(Data("error: \(message)\n".utf8))
            return 1
        }

        guard FileManager.default.fileExists(atPath: wavPath) else {
            return fail("file not found: \(wavPath)")
        }
        guard let model = Settings.shared.resolveModelURL() else {
            return fail("no model in \(Settings.modelsDir.path) — run: make model")
        }

        let engineKind = engineOverride ?? Settings.shared.engine
        let engine: any TranscriptionEngine
        if engineKind == "inprocess" {
            engine = WhisperEngine(modelURL: model)
        } else {
            guard let binary = WhisperServerManager.locateServerBinary() else {
                return fail("whisper-server not found (brew install whisper-cpp, or make deps)")
            }
            engine = WhisperServerManager(serverBinary: binary, modelURL: model,
                                          port: Settings.shared.serverPort)
        }
        errOut.write(Data("using model: \(model.lastPathComponent), language: \(language), engine: \(engineKind)\n".utf8))

        var startupError: String?
        let ready = DispatchSemaphore(value: 0)
        engine.onStateChange = { state in
            switch state {
            case .ready: ready.signal()
            case .failed(let message):
                startupError = message
                ready.signal()
            case .starting, .stopped: break
            }
        }
        engine.start()
        ready.wait()
        if let startupError { return fail(startupError) }
        // stop() frees the context asynchronously on the engine's serial queue;
        // the process exit()s right after run() returns, so drain that queue for
        // the in-process engine to let ggml release its Metal resources before
        // its static teardown asserts on them.
        defer {
            engine.stop()
            (engine as? WhisperEngine)?.waitForPendingWork()
        }

        guard let wav = FileManager.default.contents(atPath: wavPath) else {
            return fail("could not read \(wavPath)")
        }
        let samples: [Float]
        do {
            samples = try WavReader.samples(fromWavData: wav)
        } catch {
            return fail(error.localizedDescription)
        }

        let lexicon = Lexicon.load()
        let pipeline = DictationPipeline(engine: engine)
        let box = ResultBox()
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                // The CLI prints text rather than executing key commands, so
                // voice-command interception is disabled: a transcript that is
                // itself a command word prints literally, matching prior behavior.
                let result = try await pipeline.run(
                    samples: samples, language: language,
                    mixedPrimary: Settings.shared.mixedPrimary, translate: translate,
                    lexicon: lexicon, voiceCommandsEnabled: false,
                    spokenPunctuationEnabled: Settings.shared.spokenPunctuationEnabled,
                    modeName: modeName, modes: ModeStore.load(), context: nil,
                    ollamaModel: Settings.shared.ollamaModel,
                    ollamaBaseURL: Settings.shared.ollamaBaseURL)
                if let aiFailure = result.aiFailure {
                    errOut.write(Data("note: AI mode failed, printing raw text — \(aiFailure.localizedDescription)\n".utf8))
                }
                switch result.outcome {
                case .text(let text): box.value = .success(text)
                case .empty: box.value = .success("")
                case .command: box.value = .success("")
                }
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
