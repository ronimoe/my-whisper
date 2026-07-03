# TODOs

## Verify (pending)

- [x] **AI modes live rewrite** — VERIFIED live 2026-07-03: pulled `llama3.2`
      via the in-app Setup Assistant, selected Mode → Email, dictated, and a
      rewritten result pasted (probe → Ollama chat → paste path all fired
      end-to-end). Note: first rewrite is slow (one-time model load into
      memory); and if the source language is mislabeled the rewrite faithfully
      keeps that language (see the Auto-detect item below).
- [ ] **Notarization** — prepared in `scripts/notarize.sh` + docs/RELEASE.md;
      blocked on enrolling in the Apple Developer Program ($99/yr).

## Live DMG test results (fresh-user simulation, 2026-07-03)

Ran the quarantined DMG through a full fresh-install: Gatekeeper block →
Open Anyway → wizard → dictation. Confirmed working:

- [x] Gatekeeper "Not Opened" flow — reproduced the exact dialog; docs now
      walk through it (click Done, not Move to Trash → Open Anyway).
- [x] DMG drag-to-install: styled icon window (app → /Applications alias);
      "Download Model.command" removed (Setup Assistant supersedes it).
- [x] Setup Assistant appears on first launch; both permission rows refresh
      live to ✅ after granting; in-app model download shows live progress
      (speech model + Ollama pull ran concurrently). (Not exercised:
      the download **Cancel** button, "Done persists / wizard doesn't
      reappear".)
- [x] Starter model dictates immediately while the full model downloads
      ("works in 60 seconds" held). Wizard offered the full-model upgrade.
- [x] Recording pill: appears bottom-center, level bars react to voice,
      elapsed ticks, caption shows the language. (Not separately confirmed:
      ✕ cancels without stealing focus.)
- [x] Try-it box receives dictation — after the fix (direct insertion; the
      synthetic-⌘V-into-our-own-window path was unreliable).

Fixed mid-test (all pushed):
- [x] Try-it box was empty on dictation → direct-insertion path.
- [x] Auto-detect mislabeled Indonesian-accented English as Malay → added a
      **language picker to the wizard** + made auto-detect previews wait for
      2 s of audio to reduce flicker. (Root-cause mitigation, not a model
      change — see the open decision below.)

## Manual feel-checks still to do

- [ ] Esc cancels while recording — and has ZERO effect system-wide before/
      after recording (critical regression check for the global hotkey).
- [ ] "Cancel Dictation (Esc)" menu item appears only while recording.
- [ ] Instant paste: dictate with preview on, pause, stop → paste is
      immediate; stop mid-word → normal path, still correct; >30 s recording
      → normal path; Settings toggle off → always normal path.
- [ ] Per-app profiles: seed via "Edit App Profiles…", e.g. Slack → Message
      mode; confirm pill caption + pasted result honor the override
      (including via instant paste).
- [ ] Mixed language packs: try mixed-tl/hi/es/zh with real speech (id+en was
      the fix target today but not yet re-confirmed end-to-end).
- [ ] Corrections: History → select → "Correct…" → edit → save; confirm rule
      lands in replacements.json and next dictation auto-fixes; second
      correction of the same phrase updates (not duplicates) the rule.
- [ ] File transcription: menu → "Transcribe Audio File…" with an mp3/m4a;
      transcript window + Copy; error path with a corrupt file; busy-guard
      while dictating.
- [ ] Older checks still open: hold-to-talk feel (0.35 s), auto-stop window
      (2 s), Launch at Login toggle.
- [ ] Truly-virgin Mac test — the 2026-07-03 run was a fresh-user simulation
      on this machine (kept the downloaded turbo model + Ollama); the one
      thing it can't prove is a Mac that never had whisper-server/dylibs.

## Open decisions

- [ ] **Default language: Auto-detect vs. a safer default?** Live testing
      showed Auto-detect reliably mislabels Indonesian-accented English as
      Malay on short/starter-model input. Current mitigation: wizard language
      picker + 2 s preview delay. Question for real users: should the shipped
      default stay Auto, or should first-run nudge harder toward pinning a
      language / a Mixed pack?
- [ ] **Pricing/positioning** — decide before public launch.
- [ ] Public-repo flip — Roni's call; everything prepared.

## Future release (v3 candidates)

- [ ] **Meeting mode** — system-audio capture (ScreenCaptureKit), diarization
      (tinydiarize), local-LLM summaries.
- [ ] **Developer-first** — stdin/pipe CLI, AppleScript + URL scheme,
      code-aware formatting (camelCase/snake_case dictation).
- [ ] Windows/Linux port — scoped in docs/PORTING.md.
- [ ] Auto-update (Sparkle) — after notarization exists.
- [x] Lexicon/ModeStore/AppProfiles seed writes tightened to 0600 (fixed in
      the 2026-07-03 fresh-eyes review batch, with tests).

## Known design tradeoffs (documented, intentional)

- Per-app profile + {app}/{selection} context are captured at RECORDING
  START, not paste time — alt-tabbing mid-dictation pastes into the new app
  using the original app's profile/context. Matches user intent in the
  common case; revisit only if real users report confusion.
