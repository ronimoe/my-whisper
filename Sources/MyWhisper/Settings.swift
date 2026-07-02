import Foundation

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MyWhisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var modelsDir: URL {
        let dir = appSupportDir.appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Whisper language code, or "auto" for detection, or "mixed" for
    /// code-switched dictation (see CodeSwitch).
    var language: String {
        get { defaults.string(forKey: "language") ?? "auto" }
        set { defaults.set(newValue, forKey: "language") }
    }

    /// Primary language pinned to whisper when `language == "mixed"`.
    var mixedPrimary: String {
        get { defaults.string(forKey: "mixedPrimary") ?? "id" }
        set { defaults.set(newValue, forKey: "mixedPrimary") }
    }

    /// Explicit model path; when nil, the best model found in modelsDir is used.
    var modelPath: String? {
        get { defaults.string(forKey: "modelPath") }
        set { defaults.set(newValue, forKey: "modelPath") }
    }

    var serverPort: Int {
        defaults.object(forKey: "serverPort") as? Int ?? 8178
    }

    /// Transcription backend: "server" (whisper-server subprocess) or
    /// "inprocess" (libwhisper linked directly). Default "server".
    var engine: String {
        get { defaults.string(forKey: "engine") ?? "server" }
        set { defaults.set(newValue, forKey: "engine") }
    }

    /// Carbon virtual key code for the dictation hotkey. Default: Space (49).
    var hotKeyCode: UInt32 {
        defaults.object(forKey: "hotKeyCode") as? UInt32 ?? 49
    }

    /// Carbon modifier mask. cmd=256 shift=512 option=2048 control=4096. Default: Option.
    var hotKeyModifiers: UInt32 {
        defaults.object(forKey: "hotKeyModifiers") as? UInt32 ?? 2048
    }

    /// Human-readable hotkey, shown in menus (e.g. "⌥Space").
    var hotKeyDisplay: String {
        get { defaults.string(forKey: "hotKeyDisplay") ?? "⌥Space" }
        set { defaults.set(newValue, forKey: "hotKeyDisplay") }
    }

    func setHotKey(code: UInt32, modifiers: UInt32, display: String) {
        defaults.set(Int(code), forKey: "hotKeyCode")
        defaults.set(Int(modifiers), forKey: "hotKeyModifiers")
        hotKeyDisplay = display
    }

    /// Play a sound when recording starts/stops. Default on.
    var soundCues: Bool {
        get { defaults.object(forKey: "soundCues") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "soundCues") }
    }

    /// Automatically stop recording after a period of silence. Default off.
    var autoStopEnabled: Bool {
        get { defaults.object(forKey: "autoStopEnabled") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "autoStopEnabled") }
    }

    /// Translate non-English speech to English instead of transcribing verbatim. Default off.
    var translateToEnglish: Bool {
        get { defaults.object(forKey: "translateToEnglish") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "translateToEnglish") }
    }

    /// Execute recognized spoken commands (e.g. "scratch that") instead of
    /// pasting them verbatim. Default on.
    var voiceCommandsEnabled: Bool {
        get { defaults.object(forKey: "voiceCommandsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "voiceCommandsEnabled") }
    }

    /// Show a floating HUD with a live partial transcript while recording.
    /// Default on.
    var livePreviewEnabled: Bool {
        get { defaults.object(forKey: "livePreview") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "livePreview") }
    }

    /// Replace spoken punctuation words (e.g. "comma", "titik") with their
    /// symbol equivalents (see SpokenPunctuation). Default off.
    var spokenPunctuationEnabled: Bool {
        get { defaults.object(forKey: "spokenPunctuationEnabled") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "spokenPunctuationEnabled") }
    }

    /// Name of the active AI mode ("Raw" disables post-processing).
    var currentModeName: String {
        get { defaults.string(forKey: "currentModeName") ?? "Raw" }
        set { defaults.set(newValue, forKey: "currentModeName") }
    }

    /// Ollama model used when a mode doesn't specify its own.
    var ollamaModel: String {
        get { defaults.string(forKey: "ollamaModel") ?? "llama3.2" }
        set { defaults.set(newValue, forKey: "ollamaModel") }
    }

    func availableModels() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.modelsDir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "bin" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func resolveModelURL() -> URL? {
        if let path = modelPath, FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        let models = availableModels()
        let preferred = ["large-v3-turbo", "large-v3-turbo-q5_0", "large-v3",
                         "medium", "small", "base", "tiny"]
        for name in preferred {
            if let hit = models.first(where: { $0.lastPathComponent == "ggml-\(name).bin" }) {
                return hit
            }
        }
        return models.first
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
