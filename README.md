# MyWhisper

Local, multilingual voice dictation for macOS, living in your menu bar.
Press a hotkey, speak in any of ~100 languages, and the transcribed text is
pasted into whatever app you're using. **Everything runs on-device**
(whisper.cpp with Metal acceleration) — no audio or text ever leaves your Mac.

Apple Silicon · macOS 13+ · free.

## Features

- **Global hotkey dictation** — tap ⌥Space to record, tap again to
  transcribe and paste; or **hold** to talk while held.
- **~100 languages**, auto-detected, plus a dedicated **Mixed
  (Indonesian + English)** mode for code-switched speech.
- **Live preview** — a floating HUD shows words as you speak.
- **Voice commands** — "scratch that" / "batalkan" → undo, "new line",
  "new paragraph" (and Indonesian equivalents).
- **Spoken punctuation** (opt-in) — say "koma"/"comma", "titik"/"period",
  "tanda tanya"/"question mark"; auto-capitalizes after sentence enders.
- **AI modes** — rewrite dictation as an email, message, or bullet notes
  through a **local** Ollama model. Still fully offline.
- **Two engines** — a managed `whisper-server` subprocess (default) or an
  in-process libwhisper backend. Switch in the menu.
- **History, custom vocabulary, text replacements, translate-to-English,
  auto-stop on silence, launch at login**, and a Settings window (⌘,).
- **Private by design** — see [Privacy](#privacy) below.

## Install (the easy way — DMG)

For using the app (no developer tools needed):

1. Open **`MyWhisper-0.1.0.dmg`** and drag **MyWhisper.app** into your
   Applications folder.
2. Double-click **"Download Model.command"** to fetch the speech model
   (~1.5 GB, one time). If macOS blocks it: right-click the file → **Open**
   → **Open**.
3. Open **MyWhisper.app**. Because this free build isn't notarized by Apple,
   macOS blocks it the first time:
   → **System Settings → Privacy & Security** → scroll down →
   *"MyWhisper.app was blocked…"* → **Open Anyway**.
4. Grant the two permissions it requests:
   - **Microphone** — to hear you.
   - **Accessibility** (System Settings → Privacy & Security →
     Accessibility) — to paste into other apps. Without it, transcripts are
     still copied to the clipboard; paste manually with ⌘V.

That's it — tap **⌥Space** and start dictating.

> The DMG is produced from source with `make dist` (see
> [Build from source](#build-from-source)).

## How it works

```
⌥Space ──▶ Recorder (mic → 16 kHz mono PCM)
                │ stop (⌥Space again, release, or auto-stop on silence)
                ▼
        Transcription engine (local, Metal-accelerated whisper.cpp)
          • whisper-server subprocess on 127.0.0.1  (default), or
          • in-process libwhisper
                │ raw text
                ▼
        DictationPipeline: clean → replacements → voice-command? →
        spoken punctuation → optional AI-mode rewrite (local Ollama)
                │ final text
                ▼
        Paste into the frontmost app (your clipboard is preserved)
```

The menu bar app spawns and manages the local engine, so the model loads
once and each dictation is fast.

## Usage

- **Tap ⌥Space** — start recording (the menu-bar waveform turns red and
  dances with your voice); tap again to stop, transcribe, and paste.
- **Hold ⌥Space** — record only while held; release to transcribe.
- Open **Settings with ⌘,**, or use the menu-bar menu. Both expose:
  - **Language** — a fixed language, *Auto-detect* (default), or
    **Mixed (Indonesian + English)** for code-switching. Pair Mixed with
    `vocabulary` entries (below) for your names/jargon; Indonesian also gets
    automatic punctuation priming.
  - **Model** — switch between downloaded models (the engine restarts).
  - **Engine** — *Server (subprocess)* (default) or *In-Process
    (experimental)*.
  - **Mode** — *Raw* (default, no rewrite) or an AI mode (see below).
  - **Change Hotkey…** — press any new combination; applies instantly.
  - Toggles: **Sound Cues**, **Auto-Stop After Silence** (~2 s, off by
    default), **Voice Commands**, **Spoken Punctuation** (off by default),
    **Live Preview**, **Translate to English**, **Save History**,
    **Launch at Login**.
  - **History…** — past transcripts; double-click to copy. Capped at 200,
    stored locally; turn off with *Save History*.
  - **Edit Text Replacements… / Edit Modes…** — open the JSON config files.

### Text replacements & vocabulary

`~/Library/Application Support/MyWhisper/replacements.json`:

```json
{
  "vocabulary": ["MyWhisper", "whisper.cpp", "Jakarta"],
  "replacements": [{"find": "my whisper", "replace": "MyWhisper"}]
}
```

- `vocabulary` biases recognition toward your terms (fed to whisper as the
  initial prompt) — especially effective in **Mixed** mode.
- `replacements` are case-insensitive literal fixes applied to every
  transcript.

### AI modes (local LLM, still offline)

Modes rewrite your dictation through an [Ollama](https://ollama.com) model on
`127.0.0.1:11434` — e.g. speak casually and paste a polished email body. AI
mode is **off by default** (mode *Raw*); nothing is sent anywhere until you
pick a mode.

**One-time Ollama setup:**

```sh
brew install ollama          # or download from https://ollama.com
ollama serve                 # start the local server (if not already running)
ollama pull llama3.2         # a small chat model (~2 GB); pick any chat model
```

Then in MyWhisper: menu → **Mode** → *Email* (or *Message* / *Bullet Notes* /
your own).

Modes live in `~/Library/Application Support/MyWhisper/modes.json` (a plain
array). Placeholders `{app}` and `{selection}` are filled with the frontmost
app's name and your currently selected text:

```json
[
  {"name": "Email",  "prompt": "Rewrite the dictated text as a clear, polite email body. Keep the input language. Output only the rewritten text."},
  {"name": "Reply",  "prompt": "Draft a reply appropriate for {app}. The user had this selected: {selection}. Output only the reply."}
]
```

Optional per-mode `"model"`; otherwise the `ollamaModel` default (`llama3.2`)
is used. **Safety:** before sending any text, MyWhisper probes the endpoint's
identity (`/api/version`) and refuses if it isn't Ollama. If the model is
unreachable or errors, you're notified and the **raw transcript is pasted
instead** — your dictation is never lost. Point at a different host with
`defaults write com.ronimoe.mywhisper ollamaBaseURL "http://127.0.0.1:11434"`.

### CLI mode

```sh
.build/release/MyWhisper --transcribe recording.wav \
    [--language <code|auto|mixed>] [--translate] \
    [--mode <name>] [--engine server|inprocess]
```

Transcribes a 16 kHz mono WAV and prints the text — handy for scripting and
end-to-end testing. Flags default to your saved settings.

## Models

Download with `make model MODEL=<name>` (or `scripts/download-model.sh`).
Models live in `~/Library/Application Support/MyWhisper/models/`; switch
between downloaded ones from the **Model** menu.

| Model            | Size      | Multilingual quality | Notes                    |
|------------------|-----------|----------------------|--------------------------|
| tiny / base      | 75–142 MB | poor                 | quick tests only         |
| small            | 466 MB    | okay                 | fast on any machine      |
| medium           | 1.5 GB    | good                 |                          |
| large-v3-turbo   | 1.5 GB    | near-best            | **recommended default**  |
| large-v3         | 2.9 GB    | best                 | slower; can translate    |

Quantized variants (e.g. `large-v3-turbo-q5_0`) trade a little accuracy for
less RAM. Whisper large-v3 covers ~100 languages including Indonesian,
Javanese, Chinese, Japanese, Arabic, Hindi, and all major European languages.

> **Translate to English** uses whisper's built-in translation. Note that
> `large-v3-turbo` is distilled for transcription and **cannot translate** —
> use `large-v3`, `medium`, or smaller for that toggle.

## Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`) and, for the
transcription engine, either Homebrew's `whisper-cpp` or a vendored build.

```sh
brew install whisper-cpp        # transcription engine (quickest path)
make model                      # download ggml-large-v3-turbo (1.5 GB)
make run                        # build MyWhisper.app and launch it
```

Other targets:

```sh
make build     # swift build -c release
make app       # assemble build/MyWhisper.app (ad-hoc / self-signed)
make test      # run the XCTest suite (see Testing)
make deps      # build a self-contained whisper-server into vendor/ (needs cmake)
make dist      # produce build/MyWhisper-<version>.dmg for distribution
```

The app resolves its engine binary in this order: `$MYWHISPER_SERVER` →
bundled `Resources/bin/whisper-server` → `vendor/whisper.cpp/build/bin/` →
Homebrew. `make dist` bundles the vendored server so the DMG is
self-contained on machines without Homebrew.

> The app is signed with a self-signed local certificate ("MyWhisper Dev"),
> so Accessibility grants survive rebuilds. Distributing to other Macs still
> requires the "Open Anyway" step until the build is notarized (which needs a
> paid Apple Developer account).

## Configuration

Settings are stored in `defaults` under `com.ronimoe.mywhisper`:

```sh
# change the hotkey, e.g. ⌃⌥D (keycode 2, control+option = 4096+2048)
defaults write com.ronimoe.mywhisper hotKeyCode -int 2
defaults write com.ronimoe.mywhisper hotKeyModifiers -int 6144

# change the local server port (default 8178)
defaults write com.ronimoe.mywhisper serverPort -int 9090
```

Key codes are Carbon virtual key codes; modifiers cmd=256, shift=512,
option=2048, control=4096 (add to combine). Most of this is also in the
Settings window.

## Project layout

```
Sources/MyWhisper/
  main.swift                  entry point + CLI arg parsing
  AppDelegate.swift           wires everything together
  DictationPipeline.swift     shared pipeline: clean → replace → command →
                              punctuation → AI rewrite (unit-tested core)
  Recorder.swift              AVAudioEngine capture → 16 kHz mono + mic level
  SilenceDetector.swift       voice-activity auto-stop (pure, tested)
  WavWriter.swift / WavReader.swift   PCM ⇄ WAV
  TranscriptionEngine.swift   engine protocol + shared state enum
  WhisperServerManager.swift  whisper-server subprocess + HTTP client
  WhisperEngine.swift         in-process libwhisper backend
  CodeSwitch.swift            mixed-language + Indonesian punctuation priming
  SpokenPunctuation.swift     "koma"/"comma" → symbols (pure, tested)
  VoiceCommands.swift         command matching (pure, tested)
  Lexicon.swift               vocabulary + replacements (cached)
  Modes.swift                 AI modes + Ollama client + identity probe
  ModeContext.swift           {app}/{selection} capture + substitution
  HistoryStore.swift          transcript history (owner-only file)
  PartialScheduler.swift      live-preview pacing (pure, tested)
  PreviewHUD.swift            floating live-preview panel
  HotKeyManager.swift         global hotkey (Carbon)
  HotKeyRecorder.swift        capture a new hotkey combo
  StatusItemController.swift  menu-bar UI + waveform icon
  MenuBarIcon.swift           voice-reactive waveform drawing
  SettingsWindowController.swift / HistoryWindowController.swift   windows
  Settings.swift              UserDefaults-backed settings
  TextInserter.swift          paste (⌘V) + voice-command keystrokes
  HeadlessRunner.swift        --transcribe CLI pipeline
  Support.swift               output cleanup + notifications
Sources/CWhisper/             libwhisper system-library shim (in-process engine)
Tests/MyWhisperTests/         XCTest suite (see Testing)
scripts/                      model download, .app assembly, DMG build
vendor/whisper.cpp            optional vendored engine (make deps)
```

## Privacy

Everything runs on-device: speech → whisper.cpp on `127.0.0.1`, optional AI
modes → Ollama on `127.0.0.1`. No telemetry, no accounts, no outbound
connections. Before sending audio or text to a local port, the app
authenticates the listener (whisper-server signature; Ollama `/api/version`
probe) so it can't hand your data to another process that happens to be
listening. Config, history, and transcripts are stored owner-only (0700
directory, 0600 files). Full details — and the honest limits of the
`NetworkAuditTests` source lint — in [PRIVACY.md](PRIVACY.md). MIT licensed.

## Testing

`make test` runs the XCTest suite — **192 tests** covering text cleanup, WAV
encode/decode, silence detection, the code-switch/punctuation/voice-command
logic, lexicon, history store, AI-mode request building and identity parsing,
the dictation pipeline, and engine state transitions. (Needs the full Xcode
toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the
bare Command Line Tools lack XCTest.) The mic-capture and hotkey layers are
OS-bound and covered by the end-to-end CLI path (`--transcribe`) plus manual
testing. New features land test-first.

## Roadmap

- [x] Hold-to-talk, voice-activity auto-stop
- [x] AI modes via local Ollama (with endpoint identity check)
- [x] History window, custom vocabulary / text replacements
- [x] Translate-to-English, launch at login, Settings window (⌘,)
- [x] Live streaming preview, voice commands, spoken punctuation
- [x] Mixed-language (code-switching) mode + Indonesian punctuation priming
- [x] Context-aware AI modes ({app}/{selection})
- [x] In-process libwhisper engine (menu → Engine)
- [x] Free-download DMG distribution
- [ ] Notarized distribution build (needs a paid Apple Developer account)
- [ ] Windows/Linux port — scoped in [PORTING.md](PORTING.md)

See [todos.md](todos.md) for pending verifications and future ideas.

## License

MIT for this project's code. whisper.cpp and Ollama are separately licensed.
