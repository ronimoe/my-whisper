import AppKit
import AVFoundation
import ApplicationServices

/// First-run wizard: permissions → model download → try it. Shown once
/// automatically (gated by Settings.shared.hasCompletedOnboarding) and
/// reachable any time via "Setup Assistant…" in the status menu or the
/// Settings window's "Download…" button.
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    /// Invoked once a model finishes downloading, so the caller can restart
    /// the transcription server against it.
    var onModelReady: (() -> Void)?

    private var window: NSWindow?
    private var refreshTimer: Timer?

    // Permissions section
    private var micStatusLabel: NSTextField!
    private var micButton: NSButton!
    private var axStatusLabel: NSTextField!
    private var axButton: NSButton!

    // Model section
    private var modelStack: NSStackView!
    private var modelStatusLabel: NSTextField!
    private var modelDownloadButton: NSButton!
    private var modelCancelButton: NSButton!
    private var modelProgressBar: NSProgressIndicator!
    private var modelByteLabel: NSTextField!

    // Try-it section
    private var tryItTextView: NSTextView!
    private var engineStatusLabel: NSTextField!

    // AI modes section
    private var aiModesStatusLabel: NSTextField!
    private var aiModesGetOllamaButton: NSButton!
    private var aiModesDownloadButton: NSButton!
    private var aiModesProgressBar: NSProgressIndicator!
    private var aiModesByteLabel: NSTextField!
    private var aiModesErrorLabel: NSTextField!
    private var aiModesProbeInFlight = false
    private var aiModesPullInFlight = false
    private var aiModesTickCount = 0
    private enum AIModesState { case unreachable, needsModel(String), ready(String) }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    /// Refreshes everything from current system/Settings state, brings the
    /// app forward, centers (every time — this window is meant to be seen),
    /// and shows it.
    func show() {
        if window == nil { buildWindow() }
        refreshPermissions()
        refreshModelSection()
        refreshAIModesSection()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        startTimer()
    }

    /// Called by AppDelegate from its engine onStateChange handler when this
    /// window is visible, so the user sees live loading/ready/error text.
    func setEngineStatus(_ text: String) {
        engineStatusLabel?.stringValue = text
    }

    // MARK: - Window construction

    private func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "Welcome to MyWhisper"
        w.isReleasedWhenClosed = false
        w.delegate = self

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let heading = NSTextField(labelWithString: "Let's get you set up.")
        heading.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        stack.addArrangedSubview(heading)

        stack.addArrangedSubview(boxed(title: "Permissions", content: buildPermissionsSection()))
        stack.addArrangedSubview(boxed(title: "Speech model", content: buildModelSection()))
        stack.addArrangedSubview(boxed(title: "AI modes (optional)", content: buildAIModesSection()))
        stack.addArrangedSubview(boxed(title: "Try it", content: buildTryItSection()))
        stack.addArrangedSubview(buildFooter())

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 560))
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

    private func boxed(title: String, content: NSView) -> NSView {
        let box = NSBox()
        box.titlePosition = .atTop
        box.title = title
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 480).isActive = true

        content.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(content)
        if let contentContainer = box.contentView {
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 8),
                content.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 8),
                content.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -8),
                content.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -8),
            ])
        }
        return box
    }

    // MARK: - Section 1: Permissions

    private func buildPermissionsSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        let micRow = NSStackView()
        micRow.orientation = .horizontal
        micRow.spacing = 8
        micRow.alignment = .centerY
        micStatusLabel = NSTextField(labelWithString: "Microphone: checking…")
        micButton = NSButton(title: "Grant…", target: self, action: #selector(grantMicrophone))
        micButton.bezelStyle = .rounded
        micRow.addArrangedSubview(micStatusLabel)
        micRow.addArrangedSubview(micButton)

        let axRow = NSStackView()
        axRow.orientation = .horizontal
        axRow.spacing = 8
        axRow.alignment = .centerY
        axStatusLabel = NSTextField(labelWithString: "Accessibility: checking…")
        axButton = NSButton(title: "Open System Settings…", target: self,
                            action: #selector(openAccessibilitySettings))
        axButton.bezelStyle = .rounded
        axRow.addArrangedSubview(axStatusLabel)
        axRow.addArrangedSubview(axButton)

        stack.addArrangedSubview(micRow)
        stack.addArrangedSubview(axRow)
        return stack
    }

    private func refreshPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micStatusLabel.stringValue = "Microphone: \u{2705} Granted"
            micButton.isHidden = true
        default:
            micStatusLabel.stringValue = "Microphone: \u{26A0}\u{FE0F} Not granted"
            micButton.isHidden = false
        }

        if AXIsProcessTrusted() {
            axStatusLabel.stringValue = "Accessibility: \u{2705} Granted"
            axButton.isHidden = true
        } else {
            axStatusLabel.stringValue = "Accessibility: \u{26A0}\u{FE0F} Not granted"
            axButton.isHidden = false
        }
    }

    @objc private func grantMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async { self?.refreshPermissions() }
            }
        default:
            // Previously denied — requestAccess would no-op, so send the
            // user straight to the relevant preference pane.
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        // This also re-arms the standard AX prompt, matching TextInserter's
        // existing behavior elsewhere in the app.
        TextInserter.promptForAccessibilityIfNeeded()
    }

    // MARK: - Section 2: Speech model

    private func buildModelSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        modelStack = stack

        modelStatusLabel = NSTextField(labelWithString: "")
        modelStatusLabel.lineBreakMode = .byWordWrapping
        modelStatusLabel.maximumNumberOfLines = 0
        modelStatusLabel.preferredMaxLayoutWidth = 440

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        modelDownloadButton = NSButton(title: "Download", target: self, action: #selector(startDownload))
        modelDownloadButton.bezelStyle = .rounded
        modelCancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelDownload))
        modelCancelButton.bezelStyle = .rounded
        buttonRow.addArrangedSubview(modelDownloadButton)
        buttonRow.addArrangedSubview(modelCancelButton)

        modelProgressBar = NSProgressIndicator()
        modelProgressBar.style = .bar
        modelProgressBar.isIndeterminate = false
        modelProgressBar.minValue = 0
        modelProgressBar.maxValue = 1
        modelProgressBar.widthAnchor.constraint(equalToConstant: 440).isActive = true

        modelByteLabel = NSTextField(labelWithString: "")

        stack.addArrangedSubview(modelStatusLabel)
        stack.addArrangedSubview(buttonRow)
        stack.addArrangedSubview(modelProgressBar)
        stack.addArrangedSubview(modelByteLabel)
        return stack
    }

    private func refreshModelSection() {
        if ModelDownloader.shared.isDownloading {
            setDownloadingUI(true)
            return
        }
        if let modelURL = Settings.shared.resolveModelURL() {
            if Settings.isBundledStarter(modelURL) {
                modelStatusLabel.stringValue =
                    "\u{2705} Starter model included (small) — download the full model for best accuracy"
                modelDownloadButton.isHidden = false
                modelCancelButton.isHidden = true
                modelProgressBar.isHidden = true
                modelByteLabel.isHidden = true
            } else {
                let name = Settings.displayName(forModel: modelURL)
                modelStatusLabel.stringValue = "\u{2705} Model ready: \(name)"
                modelDownloadButton.isHidden = true
                modelCancelButton.isHidden = true
                modelProgressBar.isHidden = true
                modelByteLabel.isHidden = true
            }
        } else {
            modelStatusLabel.stringValue =
                "Download the recommended model (large-v3-turbo, ~1.5 GB, one time)"
            modelDownloadButton.isHidden = false
            modelCancelButton.isHidden = true
            modelProgressBar.isHidden = true
            modelByteLabel.isHidden = true
        }
    }

    private func setDownloadingUI(_ downloading: Bool) {
        modelDownloadButton.isHidden = downloading
        modelCancelButton.isHidden = !downloading
        modelProgressBar.isHidden = !downloading
        modelByteLabel.isHidden = !downloading
        if downloading {
            modelStatusLabel.stringValue = "Downloading large-v3-turbo…"
        }
    }

    @objc private func startDownload() {
        setDownloadingUI(true)
        modelProgressBar.doubleValue = 0
        modelByteLabel.stringValue = ""

        ModelDownloader.shared.download(model: "large-v3-turbo", progress: { [weak self] fraction, written, total in
            guard let self else { return }
            self.modelProgressBar.doubleValue = fraction
            let writtenString = Self.byteFormatter.string(fromByteCount: written)
            let totalString = Self.byteFormatter.string(fromByteCount: total)
            self.modelByteLabel.stringValue = total > 0
                ? "\(writtenString) of \(totalString)" : writtenString
        }, completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.refreshModelSection()
                self.onModelReady?()
            case .failure(let error):
                if error is CancellationError {
                    self.refreshModelSection()
                    return
                }
                self.refreshModelSection()
                Notifier.show(title: "Model download failed", body: error.localizedDescription)
            }
        })
    }

    @objc private func cancelDownload() {
        ModelDownloader.shared.cancel()
    }

    // MARK: - Section 2b: AI modes (optional)

    private func buildAIModesSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        let explainer = NSTextField(labelWithString:
            "Rewrite dictation as emails or messages using a local AI (Ollama). "
                + "Optional — everything else works without it. Stays 100% on your Mac.")
        explainer.lineBreakMode = .byWordWrapping
        explainer.maximumNumberOfLines = 0
        explainer.preferredMaxLayoutWidth = 440
        explainer.textColor = .secondaryLabelColor

        aiModesStatusLabel = NSTextField(labelWithString: "")
        aiModesStatusLabel.lineBreakMode = .byWordWrapping
        aiModesStatusLabel.maximumNumberOfLines = 0
        aiModesStatusLabel.preferredMaxLayoutWidth = 440

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        aiModesGetOllamaButton = NSButton(title: "Get Ollama \u{2197}", target: self,
                                          action: #selector(openOllamaDownloadPage))
        aiModesGetOllamaButton.bezelStyle = .rounded
        aiModesDownloadButton = NSButton(title: "Download AI Model (~2 GB)", target: self,
                                         action: #selector(startAIModelDownload))
        aiModesDownloadButton.bezelStyle = .rounded
        buttonRow.addArrangedSubview(aiModesGetOllamaButton)
        buttonRow.addArrangedSubview(aiModesDownloadButton)

        aiModesProgressBar = NSProgressIndicator()
        aiModesProgressBar.style = .bar
        aiModesProgressBar.isIndeterminate = false
        aiModesProgressBar.minValue = 0
        aiModesProgressBar.maxValue = 1
        aiModesProgressBar.widthAnchor.constraint(equalToConstant: 440).isActive = true

        aiModesByteLabel = NSTextField(labelWithString: "")
        aiModesErrorLabel = NSTextField(labelWithString: "")
        aiModesErrorLabel.textColor = .systemRed
        aiModesErrorLabel.lineBreakMode = .byWordWrapping
        aiModesErrorLabel.maximumNumberOfLines = 0
        aiModesErrorLabel.preferredMaxLayoutWidth = 440

        stack.addArrangedSubview(explainer)
        stack.addArrangedSubview(aiModesStatusLabel)
        stack.addArrangedSubview(buttonRow)
        stack.addArrangedSubview(aiModesProgressBar)
        stack.addArrangedSubview(aiModesByteLabel)
        stack.addArrangedSubview(aiModesErrorLabel)
        return stack
    }

    /// Re-probes Ollama's reachability and, if reachable, whether the
    /// configured chat model is present, then updates the UI. Never runs
    /// concurrently with another probe or an in-flight pull.
    private func refreshAIModesSection() {
        guard !aiModesProbeInFlight, !aiModesPullInFlight else { return }
        aiModesProbeInFlight = true
        let baseURL = Settings.shared.ollamaBaseURL
        let wantedModel = Settings.shared.ollamaModel

        Task { [weak self] in
            guard let self else { return }
            let reachable = await Ollama.probeIsOllama(baseURL: baseURL)
            let state: AIModesState
            if reachable {
                let names = await Ollama.listModelNames(baseURL: baseURL) ?? []
                let hasModel = names.contains { $0 == wantedModel || $0.hasPrefix(wantedModel) }
                state = hasModel ? .ready(wantedModel) : .needsModel(wantedModel)
            } else {
                state = .unreachable
            }
            await MainActor.run {
                self.aiModesProbeInFlight = false
                self.applyAIModesState(state)
            }
        }
    }

    private func applyAIModesState(_ state: AIModesState) {
        guard !aiModesPullInFlight else { return }
        aiModesErrorLabel.stringValue = ""
        switch state {
        case .unreachable:
            aiModesStatusLabel.stringValue = "\u{25CB} Ollama not installed (or not running)"
            aiModesGetOllamaButton.isHidden = false
            aiModesDownloadButton.isHidden = true
            aiModesProgressBar.isHidden = true
            aiModesByteLabel.isHidden = true
        case .needsModel:
            aiModesStatusLabel.stringValue = "\u{25D0} Ollama is running \u{2014} needs an AI model"
            aiModesGetOllamaButton.isHidden = true
            aiModesDownloadButton.isHidden = false
            aiModesProgressBar.isHidden = true
            aiModesByteLabel.isHidden = true
        case .ready(let model):
            aiModesStatusLabel.stringValue =
                "\u{2705} AI modes ready (\(model)) \u{2014} pick a mode from the menu bar (e.g. Email)."
            aiModesGetOllamaButton.isHidden = true
            aiModesDownloadButton.isHidden = true
            aiModesProgressBar.isHidden = true
            aiModesByteLabel.isHidden = true
        }
    }

    @objc private func openOllamaDownloadPage() {
        // Opens in the user's default browser — the app itself never fetches
        // this URL. Once the user installs/launches Ollama, the periodic
        // probe (startTimer) picks it up automatically.
        NSWorkspace.shared.open(URL(string: "https://ollama.com/download")!)
    }

    @objc private func startAIModelDownload() {
        let model = Settings.shared.ollamaModel
        let baseURL = Settings.shared.ollamaBaseURL

        aiModesPullInFlight = true
        aiModesErrorLabel.stringValue = ""
        aiModesDownloadButton.isEnabled = false
        aiModesProgressBar.isHidden = false
        aiModesProgressBar.doubleValue = 0
        aiModesByteLabel.isHidden = false
        aiModesByteLabel.stringValue = ""
        aiModesStatusLabel.stringValue = "Downloading \(model)\u{2026}"

        Task { [weak self] in
            guard let self else { return }
            do {
                try await Ollama.pullModel(name: model, baseURL: baseURL) { status, completed, total in
                    MainActor.assumeIsolated {
                        if let completed, let total, total > 0 {
                            self.aiModesProgressBar.doubleValue = Double(completed) / Double(total)
                            let writtenString = Self.byteFormatter.string(fromByteCount: completed)
                            let totalString = Self.byteFormatter.string(fromByteCount: total)
                            self.aiModesByteLabel.stringValue = "\(writtenString) of \(totalString) \u{2014} \(status)"
                        } else {
                            self.aiModesByteLabel.stringValue = status
                        }
                    }
                }
                await MainActor.run {
                    self.aiModesPullInFlight = false
                    self.aiModesDownloadButton.isEnabled = true
                    self.refreshAIModesSection()
                }
            } catch {
                await MainActor.run {
                    self.aiModesPullInFlight = false
                    self.aiModesDownloadButton.isEnabled = true
                    self.aiModesProgressBar.isHidden = true
                    self.aiModesByteLabel.isHidden = true
                    self.aiModesErrorLabel.stringValue = error.localizedDescription
                    self.applyAIModesState(.needsModel(model))
                }
            }
        }
    }

    // MARK: - Section 3: Try it

    private func buildTryItSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.widthAnchor.constraint(equalToConstant: 440).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let textView = NSTextView()
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.string = ""
        let hotkey = Settings.shared.hotKeyDisplay
        placeholderString(for: textView, hotkey: hotkey)

        scrollView.documentView = textView
        tryItTextView = textView

        engineStatusLabel = NSTextField(labelWithString: "")
        engineStatusLabel.textColor = .secondaryLabelColor

        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(engineStatusLabel)
        return stack
    }

    /// NSTextView has no built-in placeholder, so we show gray hint TEXT that
    /// is really in the view; `tryItPlaceholderActive` tracks it so the first
    /// transcript insertion (or programmatic clear) replaces it wholesale.
    private var tryItPlaceholderActive = false

    private func placeholderString(for textView: NSTextView, hotkey: String) {
        textView.string = "Click here, press \(hotkey) and speak — your words will appear."
        textView.textColor = .placeholderTextColor
        tryItPlaceholderActive = true
    }

    /// Direct-inserts a dictation transcript into the try-it box, bypassing
    /// the clipboard + synthetic ⌘V path (which is unreliable when the paste
    /// target is our own window, e.g. under heavy load during model
    /// downloads). Returns false when the wizard isn't the active paste
    /// target so the caller falls back to the normal paste path.
    func insertTranscript(_ text: String) -> Bool {
        guard let window, window.isVisible, window.isKeyWindow,
              let textView = tryItTextView else { return false }
        if tryItPlaceholderActive {
            textView.string = ""
            textView.textColor = .labelColor
            tryItPlaceholderActive = false
        }
        let current = textView.string
        textView.string = current.isEmpty ? text : current + " " + text
        textView.textColor = .labelColor
        return true
    }

    // MARK: - Footer

    private func buildFooter() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true

        let done = NSButton(title: "Done", target: self, action: #selector(doneClicked))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"

        row.addArrangedSubview(spacer)
        row.addArrangedSubview(done)
        return row
    }

    @objc private func doneClicked() {
        Settings.shared.hasCompletedOnboarding = true
        window?.close()
    }

    // MARK: - Timer

    private func startTimer() {
        refreshTimer?.invalidate()
        aiModesTickCount = 0
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshPermissions()
            // Rate-limit the AI-modes network probe to roughly every 3 ticks
            // (~3 s) rather than every second — it's localhost and cheap, but
            // there's no reason to hammer it on a 1 Hz UI timer.
            self.aiModesTickCount += 1
            if self.aiModesTickCount >= 3 {
                self.aiModesTickCount = 0
                self.refreshAIModesSection()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        stopTimer()
    }
}
