# TODOs

## Verify (pending)

- [ ] **AI modes live rewrite** — needs a chat model on `127.0.0.1:11434`
      (the Ollama there currently has only `bge-m3`, an embedding model):
      `docker exec agent-os-ollama ollama pull llama3.2` (or native install).
      Then: menu → Mode → Email, dictate, confirm rewritten paste; and
      `.build/release/MyWhisper --transcribe <wav> --mode Email`.
- [ ] **Notarization** — prepared in `scripts/notarize.sh` + RELEASE.md;
      blocked on enrolling in the Apple Developer Program ($99/yr).

## Manual feel-checks (v2 feature sweep, 2026-07-03)

- [ ] Recording pill: appears bottom-center on every recording start; level
      bars react to voice; elapsed ticks; caption shows effective
      language/mode; ✕ cancels without stealing focus.
- [ ] Esc cancels while recording — and has ZERO effect system-wide before/
      after recording (critical regression check for the global hotkey).
- [ ] "Cancel Dictation (Esc)" menu item appears only while recording.
- [ ] Setup Assistant: appears on first launch (reset with
      `defaults write com.ronimoe.mywhisper hasCompletedOnboarding -bool false`),
      permission rows refresh live, in-app model download shows progress and
      cancel works, try-it box dictation, Done persists.
- [ ] DMG on a fresh Mac (or fresh user account): starter model dictates
      immediately; wizard offers the full-model upgrade.
- [ ] Instant paste: dictate with preview on, pause, stop → paste is
      immediate; stop mid-word → normal path, still correct; >30 s recording
      → normal path; Settings toggle off → always normal path.
- [ ] Per-app profiles: seed via "Edit App Profiles…", e.g. Slack → Message
      mode; confirm pill caption + pasted result honor the override
      (including via instant paste).
- [ ] Mixed language packs: try mixed-tl/hi/es/zh with real speech.
- [ ] Corrections: History → select → "Correct…" → edit → save; confirm rule
      lands in replacements.json and next dictation auto-fixes; second
      correction of the same phrase updates (not duplicates) the rule.
- [ ] File transcription: menu → "Transcribe Audio File…" with an mp3/m4a;
      transcript window + Copy; error path with a corrupt file; busy-guard
      while dictating.
- [ ] Older checks still open: hold-to-talk feel (0.35 s), auto-stop window
      (2 s), Launch at Login toggle.

## Future release (v3 candidates)

- [ ] **Meeting mode** — system-audio capture (ScreenCaptureKit), diarization
      (tinydiarize), local-LLM summaries.
- [ ] **Developer-first** — stdin/pipe CLI, AppleScript + URL scheme,
      code-aware formatting (camelCase/snake_case dictation).
- [ ] **Pricing/positioning** — decide before public launch.
- [ ] Windows/Linux port — scoped in PORTING.md.
- [ ] Auto-update (Sparkle) — after notarization exists.
- [ ] Lexicon/ModeStore JSON writes: tighten to 0600 like HistoryStore
      (follow-up noted during the permissions fix).
