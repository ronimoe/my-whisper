# MyWhisper — Architecture

For developers (and future-you) working on the codebase. Every claim below
is verified against the current source, not carried over from old docs.

---

## System overview

MyWhisper is a macOS menu-bar app (AppKit, `LSUIElement` accessory app, no
Dock icon) built with Swift Package Manager — there is no Xcode project.
It captures microphone audio on a global hotkey, transcribes it locally via
whisper.cpp, optionally rewrites it through a local Ollama LLM, and pastes
the result into whatever app was frontmost.

```
                          ┌────────────────────────┐
                          │   StatusItemController   │  menu bar UI
                          │  SettingsWindowController │  ⌘, window
                          │ OnboardingWindowController│  first-run wizard
                          │  HistoryWindowController  │  history browser
                          │TranscriptWindowController │  file-transcript view
                          └───────────┬────────────┘
                                      │ callbacks
┌──────────────┐    hotkey down/up   ▼
│ HotKeyManager │───────────────▶┌─────────────┐        ┌────────────────┐
│  (Carbon)     │                │ AppDelegate │◀──────▶│  RecordingPill  │
└──────────────┘                │ (orchestr.) │        │ (floating HUD) │
                                 └──────┬──────┘        └────────────────┘
                                        │ start/stop
                                        ▼
                                  ┌───────────┐   16kHz mono Float32
                                  │  Recorder │───────────┐
                                  │(AVAudioEngine)         │
                                  └───────────┘            ▼
                                                  ┌──────────────────────┐
                                                  │ TranscriptionEngine  │  protocol
                                                  │ ┌──────────────────┐ │
                                                  │ │WhisperServerManager│ subprocess + HTTP
                                                  │ ├──────────────────┤ │
                                                  │ │   WhisperEngine   │ in-process libwhisper
                                                  │ └──────────────────┘ │
                                                  └──────────┬───────────┘
                                                             │ raw transcript
                                                             ▼
                                                 ┌────────────────────────┐
                                                 │   DictationPipeline    │
                                                 │ clean → lexicon →      │
                                                 │ voice-command? →       │
                                                 │ spoken punctuation →   │
                                                 │ AI-mode rewrite (Ollama)│
                                                 └───────────┬────────────┘
                                                             │ DictationResult
                                                             ▼
                                                     ┌───────────────┐
                                                     │ TextInserter  │  ⌘V paste,
                                                     │               │  command keystrokes
                                                     └───────────────┘
```

Supporting, mostly-pure modules feeding the pipeline: `Lexicon` (vocabulary +
replacements), `CodeSwitch` (mixed-language request params), `AppProfiles`
(per-app overrides), `ModeContext` (frontmost app + selection capture),
`VoiceCommands`, `SpokenPunctuation`, `Postprocess`, `FastFinalize`,
`PartialScheduler`, `SilenceDetector`, `HistoryStore`, `CorrectionDiff`.

---

## Dictation data flow: hotkey → paste

Exact order, matching `AppDelegate.swift` and `DictationPipeline.swift`:

1. **Hotkey down** (`HotKeyManager.onHotKeyDown`) → `AppDelegate.hotKeyDown()`.
   If already recording, this is a "tap to stop" — calls `finishDictation()`.
   Otherwise it's "tap to start": records `lastPressDate`, sets
   `pressStartedRecording = true`, calls `beginDictation()`.
2. **`beginDictation()`**:
   - Guards on `!isTranscribing` (re-entrancy guard, see Concurrency below)
     and the engine being `.ready`.
   - Captures **context** and **profile** right here, at the start, not at
     the end: `dictationContext = ModeContext.capture()` (frontmost app name,
     bundle ID, current Accessibility text selection) and
     `activeProfile = AppProfileStore.match(...)` against that captured app.
     This means the app you were in *when you started talking* determines
     the profile — switching apps mid-dictation doesn't change it.
   - Clears `lastPartial`, starts `Recorder` (which resamples mic input to
     16 kHz mono Float32 via `AVAudioConverter`), shows `RecordingPill` with
     a caption computed from the *effective* (profile-merged) language/mode,
     registers the secondary Escape hotkey (armed only while recording), and
     — if Live Preview is on — starts the preview timer.
3. **Recording** continues until: a second hotkey tap/release past the 0.35s
   hold threshold, the menu's "Stop & Transcribe", Escape/pill-✕ (cancel —
   see below), or `SilenceDetector` firing auto-stop (if enabled).
4. **Live preview** (if on), every ~1.5s (`PartialScheduler`, gated on
   ≥1s of audio and no preview already in flight): snapshots up to the last
   30 seconds of samples (`previewWindowSamples = 30 * 16000`), builds
   `CodeSwitch` request params, transcribes that snapshot through the same
   engine, and updates the pill's text. Critically, it also records a
   `FastFinalize.Partial(sampleCount, rawText)` — but **only** when the
   snapshot at request time covered the *entire* recording so far (i.e.
   `sampleCountAtRequest <= previewWindowSamples`); once a recording exceeds
   the window, `lastPartial` is cleared instead, since a partial that missed
   audio can no longer stand in for the whole thing.
5. **Hotkey up / stop** → `finishDictation()`:
   - Stops the preview timer (cancelling any in-flight preview `Task`), hides
     the pill, unregisters the secondary Escape key, stops the `Recorder`
     (returning all captured samples).
   - Recordings under 0.2s (3200 samples) are silently dropped as idle —
     no transcription, no error.
   - Resolves **effective** settings via `EffectiveDictation.resolve(...)`
     (base `Settings` merged with `activeProfile`, profile fields winning
     when non-nil).
   - **Fast-finalize branch**: computes `tailRMS` of samples after the
     partial's sample count, and checks
     `FastFinalize.shouldReuse(partial:totalSamples:tailRMS:)` — true only if
     a partial exists with non-empty text, the recording hasn't shrunk below
     the partial's snapshot, the tail is ≤12,000 samples (~0.75s), and that
     tail is quiet (RMS < 0.005). If so (and the Settings toggle
     `fastFinalizeEnabled` is on), it calls the **static**
     `DictationPipeline.run(rawTranscript:...)` overload directly on the
     partial's already-transcribed text — skipping the engine call
     entirely. Otherwise it calls the instance `pipeline.run(samples:...)`,
     which re-transcribes the full recording from scratch.
   - Both branches converge on the same private
     `finishFromRawTranscript(...)`: `DictationPipeline.process(...)` (clean
     → lexicon → voice-command check → spoken punctuation), then, only for
     `.text` outcomes in a non-`"Raw"` mode, an Ollama rewrite (with `{app}`/
     `{selection}` substituted into the mode prompt first) that falls back to
     the un-rewritten text on any failure, surfacing the error via
     `DictationResult.aiFailure`.
   - On the main actor: `.command` outcomes are executed via
     `TextInserter.perform`; `.text` outcomes are pasted via
     `TextInserter.insert` (clipboard-preserving) and, if `historyEnabled`,
     appended to `HistoryStore`; `.empty` does nothing.

**Cancel** (`cancelDictation()`, wired to Escape and the pill's ✕): stops the
recorder and discards its samples outright — no transcription, no pipeline,
no history write, no paste.

---

## The two engines

Both conform to `TranscriptionEngine` (`state`, `onStateChange`, `start()`,
`stop()`, `transcribe(samples:language:translate:prompt:) async throws ->
String`), so `AppDelegate`/`DictationPipeline`/`HeadlessRunner` don't care
which is active.

### `WhisperServerManager` (default: `engine == "server"`)

Owns a `whisper-server` (whisper.cpp) **subprocess**, talked to over
`http://127.0.0.1:<port>` (default port 8178).

- **Start**: before spawning, calls `isPortInUse(port)` — a POSIX bind probe
  (bind, then immediately release if it succeeds) — and refuses to start
  with a `.failed` state if something else already owns that port, rather
  than risk POSTing audio to an unknown listener. Spawns the process with
  `--model`, `--host 127.0.0.1`, `--port`, `--threads`
  (`max(4, coreCount - 2)`), piping stdout/stderr to
  `whisper-server.log`. Polls readiness (see below) up to a 300s deadline.
- **Readiness probe**: GETs `/` and requires whisper.cpp's stable `Server:
  whisper.cpp` response header (present even on 404s) — not just "any HTTP
  response" — as defense-in-depth on top of the port-ownership guarantee
  from the pre-bind check.
- **Transcription**: encodes samples to an in-memory WAV (`WavWriter`),
  POSTs multipart form data (`response_format=json`, `language`,
  `temperature=0.0`, optional `translate`/`prompt`, the WAV as `file`) to
  `/inference`.
- **Stop**: unconditionally sets `.stopped` (authoritative), terminates the
  process.

### `WhisperEngine` (`engine == "inprocess"`, experimental)

Links `libwhisper` directly via the `CWhisper` C shim module and keeps the
model resident **in this process** — no subprocess, no HTTP.

- **Start**: on a private serial `queue`, calls
  `whisper_init_from_file_with_params` (GPU enabled). Publishes the raw
  context pointer under `contextLock`, then promotes to `.ready` only if
  still `.starting`.
- **Transcribe**: dispatches onto the same serial `queue`, builds
  `whisper_full_default_params` (greedy sampling, threads =
  `max(4, coreCount - 2)`), copies `language`/`prompt` into `strdup`-owned
  C-string buffers that outlive the `whisper_full` call, and concatenates
  every resulting segment's text.
- **Stop**: synchronously flips state to `.stopped`, nulls `context` under
  `contextLock`, and dispatches the actual `whisper_free` onto the same
  serial `queue` — guaranteeing it runs strictly after any in-flight or
  already-queued transcription, since that queue is the sole owner of the
  context.

### Adding a third engine

Implement `TranscriptionEngine` (`Sources/MyWhisper/TranscriptionEngine.swift`):
report `.starting` while loading, `.ready` once usable, `.failed(message)`
on error (with a human-readable message — it's shown directly in the menu
bar and Setup Assistant), and `.stopped` after `stop()`. Implement
`transcribe(samples:language:translate:prompt:)` — samples are already
16 kHz mono Float32, so no resampling is needed on your end. Wire it into
`AppDelegate.startServer()`'s `if Settings.shared.engine == "..."` branch and
add a case to `StatusItemController.buildEngineMenu()`'s `options` array and
`Settings.engine`'s doc comment. `HeadlessRunner` has an identical
if/else that needs the same new case for CLI `--engine` support.

---

## Concurrency model

Every shared-mutable-state type in this codebase follows the same
**stateLock / setState / transition** pattern, chosen so `onStateChange`
callbacks — which may themselves read `state` — can never deadlock:

- A private `NSLock` (`stateLock`) guards a private `_state` field.
- `state` is a locked read-only computed property.
- `setState(_:)` is the single unconditional writer: locks, mutates
  `_state`, captures the `onStateChange` callback, **unlocks**, then invokes
  the callback *outside* the lock.
- `transition(to:onlyIf:)` is a compare-and-set: only writes if a predicate
  over the *current* state (evaluated under the same lock) holds, and
  returns whether it happened. This lets an authoritative writer (e.g.
  `stop()` unconditionally setting `.stopped`) win a race against a
  slower background writer (e.g. a termination handler or async load
  trying to promote to `.ready`/`.failed` after the fact) — the late writer's
  `transition` call simply becomes a no-op because the predicate no longer
  holds.

This exact pattern appears in both `WhisperServerManager` and `WhisperEngine`.

**`WhisperEngine` additionally has `contextLock`** (separate from
`stateLock`, **never held nested with it** — see `stop()`'s comment)
guarding the raw `context: OpaquePointer?`. All actual use of the whisper
context (`whisper_init_from_file_with_params`, `whisper_full`,
`whisper_free`) is further serialized onto a private `DispatchQueue`
(`queue`), which is the sole owner of the context — `stop()` doesn't free
synchronously; it nulls the pointer under `contextLock` then dispatches the
free onto `queue`, so it's ordered strictly after any transcription already
running or queued there. `waitForPendingWork()` (`queue.sync {}`) exists so
`HeadlessRunner` can block until that dispatched free has actually run
before the process `exit()`s — otherwise ggml's static teardown could assert
on Metal resources the free hadn't released yet.

**`Recorder`** guards `samples`/`level` with its own `NSLock`; the mic tap
callback runs on a CoreAudio thread and appends samples/updates level under
that lock, while `sampleCount`/`snapshotSamples`/`currentLevel` are read from
the main thread (preview timer, menu bar level meter) through the same lock.

**Main-thread UI rule**: every UI mutation (`StatusItemController`,
`RecordingPill`, window controllers) is dispatched onto the main thread —
engine `onStateChange` callbacks explicitly `DispatchQueue.main.async` before
touching `statusController`; pipeline `Task`s `await MainActor.run` before
touching outcome/UI state.

**Preview `Task` cancellation**: `AppDelegate.previewTask` is captured so
`stopPreviewTimer()` can cancel it; the preview's completion checks
`!Task.isCancelled` before writing to `lastPartial`/the pill, so a preview
in flight when recording stops can't race a stale result into state after
the fact.

**`isTranscribing` re-entrancy guard**: set `true` the moment
`finishDictation` commits to actually transcribing, cleared only once the
result (or error) is fully handled. `beginDictation()` and
`beginTranscribeFile()` both check `!isTranscribing` first, so a stray
hotkey press or menu click mid-transcription can't start a second,
overlapping recording/transcription.

**Fast-finalize's 30-second-window guard**: `previewWindowSamples = 30 *
16000`. A partial is only ever trusted as a stand-in for the *entire*
recording if it was captured while `sampleCountAtRequest <=
previewWindowSamples` — once a recording runs long enough that the preview
snapshot (itself capped to the last 30s via `PartialScheduler.windowed`)
no longer covers everything spoken, `lastPartial` is cleared so
fast-finalize can't silently drop the earlier part of a long recording.

---

## Localhost peer authentication design

Two independent identity checks exist because two different local servers
are involved, and both are one HTTP hop away from "some other process
happens to be listening on that port":

1. **whisper-server**: `WhisperServerManager.start()` first proves the port
   was free (bind-probe) before spawning its own subprocess — so nothing
   else could have claimed it in between (barring a small, accepted TOCTOU
   window). Its readiness `ping()` then additionally checks for whisper.cpp's
   `Server: whisper.cpp` response header, not just any 200/404.
2. **Ollama**: `Ollama.probeIsOllama(baseURL:)` GETs `/api/version` and
   requires the body to decode as Ollama's specific `{"version": String}`
   shape (`parseVersionResponse`) — this runs before *every* `rewrite(...)`
   and `pullModel(...)` call, refusing to send dictation text (or a
   `pullModel` request) if the endpoint doesn't identify as Ollama. Unlike
   whisper-server, MyWhisper doesn't own/spawn the Ollama process, so this
   probe is the only identity signal available — there's no equivalent
   "we know we bound this port ourselves" guarantee.

`ollamaBaseURL` is configurable (`defaults write com.ronimoe.mywhisper
ollamaBaseURL "http://..."`), with a malformed or missing stored value
always falling back to the hardcoded `http://127.0.0.1:11434` default rather
than silently sending dictation text to a broken/empty URL.

---

## File / permission model

`Settings.appSupportDir` (`~/Library/Application
Support/MyWhisper/`) is locked to `0700` on every access via
`Settings.lockDown(_:)`, which re-applies the permission even if the
directory already existed from before this change. Individual files holding
cleartext dictation are written `0600`:

| File | Written by | Perms |
|---|---|---|
| `history.json` | `HistoryStore.persist` | 0600 |
| `replacements.json` (via correction learning) | `Lexicon.appendReplacement` | 0600 |
| `models/ggml-*.bin` | `ModelDownloader` (on move-into-place) | 0600 |

`modes.json` and `profiles.json` are created via `ensureFileExists` with
default file permissions (inheriting the locked-down `0700` directory but
no explicit `0600`) since they don't (by default) contain anything more
sensitive than user-authored prompts/rules — a developer adding new
persisted files here should default to 0600 if the content could ever be
sensitive.

---

## Source-file map

`Sources/MyWhisper/`:

| File | Role |
|---|---|
| `main.swift` | Entry point; parses `--help`/`--transcribe` CLI flags or launches the GUI |
| `AppDelegate.swift` | Wires every controller/engine together; owns the hotkey→paste orchestration |
| `DictationPipeline.swift` | Shared clean→replace→command→punctuation→AI-rewrite pipeline (engine-agnostic core is pure/tested) |
| `HeadlessRunner.swift` | `--transcribe` CLI pipeline, reusing `DictationPipeline` |
| `Recorder.swift` | `AVAudioEngine` capture → 16 kHz mono Float32 + smoothed mic level |
| `SilenceDetector.swift` | Pure voice-activity state machine driving auto-stop |
| `WavWriter.swift` / `WavReader.swift` | PCM ⇄ WAV encode/decode |
| `AudioFileDecoder.swift` | Decodes arbitrary audio files (mp3/m4a/aiff/…) to 16 kHz mono via `AVAudioConverter` |
| `TranscriptionEngine.swift` | Engine protocol + shared `EngineState` enum |
| `WhisperServerManager.swift` | `whisper-server` subprocess manager + HTTP client + port/identity checks |
| `WhisperEngine.swift` | In-process libwhisper backend (serial-queue-owned context) |
| `CodeSwitch.swift` | Mixed-language + Indonesian punctuation priming prompts |
| `SpokenPunctuation.swift` | "koma"/"comma" → symbols, with capitalization rules (pure, tested) |
| `VoiceCommands.swift` | Whole-utterance command matching (pure, tested) |
| `Lexicon.swift` | Vocabulary + replacements, mtime-cached (pure load, tested) |
| `CorrectionDiff.swift` | Derives a find→replace rule from a manual correction (pure, tested) |
| `Modes.swift` | AI modes model, `ModeStore`, and the Ollama HTTP client (chat/version/tags/pull) |
| `ModeContext.swift` | Captures frontmost app name + Accessibility text selection; `{app}`/`{selection}` substitution |
| `AppProfiles.swift` | Per-app profile model, matching, and `EffectiveDictation` merge (pure, tested) |
| `HistoryStore.swift` | Transcript history persistence (0600, 200-entry cap) |
| `PartialScheduler.swift` | Live-preview pacing/windowing logic (pure, tested) |
| `FastFinalize.swift` | Pure "reuse the live preview as final" decision logic (tested) |
| `HotKeyManager.swift` | Global hotkey registration via Carbon `RegisterEventHotKey` |
| `HotKeyRecorder.swift` | Captures a new hotkey combination for "Change Hotkey…" |
| `StatusItemController.swift` | Menu-bar `NSStatusItem` + its full menu |
| `MenuBarIcon.swift` | Voice-reactive waveform icon drawing |
| `RecordingPill.swift` | Floating HUD during recording (meter, elapsed, caption, partial text, cancel) |
| `SettingsWindowController.swift` | ⌘, Settings window |
| `OnboardingWindowController.swift` | First-run Setup Assistant wizard |
| `HistoryWindowController.swift` | History browser window + Correct… flow |
| `TranscriptWindowController.swift` | File-transcription result window |
| `ModelDownloader.swift` | Downloads a ggml model from Hugging Face (the one non-localhost host the app talks to on its own) |
| `Settings.swift` | `UserDefaults`-backed settings, `Key` enum, model resolution logic |
| `TextInserter.swift` | Clipboard-preserving ⌘V paste + voice-command synthetic keystrokes |
| `Support.swift` | `Postprocess.clean` + `Notifier` (user notifications) |

`Sources/CWhisper/` — system-library shim (`module.modulemap` + `shim.h`)
exposing libwhisper's C API to Swift for `WhisperEngine`.

`Tests/MyWhisperTests/` — 24 XCTest files (below). `scripts/` — model
download, `.app` assembly, DMG build/notarize (see
[DEVELOPMENT.md](DEVELOPMENT.md)). `vendor/whisper.cpp/` — optional vendored
build of the engine (`make deps`).

---

## Test strategy

**310 tests** currently pass (`make test`; needs the full Xcode toolchain —
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, since the bare
Command Line Tools lack XCTest).

**Pure-logic extraction pattern**: every module that has *any* testable
decision logic keeps that logic in a static/pure function separated from
its OS-bound or I/O-bound shell, so it's unit-testable without a mic, a
subprocess, or a network call — e.g. `DictationPipeline.process(...)` (the
clean→replace→command→punctuation core) is pure and tested directly, while
`DictationPipeline.run(samples:...)` (which actually calls the engine) is
exercised via the CLI's real end-to-end path instead. Same split exists for
`SilenceDetector` (pure state machine) vs. `Recorder` (the AVAudioEngine
shell around it), `FastFinalize.shouldReuse` vs. the branch in
`AppDelegate.finishDictation`, `AppProfileStore.match`/`EffectiveDictation.resolve`
vs. the OS-bound `ModeContext.capture()`, and `Ollama.parseChatResponse` /
`parseVersionResponse` / `parseTagsResponse` / `parsePullProgressLine` (pure
parsers) vs. the actual `URLSession` calls around them.

**`NetworkAuditTests`** (`Tests/MyWhisperTests/NetworkAuditTests.swift`) is a
**source lint**, not a runtime sandbox: it scans every `.swift` file in
`Sources/MyWhisper` for `http://`/`https://` literals and fails if any line
references a non-`127.0.0.1`/`localhost` URL outside a narrow, per-file
allowlist. A second test pins that allowlist to **exactly 2 entries**:
`ModelDownloader.swift` → `https://huggingface.co`, and
`OnboardingWindowController.swift` → `https://ollama.com` (the "Get Ollama"
browser link). Adding a third entry, renaming either file, or widening
either URL fails that pinning test — so any new non-localhost endpoint
requires a deliberate, reviewed edit to this test, not just a code change
elsewhere. It cannot see dynamically-constructed URLs (string
concatenation) or traffic from outside `Sources/MyWhisper`; treat it as a
regression guard, not proof of network isolation (see PRIVACY.md).

Per-file test counts (roughly ascending): `NetworkAuditTests` (2),
`AudioFileDecoderTests`/`HotKeyDisplayTests`/`RecordingPillTests` (4 each),
`ModelDownloaderTests`/`MultipartBodyTests`/`SilenceDetectorTests` (5 each),
`PartialSchedulerTests`/`WavWriterTests` (6 each), `PostprocessTests` (8),
`ModeContextTests`/`WavReaderTests` (9 each), `HistoryStoreTests` (10),
`FastFinalizeTests`/`LexiconTests`/`StateTransitionTests` (13 each),
`CorrectionDiffTests`/`ModeTests` (14 each),
`DictationPipelineTests`/`SettingsTests` (15 each), `OllamaProbeTests` (17),
`VoiceCommandTests` (18), `AppProfileTests` (19), `CodeSwitchTests` (24),
`SpokenPunctuationTests` (42, the largest file — covers the token table,
spacing, capitalization, and duplicate-collapse rules exhaustively).

The mic-capture (`Recorder`) and global-hotkey (`HotKeyManager`) layers are
inherently OS-bound and aren't unit tested directly; they're instead covered
by the end-to-end CLI path (`--transcribe`) plus manual verification (see
`todos.md`'s manual feel-checks).

---

## Known accepted limitations

- **Ad-hoc / self-signed signing means TCC re-grants after rebuilds.** The
  app is signed with a local "MyWhisper Dev" certificate when available (ad
  hoc otherwise, see `scripts/make-app.sh`); because Gatekeeper/TCC key
  permissions like Accessibility off the code signature, every rebuild that
  changes the signature (or every ad-hoc build, which effectively re-signs
  each time) requires re-granting Accessibility. A stable Developer ID
  signature (post-notarization) would fix this permanently — see
  `docs/RELEASE.md`.
- **`large-v3-turbo` cannot translate.** It's distilled specifically for
  transcription; the Translate-to-English toggle needs `large-v3`,
  `medium`, or a smaller model instead (documented in the User Guide, not
  re-litigated in code — whisper.cpp itself enforces this at inference
  time, not MyWhisper).
- **AAC / compressed-writer-handle quirks** in `AudioFileDecoder`'s
  `AVAudioFile`/`AVAudioConverter` path are inherent to AVFoundation's
  handling of certain compressed containers; the fallback chain
  (`WavReader` fast path → `AudioFileDecoder` for everything else) exists
  precisely because not every format round-trips identically, and is the
  accepted mitigation rather than a promise that every codec/container
  combination behaves identically.
