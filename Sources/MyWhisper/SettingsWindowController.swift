import AppKit
import ServiceManagement

/// A singleton Settings window exposing the hotkey, behavior toggles, and
/// dictation options that otherwise live in the status-bar menu.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    /// Invoked when the user clicks "Change…" next to the hotkey row.
    var onChangeHotKey: (() -> Void)?
    /// Invoked after the user picks a different model from the popup.
    var onModelChanged: (() -> Void)?

    private var window: NSWindow?
    private var hasCenteredOnce = false

    private var hotKeyValueLabel: NSTextField!

    private var soundCuesCheckbox: NSButton!
    private var autoStopCheckbox: NSButton!
    private var voiceCommandsCheckbox: NSButton!
    private var spokenPunctuationCheckbox: NSButton!
    private var livePreviewCheckbox: NSButton!
    private var translateCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var saveHistoryCheckbox: NSButton!

    private var languagePopup: NSPopUpButton!
    private var modelPopup: NSPopUpButton!
    private var modePopup: NSPopUpButton!
    private var ollamaModelField: NSTextField!

    private var models: [URL] = []

    /// Reloads control state from Settings, brings the app forward, and
    /// shows the window (centering only the first time it's shown).
    func show() {
        if window == nil { buildWindow() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        if !hasCenteredOnce {
            window?.center()
            hasCenteredOnce = true
        }
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Window construction

    private func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 480),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "MyWhisper Settings"
        w.isReleasedWhenClosed = false
        w.delegate = self

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(buildHotKeyRow())
        stack.addArrangedSubview(separator())

        stack.addArrangedSubview(buildBehaviorSection())
        stack.addArrangedSubview(separator())

        stack.addArrangedSubview(buildDictationSection())
        stack.addArrangedSubview(separator())

        stack.addArrangedSubview(buildButtonsSection())

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 470, height: 480))
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
        ])

        w.contentView = contentView
        window = w
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 430).isActive = true
        return box
    }

    private func buildHotKeyRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY

        let label = NSTextField(labelWithString: "Dictation hotkey:")
        let value = NSTextField(labelWithString: Settings.shared.hotKeyDisplay)
        value.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        hotKeyValueLabel = value

        let change = NSButton(title: "Change…", target: self, action: #selector(changeHotKeyClicked))
        change.bezelStyle = .rounded

        row.addArrangedSubview(label)
        row.addArrangedSubview(value)
        row.addArrangedSubview(change)
        return row
    }

    private func buildBehaviorSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        soundCuesCheckbox = NSButton(checkboxWithTitle: "Sound cues", target: self,
                                     action: #selector(toggleSoundCues))
        autoStopCheckbox = NSButton(checkboxWithTitle: "Auto-stop after silence", target: self,
                                    action: #selector(toggleAutoStop))
        voiceCommandsCheckbox = NSButton(checkboxWithTitle: "Voice commands", target: self,
                                         action: #selector(toggleVoiceCommands))
        spokenPunctuationCheckbox = NSButton(checkboxWithTitle: "Spoken punctuation (\"koma\" → ,)",
                                             target: self, action: #selector(toggleSpokenPunctuation))
        livePreviewCheckbox = NSButton(checkboxWithTitle: "Live preview while dictating", target: self,
                                       action: #selector(toggleLivePreview))
        translateCheckbox = NSButton(checkboxWithTitle: "Translate to English", target: self,
                                     action: #selector(toggleTranslate))
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self,
                                         action: #selector(toggleLaunchAtLogin))
        launchAtLoginCheckbox.isEnabled = Bundle.main.bundleURL.pathExtension == "app"
        saveHistoryCheckbox = NSButton(checkboxWithTitle: "Save history", target: self,
                                       action: #selector(toggleSaveHistory))

        for checkbox in [soundCuesCheckbox, autoStopCheckbox, voiceCommandsCheckbox,
                         spokenPunctuationCheckbox, livePreviewCheckbox, translateCheckbox,
                         launchAtLoginCheckbox, saveHistoryCheckbox] {
            stack.addArrangedSubview(checkbox!)
        }
        return stack
    }

    private func buildDictationSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        languagePopup = NSPopUpButton()
        languagePopup.target = self
        languagePopup.action = #selector(selectLanguage)
        stack.addArrangedSubview(popupRow(label: "Language:", popup: languagePopup))

        modelPopup = NSPopUpButton()
        modelPopup.target = self
        modelPopup.action = #selector(selectModel)
        let modelRow = NSStackView()
        modelRow.orientation = .horizontal
        modelRow.spacing = 8
        modelRow.alignment = .centerY
        modelRow.addArrangedSubview(popupRow(label: "Model:", popup: modelPopup))
        let downloadModelButton = NSButton(title: "Download…", target: self,
                                           action: #selector(openModelDownloader))
        downloadModelButton.bezelStyle = .rounded
        modelRow.addArrangedSubview(downloadModelButton)
        stack.addArrangedSubview(modelRow)

        modePopup = NSPopUpButton()
        modePopup.target = self
        modePopup.action = #selector(selectMode)
        stack.addArrangedSubview(popupRow(label: "AI mode:", popup: modePopup))

        ollamaModelField = NSTextField(string: Settings.shared.ollamaModel)
        ollamaModelField.target = self
        ollamaModelField.action = #selector(commitOllamaModel)
        ollamaModelField.delegate = self
        ollamaModelField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        stack.addArrangedSubview(popupRow(label: "Ollama model:", control: ollamaModelField))

        return stack
    }

    private func popupRow(label text: String, popup: NSPopUpButton) -> NSView {
        popupRow(label: text, control: popup)
    }

    private func popupRow(label text: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY

        let label = NSTextField(labelWithString: text)
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true
        label.alignment = .right

        row.addArrangedSubview(label)
        row.addArrangedSubview(control)
        return row
    }

    private func buildButtonsSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let row1 = NSStackView()
        row1.orientation = .horizontal
        row1.spacing = 8
        let openModelsButton = NSButton(title: "Open Models Folder", target: self,
                                        action: #selector(openModelsFolder))
        openModelsButton.bezelStyle = .rounded
        let editReplacementsButton = NSButton(title: "Edit Replacements…", target: self,
                                              action: #selector(editReplacements))
        editReplacementsButton.bezelStyle = .rounded
        row1.addArrangedSubview(openModelsButton)
        row1.addArrangedSubview(editReplacementsButton)

        let row2 = NSStackView()
        row2.orientation = .horizontal
        row2.spacing = 8
        let editModesButton = NSButton(title: "Edit Modes…", target: self, action: #selector(editModes))
        editModesButton.bezelStyle = .rounded
        let openLogButton = NSButton(title: "Open Server Log", target: self, action: #selector(openLog))
        openLogButton.bezelStyle = .rounded
        row2.addArrangedSubview(editModesButton)
        row2.addArrangedSubview(openLogButton)

        stack.addArrangedSubview(row1)
        stack.addArrangedSubview(row2)
        return stack
    }

    // MARK: - Refresh

    /// Rebuilds control state from Settings so reopening the window (or
    /// bringing it back to key) always reflects reality.
    private func refresh() {
        hotKeyValueLabel.stringValue = Settings.shared.hotKeyDisplay

        soundCuesCheckbox.state = Settings.shared.soundCues ? .on : .off
        autoStopCheckbox.state = Settings.shared.autoStopEnabled ? .on : .off
        voiceCommandsCheckbox.state = Settings.shared.voiceCommandsEnabled ? .on : .off
        spokenPunctuationCheckbox.state = Settings.shared.spokenPunctuationEnabled ? .on : .off
        livePreviewCheckbox.state = Settings.shared.livePreviewEnabled ? .on : .off
        translateCheckbox.state = Settings.shared.translateToEnglish ? .on : .off
        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        launchAtLoginCheckbox.isEnabled = Bundle.main.bundleURL.pathExtension == "app"
        saveHistoryCheckbox.state = Settings.shared.historyEnabled ? .on : .off

        refreshLanguagePopup()
        refreshModelPopup()
        refreshModePopup()
        ollamaModelField.stringValue = Settings.shared.ollamaModel
    }

    private func refreshLanguagePopup() {
        languagePopup.removeAllItems()
        let current = Settings.shared.language
        for (code, name) in Settings.languages {
            languagePopup.addItem(withTitle: name)
            languagePopup.lastItem?.representedObject = code
        }
        if let index = Settings.languages.firstIndex(where: { $0.code == current }) {
            languagePopup.selectItem(at: index)
        }
    }

    private func refreshModelPopup() {
        modelPopup.removeAllItems()
        models = Settings.shared.availableModels()
        let current = Settings.shared.resolveModelURL()
        if models.isEmpty {
            modelPopup.addItem(withTitle: "No models downloaded")
            modelPopup.isEnabled = false
            return
        }
        modelPopup.isEnabled = true
        for model in models {
            modelPopup.addItem(withTitle: Settings.displayName(forModel: model))
        }
        if let current, let index = models.firstIndex(of: current) {
            modelPopup.selectItem(at: index)
        }
    }

    private func refreshModePopup() {
        modePopup.removeAllItems()
        let modes = ModeStore.load()
        let current = Settings.shared.currentModeName

        modePopup.addItem(withTitle: "Raw")
        for mode in modes {
            modePopup.addItem(withTitle: mode.name)
        }
        if let index = modePopup.itemTitles.firstIndex(of: current) {
            modePopup.selectItem(at: index)
        } else {
            modePopup.selectItem(at: 0)
        }
    }

    // MARK: - Actions

    @objc private func changeHotKeyClicked() {
        onChangeHotKey?()
    }

    @objc private func toggleSoundCues() {
        Settings.shared.soundCues = soundCuesCheckbox.state == .on
    }

    @objc private func toggleAutoStop() {
        Settings.shared.autoStopEnabled = autoStopCheckbox.state == .on
    }

    @objc private func toggleVoiceCommands() {
        Settings.shared.voiceCommandsEnabled = voiceCommandsCheckbox.state == .on
    }

    @objc private func toggleSpokenPunctuation() {
        Settings.shared.spokenPunctuationEnabled = spokenPunctuationCheckbox.state == .on
    }

    @objc private func toggleLivePreview() {
        Settings.shared.livePreviewEnabled = livePreviewCheckbox.state == .on
    }

    @objc private func toggleTranslate() {
        Settings.shared.translateToEnglish = translateCheckbox.state == .on
    }

    @objc private func toggleSaveHistory() {
        Settings.shared.historyEnabled = saveHistoryCheckbox.state == .on
    }

    @objc private func toggleLaunchAtLogin() {
        if launchAtLoginCheckbox.state == .on {
            do {
                try SMAppService.mainApp.register()
            } catch {
                Notifier.show(title: "Couldn't enable Launch at Login", body: error.localizedDescription)
                launchAtLoginCheckbox.state = .off
            }
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    @objc private func selectLanguage() {
        guard let code = languagePopup.selectedItem?.representedObject as? String else { return }
        Settings.shared.language = code
    }

    @objc private func selectModel() {
        let index = modelPopup.indexOfSelectedItem
        guard index >= 0, index < models.count else { return }
        let url = models[index]
        Settings.shared.modelPath = url.path
        onModelChanged?()
    }

    @objc private func selectMode() {
        guard let title = modePopup.selectedItem?.title else { return }
        Settings.shared.currentModeName = title
    }

    @objc private func commitOllamaModel() {
        let trimmed = ollamaModelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            ollamaModelField.stringValue = Settings.shared.ollamaModel
            return
        }
        Settings.shared.ollamaModel = trimmed
    }

    @objc private func openModelsFolder() {
        NSWorkspace.shared.open(Settings.modelsDir)
    }

    @objc private func openModelDownloader() {
        OnboardingWindowController.shared.show()
    }

    @objc private func editReplacements() {
        Lexicon.ensureFileExists()
        NSWorkspace.shared.open(Lexicon.fileURL)
    }

    @objc private func editModes() {
        ModeStore.ensureFileExists()
        NSWorkspace.shared.open(ModeStore.fileURL)
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(Settings.appSupportDir.appendingPathComponent("whisper-server.log"))
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        // The hotkey (or other state) may have changed while this window
        // was open but not focused, e.g. via the status menu.
        refresh()
    }

    func windowWillClose(_ notification: Notification) {}
}

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === ollamaModelField else { return }
        commitOllamaModel()
    }
}
