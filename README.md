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

- **Tap ⌥Space** — start recording (waveform turns red and dances with your
  voice); tap again to stop, transcribe, and paste.
- **Hold ⌥Space** — record only while held; release to transcribe (hold-to-talk).
- Everything else lives in the menu bar menu:
  - **Language** — fixed language or *Auto-detect* (default; reliable with
    the large models).
  - **Model** — switch between downloaded models (server restarts).
  - **Mode** — post-process dictation with a local LLM via Ollama
    (Email / Message / Bullet Notes / your own); see *AI modes* below.
  - **Change Hotkey…** — press any new combo; applies instantly.
  - **Sound Cues** — pop on start, tink on stop.
  - **Auto-Stop After Silence** — hands-free stop ~2 s after you finish
    speaking (off by default).
  - **Translate to English** — whisper's built-in translation. Note:
    `large-v3-turbo` cannot translate (distilled for transcription only);
    use `large-v3`, `medium`, or smaller.
  - **History…** — past transcripts; double-click to copy. Stored locally in
    `history.json`, capped at 200 entries.
  - **Edit Text Replacements…** — auto-corrections applied to every
    transcript, plus vocabulary hints fed to whisper (see below).
  - **Launch at Login** — via SMAppService (bundled app only).

### Text replacements & vocabulary

`~/Library/Application Support/MyWhisper/replacements.json`:

```json
{
  "vocabulary": ["MyWhisper", "whisper.cpp"],
  "replacements": [{"find": "my whisper", "replace": "MyWhisper"}]
}
```

`vocabulary` biases recognition toward your terms (sent as whisper's initial
prompt); `replacements` are case-insensitive literal fixes applied to every
transcript.

### AI modes (local LLM, still offline)

Modes rewrite your dictation through an Ollama model served on
`127.0.0.1:11434` — e.g. speak casually, paste a polished email body.
`~/Library/Application Support/MyWhisper/modes.json` is a plain array:

```json
[
  {"name": "Email", "prompt": "Rewrite the dictated text as a clear, polite email body. Keep the language of the input. Output only the rewritten text."}
]
```

Optional per-mode `"model"`; otherwise the `ollamaModel` default
(`llama3.2`) is used. Setup: `brew install ollama && ollama pull llama3.2`.
If the LLM is unreachable or errors, MyWhisper notifies you and pastes the
raw transcript — your dictation is never lost.

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

## Testing

`make test` runs the XCTest suite (57 tests: text cleanup, WAV encoding,
silence detection, lexicon, history store, modes, request building). The
mic-capture and hotkey layers are OS-bound and covered by the end-to-end CLI
path (`--transcribe`) and manual testing instead. New features land
test-first.

## Roadmap

- [x] Hold-to-talk mode (press and hold the hotkey)
- [x] Voice activity detection: auto-stop when you stop speaking
- [x] AI modes: post-process transcripts with a local LLM via Ollama
- [x] History window with past transcripts
- [x] Custom vocabulary / text replacements
- [x] Translate-to-English toggle
- [x] Launch at login
- [ ] Context awareness (use selected text / active app)
- [ ] Settings window (hotkey recorder, language, model manager with
      in-app downloads)
- [ ] Streaming preview (see words while you speak)
- [ ] In-process engine (link libwhisper directly, drop the server process)
- [ ] Signed/notarized distribution build
- [ ] Windows/Linux port (the engine is portable; the capture/paste layer
      would need per-OS implementations)

## License

MIT for this project's code. whisper.cpp is MIT-licensed.
