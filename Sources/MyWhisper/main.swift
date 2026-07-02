import AppKit

let arguments = CommandLine.arguments

if arguments.contains("--help") || arguments.contains("-h") {
    print("""
    MyWhisper — local multilingual dictation for macOS

    Usage:
      MyWhisper                        Run the menu bar app
      MyWhisper --transcribe <wav>     Transcribe a 16 kHz mono WAV file and print the text
          [--language <code|auto>]     Language override (default: saved setting)
          [--translate]                Translate the speech to English
          [--mode <name>]              Rewrite the result with an AI mode (default: saved setting)

    The menu bar app toggles recording with the global hotkey (default ⌥Space),
    transcribes locally with whisper.cpp, and pastes the result into the
    frontmost application. Nothing ever leaves this Mac.
    """)
    exit(0)
}

if let index = arguments.firstIndex(of: "--transcribe") {
    guard arguments.count > index + 1 else {
        FileHandle.standardError.write(Data("--transcribe requires a WAV file path\n".utf8))
        exit(1)
    }
    let wavPath = arguments[index + 1]
    var language = Settings.shared.language
    if let langIndex = arguments.firstIndex(of: "--language"), arguments.count > langIndex + 1 {
        language = arguments[langIndex + 1]
    }
    let translate = arguments.contains("--translate") || Settings.shared.translateToEnglish
    var modeName = Settings.shared.currentModeName
    if let modeIndex = arguments.firstIndex(of: "--mode"), arguments.count > modeIndex + 1 {
        modeName = arguments[modeIndex + 1]
    }
    exit(HeadlessRunner().run(wavPath: wavPath, language: language, translate: translate, modeName: modeName))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
