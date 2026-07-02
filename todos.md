# TODOs

## Verify (easy, pending)

- [ ] **AI modes live rewrite** — needs a chat model on `127.0.0.1:11434`.
      Either `docker exec agent-os-ollama ollama pull llama3.2` (existing
      container) or `brew install ollama && ollama serve && ollama pull llama3.2`.
      Then: menu → Mode → Email, dictate, confirm rewritten paste; and
      `.build/release/MyWhisper --transcribe <wav> --mode Email`.
      (Request/parse layer unit-tested; unreachable-fallback verified live.)
- [ ] Manual feel checks: hold-to-talk threshold (0.35 s), auto-stop
      silence window (2 s), history window UI, Launch at Login toggle.
- [ ] Manual checks (v1.5+): Settings window (⌘,) controls, live preview
      HUD position/readability, spoken punctuation in real dictation
      (enable in Settings first), mixed-language mode with your real voice,
      {app}/{selection} placeholders in AI modes (needs Ollama chat model).

## Future release (v2 candidates)

- [ ] **Meeting mode** — capture system audio locally (ScreenCaptureKit),
      speaker diarization (tinydiarize), meeting summaries via local LLM.
- [ ] **Developer-first** — stdin/pipe CLI, AppleScript + URL scheme,
      code-aware formatting modes (camelCase/snake_case dictation) for
      Cursor/Claude Code workflows.
- [ ] **Self-learning corrections** — observe post-paste edits and suggest
      new replacement rules automatically.
- [ ] **Pricing/positioning** — one-time purchase or free core vs.
      subscription incumbents; decide before public launch.
- [ ] Carried from README roadmap: context awareness, settings window,
      in-process libwhisper engine, notarized distribution, Windows/Linux.
