import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusController = StatusItemController()
    private let hotKeys = HotKeyManager()
    private let recorder = Recorder()
    private var engine: (any TranscriptionEngine)?
    private var lastPressDate: Date?
    private var pressStartedRecording = false
    private var previewTimer: Timer?
    private var previewScheduler = PartialScheduler()
    private var previewInFlight = false
    private var previewTask: Task<Void, Never>?
    private var dictationContext = ModeContext.Captured(appName: nil, selection: nil)
    /// True from the moment finishDictation commits to transcribing until
    /// the result (or error) is handled, so a hotkey/menu press mid-transcribe
    /// can't start a second, overlapping recording.
    private var isTranscribing = false
    /// The most recently completed live-preview partial, bound to the sample
    /// count the recording had when that partial was requested. Only ever
    /// set when the snapshot covered the FULL recording so far (i.e. the
    /// recording hadn't exceeded the preview window yet) — see previewTick.
    /// Cleared on every begin/cancel and consumed (cleared) by finishDictation.
    private var lastPartial: FastFinalize.Partial?

    /// Samples above this, the 30s preview window (snapshotSamples' cap) no
    /// longer covers the full recording, so a partial taken at/after this
    /// point cannot be trusted to stand in for the whole thing.
    private static let previewWindowSamples = 30 * 16000

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController.onToggleDictation = { [weak self] in self?.toggleDictation() }
        statusController.onCancelDictation = { [weak self] in self?.cancelDictation() }
        statusController.onSelectLanguage = { code in Settings.shared.language = code }
        statusController.onSelectModel = { [weak self] url in
            Settings.shared.modelPath = url.path
            self?.restartServer()
        }
        statusController.onSelectEngine = { [weak self] engine in
            Settings.shared.engine = engine
            self?.restartServer()
        }
        statusController.onChangeHotKey = { [weak self] in self?.beginHotKeyCapture() }
        statusController.levelProvider = { [weak self] in self?.recorder.currentLevel ?? 0 }

        SettingsWindowController.shared.onChangeHotKey = { [weak self] in self?.beginHotKeyCapture() }
        SettingsWindowController.shared.onModelChanged = { [weak self] in self?.restartServer() }

        statusController.onOpenOnboarding = { OnboardingWindowController.shared.show() }
        OnboardingWindowController.shared.onModelReady = { [weak self] in self?.restartServer() }

        hotKeys.onHotKeyDown = { [weak self] in self?.hotKeyDown() }
        hotKeys.onHotKeyUp = { [weak self] in self?.hotKeyUp() }
        hotKeys.register(keyCode: Settings.shared.hotKeyCode,
                         modifiers: Settings.shared.hotKeyModifiers)
        hotKeys.onSecondaryDown = { [weak self] in self?.cancelDictation() }

        RecordingPill.shared.levelProvider = { [weak self] in self?.recorder.currentLevel ?? 0 }
        RecordingPill.shared.onCancel = { [weak self] in self?.cancelDictation() }

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

        if !Settings.shared.hasCompletedOnboarding {
            OnboardingWindowController.shared.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys.unregisterSecondary()
        engine?.stop()
    }

    private func startServer() {
        guard let model = Settings.shared.resolveModelURL() else {
            statusController.setStatus(.error("No model — run: make model"))
            return
        }
        let name = Settings.displayName(forModel: model)
        statusController.setModelName(name)
        statusController.setStatus(.loading("Loading \(name)…"))

        let engine: any TranscriptionEngine
        if Settings.shared.engine == "inprocess" {
            engine = WhisperEngine(modelURL: model)
        } else {
            guard let binary = WhisperServerManager.locateServerBinary() else {
                statusController.setStatus(.error("whisper-server not found — brew install whisper-cpp"))
                return
            }
            engine = WhisperServerManager(serverBinary: binary, modelURL: model,
                                          port: Settings.shared.serverPort)
        }
        self.engine = engine
        engine.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.statusController.setStatus(.idle)
                    OnboardingWindowController.shared.setEngineStatus("Ready — dictate away!")
                case .failed(let message):
                    self?.statusController.setStatus(.error(message))
                    OnboardingWindowController.shared.setEngineStatus(message)
                case .starting:
                    OnboardingWindowController.shared.setEngineStatus("Loading model…")
                case .stopped: break
                }
            }
        }
        engine.start()
    }

    func beginHotKeyCapture() {
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

    func restartServer() {
        stopPreviewTimer()
        if recorder.isRecording {
            _ = recorder.stop()
            hotKeys.unregisterSecondary()
            RecordingPill.shared.hide()
        }
        engine?.stop()
        engine = nil
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
        guard !isTranscribing else {
            Notifier.show(title: "Still transcribing", body: "Wait for the current dictation to finish.")
            return
        }
        guard let engine, case .ready = engine.state else {
            Notifier.show(title: "Model still loading", body: "Try again in a few seconds.")
            return
        }
        _ = engine
        dictationContext = ModeContext.capture()
        lastPartial = nil
        do {
            recorder.autoStopEnabled = Settings.shared.autoStopEnabled
            try recorder.start()
            statusController.setStatus(.recording)
            if Settings.shared.soundCues { NSSound(named: "Pop")?.play() }
            RecordingPill.shared.show()
            hotKeys.registerSecondary(keyCode: 53, modifiers: 0) // Escape, only while recording
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
        previewTask?.cancel()
        previewTask = nil
        previewInFlight = false
    }

    private func previewTick() {
        guard recorder.isRecording else { return }
        let now = Date().timeIntervalSinceReferenceDate
        let sampleCountAtRequest = recorder.sampleCount
        guard previewScheduler.shouldFire(now: now, samplesAvailable: sampleCountAtRequest,
                                          inFlight: previewInFlight) else { return }
        guard let engine else { return }
        previewInFlight = true
        let snapshot = recorder.snapshotSamples(maxSamples: Self.previewWindowSamples)
        let language = Settings.shared.language
        let translate = Settings.shared.translateToEnglish
        let lexicon = Lexicon.load()
        let params = CodeSwitch.requestParameters(language: language,
                                                   primary: Settings.shared.mixedPrimary,
                                                   vocabularyPrompt: lexicon.vocabularyPrompt)
        previewTask = Task {
            let raw = try? await engine.transcribe(samples: snapshot,
                                                   language: params.language,
                                                   translate: translate,
                                                   prompt: params.prompt)
            await MainActor.run {
                self.previewInFlight = false
                guard !Task.isCancelled else { return }
                if self.recorder.isRecording, let raw {
                    // Only trust this partial as a stand-in for the full
                    // recording when the snapshot wasn't truncated by the
                    // preview window, i.e. it covered everything captured
                    // so far. Otherwise there's audio this partial never
                    // saw, so fast finalize must not fire.
                    if sampleCountAtRequest <= Self.previewWindowSamples {
                        self.lastPartial = FastFinalize.Partial(sampleCount: sampleCountAtRequest,
                                                                rawText: raw)
                    } else {
                        self.lastPartial = nil
                    }
                    let text = Postprocess.clean(raw)
                    if !text.isEmpty {
                        RecordingPill.shared.update(text: text)
                    }
                }
            }
        }
    }

    private func finishDictation() {
        stopPreviewTimer()
        RecordingPill.shared.hide()
        hotKeys.unregisterSecondary()
        let samples = recorder.stop()
        let partial = lastPartial
        lastPartial = nil
        if Settings.shared.soundCues { NSSound(named: "Tink")?.play() }
        guard samples.count > 3200 else { // ignore recordings under 0.2 s
            statusController.setStatus(.idle)
            return
        }
        guard let engine else { return }
        statusController.setStatus(.transcribing)
        isTranscribing = true
        let language = Settings.shared.language
        let translate = Settings.shared.translateToEnglish
        let lexicon = Lexicon.load()
        let context = dictationContext
        let pipeline = DictationPipeline(engine: engine)

        let tailRMS = FastFinalize.tailRMS(samples, from: partial?.sampleCount ?? 0)
        let reuse = Settings.shared.fastFinalizeEnabled &&
            FastFinalize.shouldReuse(partial: partial, totalSamples: samples.count, tailRMS: tailRMS)

        Task {
            do {
                let result: DictationResult
                if reuse, let partial {
                    result = await DictationPipeline.run(
                        rawTranscript: partial.rawText,
                        lexicon: lexicon,
                        voiceCommandsEnabled: Settings.shared.voiceCommandsEnabled,
                        spokenPunctuationEnabled: Settings.shared.spokenPunctuationEnabled,
                        modeName: Settings.shared.currentModeName, modes: ModeStore.load(),
                        context: context,
                        ollamaModel: Settings.shared.ollamaModel,
                        ollamaBaseURL: Settings.shared.ollamaBaseURL)
                } else {
                    result = try await pipeline.run(
                        samples: samples, language: language,
                        mixedPrimary: Settings.shared.mixedPrimary, translate: translate,
                        lexicon: lexicon,
                        voiceCommandsEnabled: Settings.shared.voiceCommandsEnabled,
                        spokenPunctuationEnabled: Settings.shared.spokenPunctuationEnabled,
                        modeName: Settings.shared.currentModeName, modes: ModeStore.load(),
                        context: context,
                        ollamaModel: Settings.shared.ollamaModel,
                        ollamaBaseURL: Settings.shared.ollamaBaseURL)
                }

                if let aiFailure = result.aiFailure {
                    await MainActor.run {
                        Notifier.show(title: "AI mode failed — pasted raw text",
                                     body: aiFailure.localizedDescription)
                    }
                }

                switch result.outcome {
                case .command(let command):
                    await MainActor.run {
                        self.isTranscribing = false
                        self.statusController.setStatus(.idle)
                        if !TextInserter.perform(command) {
                            Notifier.show(title: "Command needs Accessibility",
                                         body: "Grant Accessibility permission to run voice commands.")
                        }
                    }
                case .empty:
                    await MainActor.run {
                        self.isTranscribing = false
                        self.statusController.setStatus(.idle)
                    }
                case .text(let text):
                    await MainActor.run {
                        self.isTranscribing = false
                        self.statusController.setStatus(.idle)
                        let pasted = TextInserter.insert(text)
                        if !pasted {
                            Notifier.show(title: "Copied to clipboard",
                                          body: "Grant Accessibility permission to paste automatically.")
                        }
                        if Settings.shared.historyEnabled {
                            HistoryStore.shared.append(text: text, language: language)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isTranscribing = false
                    self.statusController.setStatus(.error(error.localizedDescription))
                    Notifier.show(title: "Transcription failed", body: error.localizedDescription)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        self.statusController.setStatus(.idle)
                    }
                }
            }
        }
    }

    /// Aborts the in-progress recording: discards the captured samples (no
    /// transcription, no paste, no history) and resets to idle.
    func cancelDictation() {
        guard recorder.isRecording else { return }
        stopPreviewTimer()
        _ = recorder.stop()
        lastPartial = nil
        if Settings.shared.soundCues { NSSound(named: "Basso")?.play() }
        RecordingPill.shared.hide()
        hotKeys.unregisterSecondary()
        statusController.setStatus(.idle)
        pressStartedRecording = false
        lastPressDate = nil
    }
}
