# MyWhisper

macOS menu-bar dictation app: global hotkey → record → transcribe locally via
whisper.cpp (`whisper-server` subprocess on localhost:8178) → paste into the
frontmost app. Swift Package Manager, AppKit, no Xcode project.

## Commands

- `swift build -c release` — build the executable
- `make app` — assemble `build/MyWhisper.app` (ad-hoc signed)
- `make run` — build + launch
- `make model MODEL=large-v3-turbo` — download a ggml model
- `.build/release/MyWhisper --transcribe file.wav [--language xx]` — headless
  end-to-end test (spawns server, transcribes a 16 kHz mono WAV, prints text)

## Notes

- Engine binary resolution order: `$MYWHISPER_SERVER` env var → bundled
  `Resources/bin/whisper-server` → `vendor/whisper.cpp/build/bin/` →
  Homebrew (`/opt/homebrew/bin/whisper-server`).
- Models live in `~/Library/Application Support/MyWhisper/models/`.
- Server log: `~/Library/Application Support/MyWhisper/whisper-server.log`.
- GUI needs Microphone + Accessibility permissions; ad-hoc signing means
  Accessibility must be re-granted after rebuilds.
- Test WAVs can be synthesized with `say -o test.wav --file-format=WAVE
  --data-format=LEI16@16000 "text"` (Indonesian voice: `-v Damayanti`).
