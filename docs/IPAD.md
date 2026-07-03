# Bringing MyWhisper to iPad (A16-class)

An honest scoping document, in the spirit of [PORTING.md](PORTING.md). Short
version: **the current macOS app cannot run on iPad**, but a large fraction of
its code can be reused to build a *separate* iPad app. The blocker is not the
chip — an A16 iPad (≈6 GB RAM) runs whisper.cpp with Metal comfortably — it's
the platform: iPadOS uses UIKit not AppKit, ships `.ipa` not `.app`, and its
sandbox forbids the two mechanisms MyWhisper is built around (a global hotkey
and pasting into other apps). Macs can run iPad apps; iPads cannot run Mac
apps, so there is no "just enable it" path.

## Why the Mac app can't just load on iPad

| Blocker | Detail |
|---|---|
| Wrong UI framework | 11 of the source files import `AppKit` (menu bar, windows, panels). iPadOS has no AppKit — UIKit/SwiftUI rewrite. |
| Wrong binary/format | macOS `.app`/DMG vs iPadOS `.ipa` via App Store/TestFlight. Different SDK, different sandbox. |
| No global hotkey | `HotKeyManager`/`HotKeyRecorder` use Carbon `RegisterEventHotKey`. iPadOS has **no** system-wide hotkey; hardware-keyboard shortcuts work only while the app is foreground. |
| No paste-into-other-apps | `TextInserter` uses Accessibility + synthetic ⌘V; `ModeContext` reads the frontmost app's selection via AX. iOS/iPadOS sandboxing **forbids both**. This removes MyWhisper's core "dictate into whatever app is focused" model. |
| No subprocesses | `WhisperServerManager` spawns `whisper-server` via `Process`. iOS bans subprocess spawning — the default engine is gone. |
| Desktop-only integrations | `ServiceManagement` launch-at-login, `NSStatusItem` menu bar — no iPad equivalent. |

## What ports with little or no change

The codebase was built with logic separated from AppKit, so this column is
large. Verified against actual imports:

| Component | Notes |
|---|---|
| **In-process engine** (`WhisperEngine` + `CWhisper`) | whisper.cpp compiles for iOS with Metal. This is the *only* engine that survives, and it's the one to keep. |
| **All pure logic** — `DictationPipeline`, `CodeSwitch`, `SpokenPunctuation`, `VoiceCommands`, `Lexicon`, `CorrectionDiff`, `FastFinalize`, `AppProfiles`*, `Settings`, `SilenceDetector`, `PartialScheduler`, `Modes`/Ollama client, `ModelDownloader`, `WavReader`/`WavWriter`, `HistoryStore`, `TranscriptionEngine` | Foundation-only, zero UI. Compile as-is. (*Per-app profiles need rethinking — see below.) |
| **Audio** — `Recorder`, `AudioFileDecoder` | AVFoundation exists on iOS. `Recorder` needs an `AVAudioSession` category/activation that macOS doesn't require, plus interruption handling (calls, Siri). |
| **The 300+ test suite** | The pure-logic tests move over unchanged and become the acceptance spec for the iPad app — port them first. |
| **Config files** | `replacements.json`, `modes.json`, `profiles.json`, `history.json` formats stay identical (in the app's iOS container). |

## What must be rebuilt or rethought

| macOS piece | iPad replacement |
|---|---|
| AppKit windows/menus/panels (AppDelegate, StatusItemController, MenuBarIcon, RecordingPill, all `*WindowController`) | SwiftUI (recommended) — a normal app UI, not a menu-bar accessory. |
| Global hotkey | Foreground affordances: a big record button, hardware-keyboard shortcut while foreground, and/or a Lock-Screen/Control-Center widget or Shortcuts action to launch-and-record. |
| Paste into other apps (`TextInserter`) | **The hard one.** Options, weakest→strongest: copy-to-clipboard + share sheet; a **custom keyboard extension** with a mic key; a Shortcuts/App-Intent action. None match the Mac's silent "type into anything." |
| `{app}`/`{selection}` context (`ModeContext`) | Not possible — can't read other apps. Drop, or limit to text the user pastes/shares into MyWhisper. |
| Per-app profiles | Reframe as manual/Shortcuts-driven profiles; iPadOS can't see or key off "the frontmost app" the way macOS can. |
| Notifier (`Support`) | UIKit alert / UNUserNotificationCenter (already cross-platform). |
| AI modes (Ollama) | No Ollama on iPad. Either drop, use a *remote* endpoint (breaks the 100%-local promise — avoid), or run a small on-device LLM (llama.cpp/MLX, 1–3B) on the A16 — feasible but a separate workstream. |

## The memory wall (the decision that shapes everything)

The iPad-idiomatic way to "dictate into any app" is a **custom keyboard
extension**. But keyboard extensions run under a hard memory ceiling
(historically ~60–120 MB before the OS kills them) — nowhere near enough to
load a whisper model (`tiny` alone is ~75 MB on disk, more in memory with the
Metal context). Practical consequence:

- **Main app**: normal memory budget (a large share of ≈6 GB). Runs `small`,
  `medium`, even `large-v3-turbo`. This is where transcription must live.
- **Keyboard extension**: essentially cannot host whisper itself. It would
  have to hand audio to the containing app (App Group + shared container,
  round-tripping through the main process) or lean on a remote/on-device-tiny
  path — all with real latency and reliability costs.

So the honest conclusion: **an in-app dictation experience is the strong MVP;
true dictate-anywhere on iPad is a hard, second-class feature** — the opposite
of the Mac, where dictate-anywhere is the whole point.

## Recommended shape

1. **iPad MVP — in-app dictation.** SwiftUI app: record → live preview →
   transcript you can edit, copy, and share. Reuse `WhisperEngine` + all pure
   logic + the tests. Bundled starter model + in-app download (the
   `ModelDownloader` logic ports; the URLSession download works on iOS). This
   is genuinely useful (voice notes, drafting, transcribe-a-file) and is
   mostly assembling parts that already exist and are tested.
2. **Reach into other apps — phase 2.** Share-extension + Shortcuts/App-Intent
   ("Dictate with MyWhisper" → returns text) first (cheap, reliable), a
   keyboard extension only if the memory round-trip proves acceptable.
3. **AI modes / on-device LLM — later**, if there's demand.

Structure it as a **shared Swift package** (engine + pure logic + tests) with
two thin app shells (macOS AppKit, iPadOS SwiftUI) depending on it — the same
"shared core, per-OS shell" idea PORTING.md floats for desktop, and the
cleanest way to keep the two apps from drifting.

## Distribution reality

No free DMG-style sideloading on iPad. Options are App Store, or **TestFlight**
for demand-testing (free, up to 10 000 external testers, 90-day builds) — the
direct analog to today's free-DMG strategy. Both require the **Apple Developer
Program ($99/yr)** — the *same* enrollment already blocking macOS notarization
(see [RELEASE.md](RELEASE.md)). One account unlocks both.

## Non-goals

Keep the privacy invariant: on-device only, no telemetry, no remote
transcription. The `NetworkAuditTests` equivalent should exist in the shared
core from day one — and on iPad it matters more, because "send audio to a
server" is the easy, tempting shortcut this project exists to refuse.
