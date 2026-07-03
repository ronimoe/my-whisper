# MyWhisper

A macOS menu-bar app for local voice dictation: tap a hotkey, speak in any
of ~100 languages, and the transcribed text is pasted into whatever app
you're using. Speech recognition runs entirely on-device via whisper.cpp —
no audio or text ever leaves your Mac.

Apple Silicon · macOS 13+ · free.

## Key features

- **Global hotkey dictation** — tap to toggle, or hold to talk while held.
- **~100 languages**, auto-detect, plus five **Mixed-language** code-switching
  packs (Indonesian, Tagalog, Hindi, Spanish, Chinese + English).
- **Live preview**, **voice commands**, **spoken punctuation**, and
  **instant paste** (reuses the live preview to skip re-transcription).
- **Per-app dictation profiles** — different language/mode/punctuation per
  frontmost app.
- **AI modes** — rewrite dictation as an email, message, or bullet notes via
  a **local** Ollama model. Still fully offline.
- **Self-learning corrections** — fix a transcript once in History, and
  MyWhisper learns a reusable replacement rule.
- **Two transcription engines** — a managed subprocess (default) or an
  in-process backend — switchable from the menu.
- **History, custom vocabulary, text replacements, translate-to-English,
  file transcription, a CLI, and a Settings window (⌘,).**
- **Private by design**, with a source-level test enforcing it — see
  [PRIVACY.md](PRIVACY.md).

## Install — quick start

**DMG (no developer tools needed):**

1. Open the DMG and drag **MyWhisper.app** into Applications.
2. Open it — since this free build isn't notarized, macOS will block it
   once: **System Settings → Privacy & Security → Open Anyway**.
3. Grant **Microphone** and **Accessibility** when prompted (or via the
   in-app Setup Assistant).
4. Tap **⌥Space** and start dictating — a small starter model is bundled,
   so it works immediately.

**Build from source:**

```sh
brew install whisper-cpp   # transcription engine
make model                 # download the recommended speech model
make run                   # build MyWhisper.app and launch it
```

Full walkthroughs (permissions, the Setup Assistant, every menu item and
setting) are in the [User Guide](docs/USER-GUIDE.md).

## Documentation

| Doc | What's in it |
|---|---|
| [docs/USER-GUIDE.md](docs/USER-GUIDE.md) | Complete beginner-friendly guide: install, first dictation, every menu item and setting, languages, voice commands, AI modes, history, the CLI, troubleshooting |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design for developers: data flow, the two engines, concurrency model, file/permission model, source-file map, test strategy |
| [docs/PRODUCT.md](docs/PRODUCT.md) | Vision, differentiators, target users, shipped feature inventory, roadmap, open decisions |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Build prerequisites, every Makefile target, scripts reference, conventions, how-to recipes for common changes |
| [docs/RELEASE.md](docs/RELEASE.md) | How to build and ship a DMG, free and notarized |
| [docs/PORTING.md](docs/PORTING.md) | Honest scoping for a Windows/Linux port |
| [PRIVACY.md](PRIVACY.md) | What runs where, what never happens, how it's checked |
| [LICENSE](LICENSE) | MIT license |
| [todos.md](todos.md) | Pending verifications and future-release ideas |

## Models

| Model | Size | Multilingual quality | Notes |
|---|---|---|---|
| tiny / base | 75–142 MB | poor | quick tests only |
| small | 466 MB | okay | fast on any machine |
| medium | 1.5 GB | good | |
| large-v3-turbo | 1.5 GB | near-best | **recommended default**, bundled starter is a smaller sibling |
| large-v3 | 2.9 GB | best | slower; the only tier that can translate |

Download with `make model MODEL=<name>` or the in-app Setup Assistant.
Quantized variants (e.g. `large-v3-turbo-q5_0`) trade a little accuracy for
less RAM. `large-v3-turbo` **cannot translate** — use `large-v3`/`medium`
for the Translate-to-English toggle.

## Testing

**310 tests** pass via `make test` (needs the full Xcode toolchain —
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the bare Command
Line Tools lack XCTest). See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#test-strategy)
for the test strategy.

## Privacy

Everything runs on-device — speech recognition and AI-mode rewriting both
talk only to `127.0.0.1`, and a source-level test fails the build if any
other network endpoint appears in the app. Full details in
[PRIVACY.md](PRIVACY.md). MIT licensed.
