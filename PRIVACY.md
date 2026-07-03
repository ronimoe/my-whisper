# Privacy

MyWhisper is designed so that your voice and your words stay on your
machine: speech recognition and AI rewriting both run against local
processes, and nothing in the app talks to a remote server.

## What runs where

- **Speech recognition**: whisper.cpp (`whisper-server`) on `127.0.0.1` —
  a local process this app spawns and owns.
- **AI modes (optional)**: an Ollama model on `127.0.0.1:11434` — also local.
  Before sending text, MyWhisper probes the endpoint's identity so it
  doesn't hand dictation text to something else that happens to be listening
  on that port.
- **Model downloads (only when you click Download)**: `huggingface.co` —
  the one remote host the app ever contacts, and only through
  `ModelDownloader.swift`. It fetches a `.bin` model file when you click
  "Download" in the first-run Setup Assistant or the Settings window; no
  dictation audio or text is ever sent there, only a plain HTTPS GET for
  the model file. No other file in the app talks to any non-localhost host.
- **Transcripts, history, settings, replacements, modes**: plain local files
  under `~/Library/Application Support/MyWhisper/`, restricted to
  owner-only permissions (0700 directory, 0600 files).

## What never happens

- No telemetry, analytics, crash reporting, or account.
- No network connection is coded into the app to anything that is not
  `127.0.0.1`/`localhost`, except the explicit, user-initiated model
  download described above.

## How this is checked

- `Tests/MyWhisperTests/NetworkAuditTests.swift` is a **source lint**: it
  scans the literal text of every file in `Sources/MyWhisper` for
  `http://`/`https://` URL strings and fails the test gate if any of them
  isn't `127.0.0.1`/`localhost`, with a single narrow exception: a
  per-file allowlist permits `https://huggingface.co` in
  `ModelDownloader.swift` only. If `huggingface.co` (or any other remote
  URL) shows up in any other file, the test fails — the exception does not
  widen to the rest of the codebase. That catches accidental or
  intentional hardcoded remote endpoints in this target's source, but it is
  not a runtime sandbox — it cannot see URLs built dynamically at runtime
  (e.g. via string concatenation), traffic from system frameworks or other
  processes, or code outside `Sources/MyWhisper`. Treat it as a regression
  guard, not a network-level enforcement mechanism.
- The source is small and auditable — see the project layout in README.md.
- Model files are downloaded only when you explicitly run
  `make model` / `scripts/download-model.sh`, or click "Download" in the
  in-app Setup Assistant / Settings window (both a one-time fetch from
  Hugging Face); the running app never initiates a download on its own.

For a stronger, independent guarantee, monitor actual traffic with an
outbound firewall (e.g. Little Snitch) rather than relying on the source
lint alone.
