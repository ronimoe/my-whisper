import AppKit
import ServiceManagement

final class StatusItemController: NSObject, NSMenuDelegate {
    enum DictationStatus {
        case loading(String)
        case idle
        case recording
        case transcribing
        case error(String)
    }

    var onToggleDictation: (() -> Void)?
    var onSelectLanguage: ((String) -> Void)?
    var onSelectModel: ((URL) -> Void)?
    var onChangeHotKey: (() -> Void)?
    /// Supplies the live mic level (0…1) for the recording animation.
    var levelProvider: (() -> Float)?

    private let item: NSStatusItem
    private var status: DictationStatus = .loading("Starting…")
    private var modelName = "no model"
    private var animationTimer: Timer?
    private var pulsePhase = false

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        applyIcon()
    }

    func setStatus(_ newStatus: DictationStatus) {
        status = newStatus
        applyIcon()
    }

    func setModelName(_ name: String) {
        modelName = name
    }

    private func applyIcon() {
        animationTimer?.invalidate()
        animationTimer = nil
        guard let button = item.button else { return }

        switch status {
        case .loading:
            button.image = MenuBarIcon.loading
            button.contentTintColor = nil
        case .idle:
            button.image = MenuBarIcon.idle
            button.contentTintColor = nil
        case .error:
            button.image = MenuBarIcon.error
            button.contentTintColor = .systemOrange
        case .recording:
            button.contentTintColor = .systemRed
            button.image = MenuBarIcon.recording(level: CGFloat(levelProvider?() ?? 0))
            let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
                guard let self, let button = self.item.button else { return }
                button.image = MenuBarIcon.recording(level: CGFloat(self.levelProvider?() ?? 0))
            }
            RunLoop.main.add(timer, forMode: .common)
            animationTimer = timer
        case .transcribing:
            button.contentTintColor = nil
            button.image = MenuBarIcon.transcribingBright
            let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
                guard let self, let button = self.item.button else { return }
                self.pulsePhase.toggle()
                button.image = self.pulsePhase
                    ? MenuBarIcon.transcribingDim : MenuBarIcon.transcribingBright
            }
            RunLoop.main.add(timer, forMode: .common)
            animationTimer = timer
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let statusLine: String
        switch status {
        case .loading(let message): statusLine = message
        case .idle: statusLine = "Ready — \(modelName)"
        case .recording: statusLine = "Recording…"
        case .transcribing: statusLine = "Transcribing…"
        case .error(let message): statusLine = "Error: \(message)"
        }
        let info = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(.separator())

        let hotkey = Settings.shared.hotKeyDisplay
        let toggleTitle: String
        var toggleEnabled = true
        switch status {
        case .idle: toggleTitle = "Start Dictation (\(hotkey))"
        case .recording: toggleTitle = "Stop & Transcribe (\(hotkey))"
        default:
            toggleTitle = "Start Dictation (\(hotkey))"
            toggleEnabled = false
        }
        let toggle = NSMenuItem(title: toggleTitle, action: #selector(toggleDictation), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = toggleEnabled
        menu.addItem(toggle)
        menu.addItem(.separator())

        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        languageItem.submenu = buildLanguageMenu()
        menu.addItem(languageItem)

        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        modelItem.submenu = buildModelMenu()
        menu.addItem(modelItem)

        menu.addItem(.separator())
        let hotkeyItem = NSMenuItem(title: "Change Hotkey… (now \(hotkey))",
                                    action: #selector(changeHotKey), keyEquivalent: "")
        hotkeyItem.target = self
        menu.addItem(hotkeyItem)

        let replacementsItem = NSMenuItem(title: "Edit Text Replacements…",
                                          action: #selector(editTextReplacements), keyEquivalent: "")
        replacementsItem.target = self
        menu.addItem(replacementsItem)

        let soundItem = NSMenuItem(title: "Sound Cues", action: #selector(toggleSoundCues), keyEquivalent: "")
        soundItem.target = self
        soundItem.state = Settings.shared.soundCues ? .on : .off
        menu.addItem(soundItem)

        let autoStopItem = NSMenuItem(title: "Auto-Stop After Silence", action: #selector(toggleAutoStop), keyEquivalent: "")
        autoStopItem.target = self
        autoStopItem.state = Settings.shared.autoStopEnabled ? .on : .off
        menu.addItem(autoStopItem)

        let translateItem = NSMenuItem(title: "Translate to English", action: #selector(toggleTranslate), keyEquivalent: "")
        translateItem.target = self
        translateItem.state = Settings.shared.translateToEnglish ? .on : .off
        menu.addItem(translateItem)

        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        launchAtLoginItem.isEnabled = Bundle.main.bundleURL.pathExtension == "app"
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())
        let logItem = NSMenuItem(title: "Open Server Log", action: #selector(openLog), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)

        let quit = NSMenuItem(title: "Quit MyWhisper", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func buildLanguageMenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let current = Settings.shared.language
        for (code, name) in Settings.languages {
            let entry = NSMenuItem(title: name, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = code
            entry.state = (code == current) ? .on : .off
            submenu.addItem(entry)
        }
        return submenu
    }

    private func buildModelMenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let currentModel = Settings.shared.resolveModelURL()
        let models = Settings.shared.availableModels()
        if models.isEmpty {
            let none = NSMenuItem(title: "No models downloaded", action: nil, keyEquivalent: "")
            none.isEnabled = false
            submenu.addItem(none)
        }
        for model in models {
            let entry = NSMenuItem(title: Settings.displayName(forModel: model),
                                   action: #selector(selectModel(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = model
            entry.state = (model == currentModel) ? .on : .off
            submenu.addItem(entry)
        }
        submenu.addItem(.separator())
        let openFolder = NSMenuItem(title: "Open Models Folder",
                                    action: #selector(openModelsFolder), keyEquivalent: "")
        openFolder.target = self
        submenu.addItem(openFolder)
        return submenu
    }

    @objc private func toggleDictation() { onToggleDictation?() }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        onSelectLanguage?(code)
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        onSelectModel?(url)
    }

    @objc private func changeHotKey() { onChangeHotKey?() }

    @objc private func toggleSoundCues() {
        Settings.shared.soundCues.toggle()
    }

    @objc private func toggleAutoStop() {
        Settings.shared.autoStopEnabled.toggle()
    }

    @objc private func toggleTranslate() {
        Settings.shared.translateToEnglish.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        } else {
            do {
                try SMAppService.mainApp.register()
            } catch {
                Notifier.show(title: "Couldn't enable Launch at Login", body: error.localizedDescription)
            }
        }
    }

    @objc private func editTextReplacements() {
        Lexicon.ensureFileExists()
        NSWorkspace.shared.open(Lexicon.fileURL)
    }

    @objc private func openModelsFolder() {
        NSWorkspace.shared.open(Settings.modelsDir)
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(Settings.appSupportDir.appendingPathComponent("whisper-server.log"))
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
