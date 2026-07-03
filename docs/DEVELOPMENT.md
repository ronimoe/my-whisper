# MyWhisper — Development Guide

For anyone building, testing, or extending MyWhisper.

---

## Prerequisites

- **Xcode Command Line Tools** (`xcode-select --install`) to build with
  `swift build`.
- **The full Xcode.app** to run tests. XCTest is not part of the bare
  Command Line Tools — `make test` (and any direct `swift test`) must be run
  with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` set, or it
  fails to find the testing framework. This is not optional or a nice-to-have
  — gate every change on `make test` passing.
- **A transcription engine binary.** Either:
  - `brew install whisper-cpp` (quickest — installs `whisper-server` to
    `/opt/homebrew/bin`), or
  - `make deps` — clones `ggml-org/whisper.cpp` into `vendor/whisper.cpp` and
    builds a static `whisper-server` there (needs `cmake`; this is also what
    `make dist` bundles into the DMG so it's self-contained on machines
    without Homebrew).
- **A speech model** — `make model` (see below) or the in-app Setup
  Assistant/Download button.

---

## Every Makefile target

```makefile
build   swift build -c release
test    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
app     build + ./scripts/make-app.sh   → build/MyWhisper.app (ad-hoc/local-cert signed)
run     app + open build/MyWhisper.app
model   ./scripts/download-model.sh $(MODEL)   (MODEL defaults to large-v3-turbo)
deps    clone/pull vendor/whisper.cpp, cmake-configure + build a static whisper-server
dist    ./scripts/make-dist.sh   → build/MyWhisper-<version>.dmg
clean   rm -rf .build build
```

`make model MODEL=small` downloads a specific model name instead of the
default `large-v3-turbo`.

---

## `scripts/` reference

| Script | One-line description |
|---|---|
| `download-model.sh` | Downloads a named ggml model from Hugging Face into `~/Library/Application Support/MyWhisper/models/`, resuming partial downloads and skipping if already present. |
| `make-app.sh` | Assembles `build/MyWhisper.app` from the release binary + `Info.plist`, bundling a vendored `whisper-server` if present, and code-signs (prefers the local "MyWhisper Dev" identity, falls back to ad hoc). |
| `make-dist.sh` | Builds the free-download DMG: downloads/caches a small starter model, calls `make-app.sh`, bundles the starter model into the app's Resources, re-signs, stages `Download Model.command` + `INSTALL.txt`, and packages everything into `build/MyWhisper-<version>.dmg`. |
| `notarize.sh` | Notarized-build path (needs a paid Apple Developer Program account + a Developer ID Application certificate): builds via `make-dist.sh`, deep-signs with hardened runtime + entitlements, submits to `notarytool`, staples the ticket, and verifies with `spctl --assess`. See `docs/RELEASE.md`. |
| `dist/INSTALL.txt` | End-user install instructions bundled into the DMG as `README.txt` — not touched by this doc pass. |

---

## Repo layout

```
Sources/MyWhisper/       all Swift source — see docs/ARCHITECTURE.md's source-file map
Sources/CWhisper/        libwhisper C shim (module map + header) for the in-process engine
Tests/MyWhisperTests/    25 XCTest files, 310 tests total
Resources/               Info.plist, entitlements
scripts/                 build/dist/notarize scripts + dist/ (DMG staging assets)
vendor/                  optional vendored whisper.cpp checkout + build (make deps)
docs/                    this documentation set
Package.swift            SwiftPM manifest (no Xcode project)
Makefile                 all dev-facing commands
PRIVACY.md, LICENSE      trust documents — stay at repo root, not moved into docs/
todos.md                 pending verifications + future-release ideas
```

---

## Conventions

- **Test-first with a red-run proof.** New behavior gets a failing test
  committed (or at least run and shown red) before the implementation that
  makes it pass — this is the pattern behind the pure-logic-extraction
  modules (`FastFinalize`, `PartialScheduler`, `SpokenPunctuation`, etc.),
  each of which has a same-named `*Tests.swift` file.
- **Push per phase.** Land working, tested slices rather than one large
  uncommitted change — visible in the commit history as focused, sequential
  fixes (e.g. "Fix #3", "Fix #4", "Fix #5a/#5b").
- **Pure-logic extraction for testability.** Anything OS-bound (mic capture,
  Accessibility API calls, subprocess management, real network calls) gets a
  thin shell around a pure, static/struct-based core that takes plain data
  in and returns plain data out — see `docs/ARCHITECTURE.md`'s "Test
  strategy" section for the full list of examples. When adding a feature,
  default to this split rather than burying decision logic inside an
  AppKit/Foundation-bound class.
- **Style notes**: doc comments explain *why*, not just *what*, especially
  around concurrency (see the `stateLock`/`setState`/`transition` comments
  in `WhisperServerManager`/`WhisperEngine` as the reference example) and
  around anything privacy-sensitive (file permissions, localhost-only
  networking). Keep that standard when touching those areas.

---

## How-to recipes

### Add a Settings toggle end-to-end

1. Add a case to `Settings.Key` (`Settings.swift`) — **never rename an
   existing case's raw value**; the enum only centralizes already-persisted
   `UserDefaults` keys, and a rename orphans existing users' saved settings.
2. Add the computed property (get/set over `defaults`, with a sensible
   default via `?? <default>`) and a doc comment stating the default and
   what it does.
3. Add a checkbox/control in both `StatusItemController.menuNeedsUpdate`
   (menu item + `@objc` toggle handler) and
   `SettingsWindowController.buildBehaviorSection`/`refresh` (checkbox +
   toggle handler) — the two surfaces are kept in sync manually, so a new
   toggle needs both.
4. If the setting affects the dictation pipeline itself, thread it through
   `AppDelegate.finishDictation`/`beginDictation` (and
   `EffectiveDictation`/`AppProfile` if it should be per-app-overridable) and
   `HeadlessRunner.run` (if it's CLI-relevant).
5. Write a `SettingsTests.swift`-style test for the new property's default
   and persistence if it has any non-trivial logic (e.g. a fallback for a
   malformed stored value, as `ollamaBaseURL` has).
6. `make test` — must stay at (old count + your new tests).

### Add a language / mixed pack

- **Fixed language**: add a `(code, name)` tuple to `Settings.languages`.
  That's it — the language/model popups, the menu, and
  `CodeSwitch.requestParameters`'s fallback (`return (language,
  vocabularyPrompt)`) all pick it up automatically.
- **Mixed (code-switching) pack**: add an entry to `Settings.languages`
  (e.g. `("mixed-xx", "Mixed (Xxxxx + English)")`), a priming-example
  constant in `CodeSwitch.swift` (a natural sentence in the target language
  with a few English words mixed in, matching the style of the existing
  `tlPrimingExample`/`hiPrimingExample`/etc.), and an entry in
  `CodeSwitch.pairs` mapping the new code to `(primaryLanguageCode,
  primingExample)`. Add a `CodeSwitchTests` case asserting
  `requestParameters(language: "mixed-xx", ...)` returns the expected
  primary language and that the priming text is included.

### Add a voice command

1. Add an enum case to `VoiceCommand` (`VoiceCommands.swift`) if it's a new
   *kind* of action (not just a new phrase for an existing one).
2. Add every phrase variant (English + Indonesian, matching the existing
   pattern) to the `phrases` dictionary, each mapping to the command case.
3. Implement the actual effect in `TextInserter.perform(_:)` — commands are
   executed via synthetic key events (`sendKey`), guarded on
   `AXIsProcessTrusted()`.
4. Add cases to `VoiceCommandTests.swift`: the exact-match behavior (whole
   utterance only, punctuation-stripped), and that a phrase embedded in a
   longer sentence does *not* match.
5. Remember voice-command matching happens **before** spoken punctuation in
   `DictationPipeline.process` — if your new command's phrase overlaps with
   a spoken-punctuation token, that ordering determines which wins.

### Add an AI mode default

- Modes the *user* adds go straight into their own `modes.json` — no code
  change needed for that.
- To change the **shipped defaults** every fresh install gets, edit
  `ModeStore.defaultModes` in `Modes.swift`. Keep the existing convention:
  `name`, a `prompt` ending in an explicit "Output only the rewritten
  text"/"Output only the bullets" instruction (keeps Ollama from adding
  commentary), and `model: nil` (falls back to the user's configured
  `ollamaModel`) unless the mode specifically needs a different model size.
- Update `ModeTests.swift` if you're asserting anything about the default
  set's shape/count.
- If the new mode should support `{app}`/`{selection}`, no extra work is
  needed — `ModeContext.substitute` runs unconditionally on every mode's
  prompt.

---

## Release process summary

Two build paths exist today:

- **Free build** (works now, no Apple Developer account needed):
  `make dist` → `build/MyWhisper-<version>.dmg`, signed with a local
  self-signed "MyWhisper Dev" certificate. Recipients need one "Open
  Anyway" click in System Settings → Privacy & Security since it isn't
  notarized.
- **Notarized build** (removes the "Open Anyway" step): prepared in
  `scripts/notarize.sh`, blocked on enrolling in the paid Apple Developer
  Program. Once enrolled, it's a Developer ID certificate + stored
  `notarytool` credentials + one script invocation.

Full step-by-step instructions, credential setup, and entitlement notes
live in [`docs/RELEASE.md`](RELEASE.md) — this section is intentionally just
a pointer, not a duplicate.
