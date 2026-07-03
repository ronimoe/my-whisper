# MyWhisper — Product

## Vision

A [superwhisper](https://superwhisper.com)-class dictation experience for
macOS — press a hotkey, talk, get clean text pasted wherever your cursor is
— but **100% local** and **multilingual-first from day one**, not bolted on
later. Every claim of "runs on your Mac" is meant literally: speech
recognition is a `whisper-server`/libwhisper process on `127.0.0.1`, optional
AI rewriting is a local Ollama model on `127.0.0.1:11434`, and the only
network call the app ever makes on its own is a model download you
explicitly click to start (verified in `docs/ARCHITECTURE.md`'s
`NetworkAuditTests` section).

## Differentiators

- **Privacy, with enforcement, not just a promise.** A source-level test
  (`NetworkAuditTests`) fails the build if any file references a
  non-localhost URL outside a pinned, 2-entry allowlist
  (`ModelDownloader.swift` → Hugging Face; `OnboardingWindowController.swift`
  → an outbound browser link only). Both local servers are identity-checked
  before any audio/text is sent to them — a bind-probe + `Server:
  whisper.cpp` header check for the transcription engine, an `/api/version`
  shape check for Ollama — so MyWhisper can't be tricked into handing
  dictation to an unrelated process squatting on the expected port.
- **Code-switching packs, not just "auto-detect."** Whisper accepts one
  `language` per request, so genuinely mixed speech (a sentence hopping
  between two languages mid-thought) has no native "detect both" mode. Five
  dedicated packs (`mixed` = Indonesian+English, plus Tagalog, Hindi,
  Spanish, Chinese pairs) each pin a primary language and prime the decoder
  with a natural, code-switched example sentence, rather than forcing every
  word into one language.
- **Per-app profiles.** `profiles.json` lets language/mode/punctuation/
  translate be overridden per frontmost app (by name or bundle ID) —
  dictate casually into Slack, formally into Mail, with zero punctuation
  noise into Terminal, without touching global settings each time.
- **Self-learning corrections.** History → select a bad transcript →
  Correct… → MyWhisper diffs your edit against the original
  (`CorrectionDiff.suggestRule`, prefix/suffix trimmed to word boundaries)
  and saves a reusable find→replace rule automatically — no manual JSON
  editing required for the common case, though the file remains hand-editable.
- **Free.** No account, no subscription, no server costs to the maintainer
  (everything runs on the user's own hardware).

## Target users

- Anyone who wants voice dictation across macOS apps without sending audio
  to a cloud vendor.
- **Multilingual speakers**, especially those who naturally code-switch
  between English and another language day to day (the Indonesian pack was
  the original design center; four more pairs now exist).
- Developers/power users comfortable editing a JSON file to customize
  vocabulary, AI-mode prompts, or per-app behavior — the UI covers the common
  path, but nothing is locked behind a GUI-only config.

## Feature inventory as shipped

Grouped to match the project's own versioning language in `todos.md` and
prior review notes; every item below is verified present in the current
source (file paths in parentheses).

**v1 — core dictation loop**
- Global hotkey, tap-to-toggle and hold-to-talk (0.35s threshold)
  (`AppDelegate.hotKeyDown/hotKeyUp`)
- Local transcription via `whisper-server` subprocess (`WhisperServerManager`)
- Menu-bar status icon with live waveform animation (`MenuBarIcon`,
  `StatusItemController`)
- Clipboard-preserving paste via Accessibility (`TextInserter`)
- ~100-language support via whisper.cpp, with a curated language picker
  (`Settings.languages`)
- Model management: download, switch, list (`ModelDownloader`,
  `Settings.availableModels`)

**v1.5 — quality-of-life + power features**
- Hold-to-talk, voice-activity auto-stop (`SilenceDetector`)
- History window with copy + clear (`HistoryWindowController`,
  `HistoryStore`)
- Custom vocabulary + text replacements (`Lexicon`)
- Translate-to-English toggle, Launch at Login, Settings window (⌘,)
  (`SettingsWindowController`)
- Live streaming preview HUD (`RecordingPill`, `PartialScheduler`)
- Voice commands ("scratch that", "new line", "new paragraph", en+id)
  (`VoiceCommands`)
- Spoken punctuation, en+id, with capitalization rules
  (`SpokenPunctuation`)
- Mixed-language (Indonesian+English) code-switching mode + Indonesian
  punctuation priming (`CodeSwitch`)

**v2 — AI modes, engines, distribution, per-app context**
- AI modes rewriting dictation via local Ollama, with endpoint identity
  verification and raw-text fallback on failure (`Modes.swift`)
- Context-aware AI modes: `{app}`/`{selection}` placeholders substituted
  from the captured frontmost app and Accessibility text selection
  (`ModeContext`)
- In-process libwhisper engine as an alternative to the subprocess
  (`WhisperEngine`), selectable from the menu
- Per-app dictation profiles (`AppProfiles.swift`)
- Self-learning corrections from History (`CorrectionDiff`)
- Instant paste / fast-finalize: reuses a live-preview partial as the final
  transcript when safe, skipping full re-transcription (`FastFinalize.swift`)
- File transcription ("Transcribe Audio File…") with a dedicated transcript
  window (`TranscriptWindowController`, `AudioFileDecoder`)
- First-run Setup Assistant covering permissions, model download, and a
  no-terminal Ollama/AI-mode setup flow (`OnboardingWindowController`)
- Free-download DMG distribution with a bundled starter model so a fresh
  install can dictate immediately (`scripts/make-dist.sh`)
- Additional mixed-language packs: Tagalog, Hindi, Spanish, Chinese
  (`CodeSwitch.pairs`)
- CLI mode for scripting/testing (`main.swift --transcribe`,
  `HeadlessRunner`)
- 310-test XCTest suite with a source-level privacy lint
  (`NetworkAuditTests`)

## Roadmap (v3 candidates, from `todos.md`)

- **Meeting mode** — system-audio capture (ScreenCaptureKit), speaker
  diarization (tinydiarize), local-LLM meeting summaries.
- **Developer-first surface** — stdin/pipe CLI mode, an AppleScript/URL
  scheme for automation, code-aware formatting (e.g. dictating identifiers
  in camelCase/snake_case).
- **Windows/Linux port** — fully scoped in `docs/PORTING.md` (recommended
  stack: Tauri 2 + Rust core, reusing the existing `whisper-server` HTTP
  protocol and porting the pure-logic layer's unit tests as the acceptance
  spec).
- **Auto-update** (e.g. Sparkle) — deliberately deferred until after
  notarization exists, since auto-update needs a stable Developer ID
  signature to be trustworthy.
- Tightening `modes.json`/`profiles.json` writes to 0600 (currently created
  without an explicit permission call, unlike `history.json`/
  `replacements.json` — noted as a follow-up in `todos.md`).

## Open decisions

- **Pricing/positioning** — explicitly undecided; `todos.md` lists this as
  a pre-launch decision, not yet made.
- **Public-repo flip** — whether/when this repository goes public is not
  yet decided in any source file reviewed for this doc.
- **Notarized distribution** — prepared end-to-end (`scripts/notarize.sh`,
  `docs/RELEASE.md`) but **blocked** on enrolling in the paid Apple
  Developer Program ($99/yr); until then, every install requires the
  "Open Anyway" Gatekeeper step, and every rebuild from source requires
  re-granting Accessibility (see `docs/ARCHITECTURE.md`'s known
  limitations).
