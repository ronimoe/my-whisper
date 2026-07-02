import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusController = StatusItemController()
    private let hotKeys = HotKeyManager()
    private let recorder = Recorder()
    private var server: WhisperServerManager?
    private var lastPressDate: Date?
    private var pressStartedRecording = false
    private var previewTimer: Timer?
    private var previewScheduler = PartialScheduler()
    private var previewInFlight = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController.onToggleDictation = { [weak self] in self?.toggleDictation() }
        statusController.onSelectLanguage = { code in Settings.shared.language = code }
        statusController.onSelectModel = { [weak self] url in
            Settings.shared.modelPath = url.path
            self?.restartServer()
        }
        statusController.onChangeHotKey = { [weak self] in self?.beginHotKeyCapture() }
        statusController.levelProvider = { [weak self] in self?.recorder.currentLevel ?? 0 }

        hotKeys.onHotKeyDown = { [weak self] in self?.hotKeyDown() }
        hotKeys.onHotKeyUp = { [weak self] in self?.hotKeyUp() }
        hotKeys.register(keyCode: Settings.shared.hotKeyCode,
                         modifiers: Settings.shared.hotKeyModifiers)

        recorder.onAutoStop = { [weak self] in
            guard self?.recorder.isRecording == true else { return }
            self?.finishDictation()
        }

        recorder.requestPermission { granted in
            if !granted {
                Notifier.show(title: "Microphone access needed",
                              body: "Enable it in System Settings → Privacy & Security → Microphone.")
            }
        }
        TextInserter.promptForAccessibilityIfNeeded()
        startServer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    private func startServer() {
        guard let binary = WhisperServerManager.locateServerBinary() else {
            statusController.setStatus(.error("whisper-server not found — brew install whisper-cpp"))
            return
        }
        guard let model = Settings.shared.resolveModelURL() else {
            statusController.setStatus(.error("No model — run: make model"))
            return
        }
        let name = Settings.displayName(forModel: model)
        statusController.setModelName(name)
        statusController.setStatus(.loading("Loading \(name)…"))

        let server = WhisperServerManager(serverBinary: binary, modelURL: model,
                                          port: Settings.shared.serverPort)
        self.server = server
        server.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready: self?.statusController.setStatus(.idle)
                case .failed(let message): self?.statusController.setStatus(.error(message))
                case .starting, .stopped: break
                }
            }
        }
        server.start()
    }

    private func beginHotKeyCapture() {
        // Release the current hotkey so pressing it can be captured as the
        // new combination instead of toggling dictation.
        hotKeys.suspend()
        let recorder = HotKeyRecorder.shared
        recorder.onCapture = { code, modifiers, display in
            Settings.shared.setHotKey(code: code, modifiers: modifiers, display: display)
            Notifier.show(title: "Hotkey changed", body: "Dictation hotkey is now \(display)")
        }
        recorder.onClose = { [weak self] in
            // Re-register whatever is saved — the new combo, or the old one on cancel.
            self?.hotKeys.update(keyCode: Settings.shared.hotKeyCode,
                                 modifiers: Settings.shared.hotKeyModifiers)
        }
        recorder.beginCapture()
    }

    private func restartServer() {
        stopPreviewTimer()
        if recorder.isRecording { _ = recorder.stop() }
        server?.stop()
        server = nil
        startServer()
    }

    // Quick tap toggles recording on/off; press-and-hold records while held
    // and stops on release (only once held past the tap threshold).
    private func hotKeyDown() {
        if recorder.isRecording {
            pressStartedRecording = false
            finishDictation()
        } else {
            pressStartedRecording = true
            lastPressDate = Date()
            beginDictation()
        }
    }

    private func hotKeyUp() {
        guard recorder.isRecording, pressStartedRecording,
              let lastPressDate, Date().timeIntervalSince(lastPressDate) >= 0.35 else { return }
        finishDictation()
    }

    /// Emulates a tap from the status menu: down-only, so a stray key-up
    /// from the physical hotkey never stops a menu-started recording.
    private func toggleDictation() {
        if recorder.isRecording {
            pressStartedRecording = false
            finishDictation()
        } else {
            pressStartedRecording = false
            beginDictation()
        }
    }

    private func beginDictation() {
        guard let server, case .ready = server.state else {
            Notifier.show(title: "Model still loading", body: "Try again in a few seconds.")
            return
        }
        _ = server
        do {
            recorder.autoStopEnabled = Settings.shared.autoStopEnabled
            try recorder.start()
            statusController.setStatus(.recording)
            if Settings.shared.soundCues { NSSound(named: "Pop")?.play() }
            if Settings.shared.livePreviewEnabled {
                startPreviewTimer()
            }
        } catch {
            statusController.setStatus(.error(error.localizedDescription))
        }
    }

    private func startPreviewTimer() {
        previewScheduler.reset()
        previewInFlight = false
        previewTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.previewTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        previewTimer = timer
    }

    private func stopPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = nil
        PreviewHUD.shared.hide()
    }

    private func previewTick() {
        guard recorder.isRecording else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard previewScheduler.shouldFire(now: now, samplesAvailable: recorder.sampleCount,
                                          inFlight: previewInFlight) else { return }
        guard let server else { return }
        previewInFlight = true
        let snapshot = recorder.snapshotSamples(maxSamples: 30 * 16000)
        let language = Settings.shared.language
        let translate = Settings.shared.translateToEnglish
        let lexicon = Lexicon.load()
        let params = CodeSwitch.requestParameters(language: language,
                                                   primary: Settings.shared.mixedPrimary,
                                                   vocabularyPrompt: lexicon.vocabularyPrompt)
        Task {
            let raw = try? await server.transcribe(wavData: WavWriter.data(fromSamples: snapshot),
                                                    language: params.language,
                                                    translate: translate,
                                                    prompt: params.prompt)
            await MainActor.run {
                self.previewInFlight = false
                if self.recorder.isRecording, let raw {
                    let text = Postprocess.clean(raw)
                    if !text.isEmpty {
                        PreviewHUD.shared.update(text: text)
                    }
                }
            }
        }
    }

    private func finishDictation() {
        stopPreviewTimer()
        let samples = recorder.stop()
        if Settings.shared.soundCues { NSSound(named: "Tink")?.play() }
        guard samples.count > 3200 else { // ignore recordings under 0.2 s
            statusController.setStatus(.idle)
            return
        }
        guard let server else { return }
        statusController.setStatus(.transcribing)
        let wav = WavWriter.data(fromSamples: samples)
        let language = Settings.shared.language
        let translate = Settings.shared.translateToEnglish
        let lexicon = Lexicon.load()
        let params = CodeSwitch.requestParameters(language: language,
                                                   primary: Settings.shared.mixedPrimary,
                                                   vocabularyPrompt: lexicon.vocabularyPrompt)

        Task {
            do {
                let raw = try await server.transcribe(wavData: wav, language: params.language,
                                                       translate: translate,
                                                       prompt: params.prompt)
                var candidate = lexicon.apply(to: Postprocess.clean(raw))

                if Settings.shared.voiceCommandsEnabled, !candidate.isEmpty,
                   let command = VoiceCommands.match(candidate) {
                    await MainActor.run {
                        self.statusController.setStatus(.idle)
                        if !TextInserter.perform(command) {
                            Notifier.show(title: "Command needs Accessibility",
                                         body: "Grant Accessibility permission to run voice commands.")
                        }
                    }
                    return
                }

                if Settings.shared.spokenPunctuationEnabled {
                    candidate = SpokenPunctuation.apply(to: candidate)
                }

                let modeName = Settings.shared.currentModeName
                let text: String
                if modeName != "Raw", let mode = ModeStore.load().first(where: { $0.name == modeName }) {
                    do {
                        text = try await Ollama.rewrite(text: candidate, mode: mode,
                                                        defaultModel: Settings.shared.ollamaModel,
                                                        baseURL: URL(string: "http://127.0.0.1:11434")!)
                    } catch {
                        await MainActor.run {
                            Notifier.show(title: "AI mode failed — pasted raw text",
                                         body: error.localizedDescription)
                        }
                        text = candidate
                    }
                } else {
                    text = candidate
                }
                await MainActor.run {
                    self.statusController.setStatus(.idle)
                    guard !text.isEmpty else { return }
                    let pasted = TextInserter.insert(text)
                    if !pasted {
                        Notifier.show(title: "Copied to clipboard",
                                      body: "Grant Accessibility permission to paste automatically.")
                    }
                    HistoryStore.shared.append(text: text, language: language)
                }
            } catch {
                await MainActor.run {
                    self.statusController.setStatus(.error(error.localizedDescription))
                    Notifier.show(title: "Transcription failed", body: error.localizedDescription)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        self.statusController.setStatus(.idle)
                    }
                }
            }
        }
    }
}
