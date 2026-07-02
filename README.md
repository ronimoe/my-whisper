# MyWhisper

Local, multilingual voice dictation for macOS, living in your menu bar.
Press a hotkey, speak in any of ~100 languages, and the transcribed text
is pasted into whatever app you're using. **Everything runs on-device**
(whisper.cpp with Metal acceleration); no audio or text ever leaves your Mac.

## How it works

```
⌥Space ──▶ Recorder (mic → 16 kHz mono PCM)
                │ stop (⌥Space again)
                ▼
        whisper-server (localhost, model stays hot in memory,
                        Metal-accelerated whisper.cpp)
                │ text
                ▼
        Paste into frontmost app (clipboard is preserved)
```

The menu bar app spawns and manages a local `whisper-server` process, so the
model loads once and each dictation is fast.

## Quick start

```sh
brew install whisper-cpp        # transcription engine (if not installed)
make model                      # downloads ggml-large-v3-turbo (1.5 GB)
make run                        # builds MyWhisper.app and launches it
```

Grant the two permissions when asked:

1. **Microphone** — to record your voice.
2. **Accessibility** (System Settings → Privacy & Security → Accessibility) —
   to auto-paste into other apps. Without it, transcripts are still copied to
   the clipboard; you paste manually with ⌘V.

Note: the app is ad-hoc signed, so after rebuilding you may need to re-grant
Accessibility (remove and re-add the app in System Settings).

## Usage

- **⌥Space** — start recording (menu bar icon turns red), **⌥Space** again —
  stop, transcribe, and paste.
- Menu bar → **Language** — pick a fixed language or *Auto-detect* (default).
  Auto-detect works well with the large models.
- Menu bar → **Model** — switch between downloaded models (the server
  restarts with the new model).

### CLI mode

```sh
.build/release/MyWhisper --transcribe recording.wav --language auto
```

Transcribes a 16 kHz mono WAV and prints the text. Handy for scripting and
testing.

## Models

Download more with `make model MODEL=<name>` (or `scripts/download-model.sh`).
Models live in `~/Library/Application Support/MyWhisper/models/`.

| Model            | Size   | Multilingual quality | Notes                       |
|------------------|--------|----------------------|-----------------------------|
| tiny / base      | 75–142 MB | poor              | quick tests only            |
| small            | 466 MB | okay                 | fast on any machine         |
| medium           | 1.5 GB | good                 |                             |
| large-v3-turbo   | 1.5 GB | near-best            | **recommended default**     |
| large-v3         | 2.9 GB | best                 | slower                      |

Quantized variants (e.g. `large-v3-turbo-q5_0`) trade a little accuracy for
less RAM. Whisper large-v3 supports ~100 languages including Indonesian,
Javanese, Chinese, Japanese, Arabic, Hindi, and all major European languages.

## Configuration

Settings are stored in `defaults` under `com.ronimoe.mywhisper`:

```sh
# change the hotkey, e.g. to ⌃⌥D (keycode 2, control+option = 4096+2048)
defaults write com.ronimoe.mywhisper hotKeyCode -int 2
defaults write com.ronimoe.mywhisper hotKeyModifiers -int 6144

# change the local server port (default 8178)
defaults write com.ronimoe.mywhisper serverPort -int 9090
```

Key codes are Carbon virtual key codes; modifiers: cmd=256, shift=512,
option=2048, control=4096 (add them to combine).

## Project layout

```
Sources/MyWhisper/
  main.swift                entry point + CLI mode
  AppDelegate.swift         wires everything together
  StatusItemController.swift  menu bar UI
  HotKeyManager.swift       global hotkey (Carbon, no permissions needed)
  Recorder.swift            AVAudioEngine capture → 16 kHz mono
  WavWriter.swift           PCM → WAV encoding
  WhisperServerManager.swift  spawns/monitors whisper-server, HTTP client
  TextInserter.swift        clipboard + ⌘V injection, clipboard restore
  HeadlessRunner.swift      --transcribe CLI pipeline
  Support.swift             output cleanup, notifications
scripts/                    model download, .app assembly
vendor/whisper.cpp          optional vendored engine (make deps)
```

## Roadmap

- [ ] Hold-to-talk mode (press and hold the hotkey)
- [ ] Voice activity detection: auto-stop when you stop speaking
- [ ] AI modes: post-process transcripts with a local LLM via Ollama
      (email tone, message tone, custom prompts) — still fully offline
- [ ] Context awareness (use selected text / active app)
- [ ] History window with past transcripts
- [ ] Custom vocabulary / text replacements
- [ ] Translate-to-English toggle (whisper supports it natively)
- [ ] Settings window (hotkey recorder, language, model manager with
      in-app downloads)
- [ ] In-process engine (link libwhisper directly, drop the server process)
- [ ] Launch at login; signed/notarized distribution build
- [ ] Windows/Linux port (the engine is portable; the capture/paste layer
      would need per-OS implementations)

## License

MIT for this project's code. whisper.cpp is MIT-licensed.
