# Porting MyWhisper to Windows and Linux

An honest scoping document. The engine and all pure logic port cheaply; the
OS-integration layer is a rewrite per platform. This maps every component to
its equivalent so the port is a plannable project, not a guess.

## What ports for free

| Component | Why it ports |
|---|---|
| Transcription engine | whisper.cpp is cross-platform (CUDA/Vulkan on Windows/Linux instead of Metal). The `whisper-server` HTTP protocol our app speaks is identical everywhere. |
| Pipeline semantics | Postprocess, Lexicon, SpokenPunctuation, VoiceCommands matching, CodeSwitch prompts, PartialScheduler, HistoryStore, ModeStore/Ollama client — all pure logic, no AppKit. |
| Test suite as spec | The 145+ XCTest cases define exact expected behavior (punctuation spacing, VAD timing, WAV format, multipart fields). Port the tests first — they become the acceptance spec for the new codebase. |
| Config files | replacements.json, modes.json, history.json formats stay identical. |

## What must be rebuilt per platform

| macOS piece (this repo) | Windows | Linux |
|---|---|---|
| AVAudioEngine capture (Recorder) | WASAPI | PipeWire/PulseAudio |
| Carbon RegisterEventHotKey | RegisterHotKey (Win32) | X11 grab / DE portal (Wayland is restrictive) |
| CGEvent ⌘V paste (TextInserter) | SendInput | xdotool/wtype (X11); Wayland: virtual-keyboard portal |
| NSStatusItem menu bar | tray icon (Shell_NotifyIcon) | StatusNotifierItem |
| Accessibility selected-text capture | UIAutomation | AT-SPI (patchy) |
| SMAppService launch-at-login | registry Run key | XDG autostart |
| NSPanel preview HUD | layered topmost window | layered/override-redirect window |

## Recommended stack

**Tauri 2 + Rust core.** One codebase for Windows + Linux (and could later
absorb macOS): `cpal` (capture), `global-hotkey`, `enigo` (synthetic input),
`tray-icon`, whisper via the same local `whisper-server` subprocess we
already use (reuse the protocol; swap to `whisper-rs` later the same way
this repo added an in-process engine). Rust port of the pure-logic layer is
mechanical — each Swift type has unit tests to copy over.

Alternative: stay Swift with a shared core package and per-OS shells — only
sensible if Swift-on-Windows/Linux tooling matures; not recommended today.

## Phasing (realistic)

1. Rust core crate + ported unit tests (the spec) — the cheap, high-value start.
2. Windows shell: capture → hotkey → paste loop (the v0.1 of this repo).
3. Windows parity: menu, settings, history, modes, preview HUD.
4. Linux (X11 first; Wayland portals after).

Phase 1–2 is roughly the effort this macOS app took from zero to first
working dictation; parity (phase 3) is the long tail.

## Non-goals of a port

Keep the privacy invariant everywhere: localhost-only, no telemetry — the
NetworkAuditTests equivalent should exist in the Rust core from day one.
