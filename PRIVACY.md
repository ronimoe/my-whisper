# Privacy

MyWhisper is built so that your voice and your words physically cannot leave
your machine.

## What runs where

- **Speech recognition**: whisper.cpp (`whisper-server`) on `127.0.0.1` —
  a local process this app spawns and owns.
- **AI modes (optional)**: an Ollama model on `127.0.0.1:11434` — also local.
- **Transcripts, history, settings, replacements, modes**: plain local files
  under `~/Library/Application Support/MyWhisper/`.

## What never happens

- No telemetry, analytics, crash reporting, or account.
- No network connection to anything that is not `127.0.0.1`/`localhost`.

## How this is enforced, not just promised

- `Tests/MyWhisperTests/NetworkAuditTests.swift` scans every line of app
  source and **fails the build's test gate if any non-localhost URL appears
  in app code**.
- The source is small and auditable — see the project layout in README.md.
- Model files are downloaded only when you explicitly run
  `make model` / `scripts/download-model.sh` (from Hugging Face); the app
  itself never downloads anything.

You can independently verify with an outbound firewall (e.g. Little Snitch):
MyWhisper generates no outbound connection attempts.
