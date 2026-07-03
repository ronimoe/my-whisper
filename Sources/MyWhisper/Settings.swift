import Foundation

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    /// Centralizes UserDefaults keys. Raw values MUST match the strings
    /// already persisted on disk exactly — including the pre-existing
    /// `livePreviewEnabled` -> "livePreview" mismatch. This enum only
    /// centralizes the keys; it must never rename one, or existing users'
    /// saved settings would be orphaned.
    private enum Key: String {
        case language
        case mixedPrimary
        case modelPath
        case serverPort
        case engine
        case hotKeyCode
        case hotKeyModifiers
        case hotKeyDisplay
        case soundCues
        case autoStopEnabled
        case translateToEnglish
        case voiceCommandsEnabled
        case historyEnabled
        case livePreviewEnabled = "livePreview"
        case spokenPunctuationEnabled
        case currentModeName
        case ollamaModel
        case ollamaBaseURL
        case hasCompletedOnboarding
    }

    /// Restricts a directory (which may already exist from before this
    /// change) to owner-only access, since it holds cleartext dictation
    /// history, settings, and transcripts.
    private static func lockDown(_ dir: URL) {
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: dir.path)
    }

    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MyWhisper", isDirectory: true)
        lockDown(dir)
        return dir
    }()

    static var modelsDir: URL {
        let dir = appSupportDir.appendingPathComponent("models", isDirectory: true)
        lockDown(dir)
        return dir
    }

    /// Whisper language code, or "auto" for detection, or "mixed" for
    /// code-switched dictation (see CodeSwitch).
    var language: String {
        get { defaults.string(forKey: Key.language.rawValue) ?? "auto" }
        set { defaults.set(newValue, forKey: Key.language.rawValue) }
    }

    /// Primary language pinned to whisper when `language == "mixed"`.
    var mixedPrimary: String {
        get { defaults.string(forKey: Key.mixedPrimary.rawValue) ?? "id" }
        set { defaults.set(newValue, forKey: Key.mixedPrimary.rawValue) }
    }

    /// Explicit model path; when nil, the best model found in modelsDir is used.
    var modelPath: String? {
        get { defaults.string(forKey: Key.modelPath.rawValue) }
        set { defaults.set(newValue, forKey: Key.modelPath.rawValue) }
    }

    var serverPort: Int {
        defaults.object(forKey: Key.serverPort.rawValue) as? Int ?? 8178
    }

    /// Transcription backend: "server" (whisper-server subprocess) or
    /// "inprocess" (libwhisper linked directly). Default "server".
    var engine: String {
        get { defaults.string(forKey: Key.engine.rawValue) ?? "server" }
        set { defaults.set(newValue, forKey: Key.engine.rawValue) }
    }

    /// Carbon virtual key code for the dictation hotkey. Default: Space (49).
    var hotKeyCode: UInt32 {
        defaults.object(forKey: Key.hotKeyCode.rawValue) as? UInt32 ?? 49
    }

    /// Carbon modifier mask. cmd=256 shift=512 option=2048 control=4096. Default: Option.
    var hotKeyModifiers: UInt32 {
        defaults.object(forKey: Key.hotKeyModifiers.rawValue) as? UInt32 ?? 2048
    }

    /// Human-readable hotkey, shown in menus (e.g. "⌥Space").
    var hotKeyDisplay: String {
        get { defaults.string(forKey: Key.hotKeyDisplay.rawValue) ?? "⌥Space" }
        set { defaults.set(newValue, forKey: Key.hotKeyDisplay.rawValue) }
    }

    func setHotKey(code: UInt32, modifiers: UInt32, display: String) {
        defaults.set(Int(code), forKey: Key.hotKeyCode.rawValue)
        defaults.set(Int(modifiers), forKey: Key.hotKeyModifiers.rawValue)
        hotKeyDisplay = display
    }

    /// Play a sound when recording starts/stops. Default on.
    var soundCues: Bool {
        get { defaults.object(forKey: Key.soundCues.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.soundCues.rawValue) }
    }

    /// Automatically stop recording after a period of silence. Default off.
    var autoStopEnabled: Bool {
        get { defaults.object(forKey: Key.autoStopEnabled.rawValue) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.autoStopEnabled.rawValue) }
    }

    /// Translate non-English speech to English instead of transcribing verbatim. Default off.
    var translateToEnglish: Bool {
        get { defaults.object(forKey: Key.translateToEnglish.rawValue) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.translateToEnglish.rawValue) }
    }

    /// Execute recognized spoken commands (e.g. "scratch that") instead of
    /// pasting them verbatim. Default on.
    var voiceCommandsEnabled: Bool {
        get { defaults.object(forKey: Key.voiceCommandsEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.voiceCommandsEnabled.rawValue) }
    }

    /// Persist each transcription to HistoryStore. Default on; turning this
    /// off stops all writes to history.json.
    var historyEnabled: Bool {
        get { defaults.object(forKey: Key.historyEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.historyEnabled.rawValue) }
    }

    /// Show a floating HUD with a live partial transcript while recording.
    /// Default on.
    var livePreviewEnabled: Bool {
        get { defaults.object(forKey: Key.livePreviewEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.livePreviewEnabled.rawValue) }
    }

    /// Replace spoken punctuation words (e.g. "comma", "titik") with their
    /// symbol equivalents (see SpokenPunctuation). Default off.
    var spokenPunctuationEnabled: Bool {
        get { defaults.object(forKey: Key.spokenPunctuationEnabled.rawValue) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.spokenPunctuationEnabled.rawValue) }
    }

    /// Name of the active AI mode ("Raw" disables post-processing).
    var currentModeName: String {
        get { defaults.string(forKey: Key.currentModeName.rawValue) ?? "Raw" }
        set { defaults.set(newValue, forKey: Key.currentModeName.rawValue) }
    }

    /// Ollama model used when a mode doesn't specify its own.
    var ollamaModel: String {
        get { defaults.string(forKey: Key.ollamaModel.rawValue) ?? "llama3.2" }
        set { defaults.set(newValue, forKey: Key.ollamaModel.rawValue) }
    }

    /// Base URL of the local Ollama server used for AI-mode rewriting.
    /// Localhost by default; a malformed stored value falls back to the default
    /// so we never silently point dictation text at a bogus endpoint.
    var ollamaBaseURL: URL {
        let fallback = URL(string: "http://127.0.0.1:11434")!
        guard let stored = defaults.string(forKey: Key.ollamaBaseURL.rawValue),
              let url = URL(string: stored) else {
            return fallback
        }
        return url
    }

    /// Whether the first-run onboarding wizard has been completed. Default
    /// false so new installs see it once; the "Done" button sets it true.
    var hasCompletedOnboarding: Bool {
        get { defaults.object(forKey: Key.hasCompletedOnboarding.rawValue) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue) }
    }

    func availableModels() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.modelsDir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "bin" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Preferred model name ordering, most- to least-capable. Keep in sync
    /// with pickModel's doc comment — this is the single source of truth.
    private static let preferredModelNames = ["large-v3-turbo", "large-v3-turbo-q5_0", "large-v3",
                                               "medium", "small", "base", "tiny"]

    /// Pure model-selection logic, factored out of resolveModelURL() so it's
    /// testable without touching disk. Selection order:
    /// 1. `explicitPath`, if `explicitPathExists` is true (caller has already
    ///    checked FileManager, or pre-validated some other way).
    /// 2. The best-named match in `userModels` per `preferredModelNames`.
    /// 3. The first entry of `userModels` (matches availableModels() sort order).
    /// 4. `bundledStarter`, the small model shipped inside the app bundle.
    /// Returns nil only when every input is empty/missing.
    static func pickModel(explicitPath: String?, explicitPathExists: Bool,
                           userModels: [URL], bundledStarter: URL?) -> URL? {
        if let path = explicitPath, explicitPathExists {
            return URL(fileURLWithPath: path)
        }
        for name in preferredModelNames {
            if let hit = userModels.first(where: { $0.lastPathComponent == "ggml-\(name).bin" }) {
                return hit
            }
        }
        if let first = userModels.first {
            return first
        }
        return bundledStarter
    }

    /// First `ggml-*.bin` found directly inside the app bundle's
    /// `Resources/models/` directory, i.e. the small starter model bundled
    /// for instant-dictation-on-first-launch. nil for bare CLI/dev builds
    /// that have no app bundle (Bundle.main.resourceURL is nil there).
    static var bundledStarterURL: URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let modelsDir = resources.appendingPathComponent("models", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: modelsDir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "bin" && $0.lastPathComponent.hasPrefix("ggml-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first
    }

    /// True if `url` lives under `resourceURL` (the app bundle's Resources
    /// directory) — i.e. it's the bundled starter model, not a user-downloaded
    /// one in modelsDir. Pure/testable form; `isBundledStarter(_:)` below
    /// supplies the real Bundle.main.resourceURL.
    static func isBundledStarter(_ url: URL, under resourceURL: URL?) -> Bool {
        guard let resourceURL else { return false }
        let resourcePath = resourceURL.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        return candidatePath.hasPrefix(resourcePath + "/")
    }

    static func isBundledStarter(_ url: URL) -> Bool {
        isBundledStarter(url, under: Bundle.main.resourceURL)
    }

    func resolveModelURL() -> URL? {
        Self.pickModel(
            explicitPath: modelPath,
            explicitPathExists: modelPath.map { FileManager.default.fileExists(atPath: $0) } ?? false,
            userModels: availableModels(),
            bundledStarter: Self.bundledStarterURL)
    }

    static let languages: [(code: String, name: String)] = [
        ("auto", "Auto-detect"),
        ("mixed", "Mixed (Indonesian + English)"),
        ("en", "English"), ("id", "Indonesian"), ("zh", "Chinese"), ("es", "Spanish"),
        ("fr", "French"), ("de", "German"), ("ja", "Japanese"), ("ko", "Korean"),
        ("pt", "Portuguese"), ("ru", "Russian"), ("ar", "Arabic"), ("hi", "Hindi"),
        ("it", "Italian"), ("nl", "Dutch"), ("tr", "Turkish"), ("vi", "Vietnamese"),
        ("th", "Thai"), ("ms", "Malay"), ("pl", "Polish"), ("uk", "Ukrainian"),
        ("sv", "Swedish"), ("tl", "Tagalog")
    ]

    static func displayName(forModel url: URL) -> String {
        var name = url.deletingPathExtension().lastPathComponent
        if name.hasPrefix("ggml-") { name.removeFirst(5) }
        return name
    }
}
