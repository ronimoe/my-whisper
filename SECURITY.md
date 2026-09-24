# Security Policy

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

Report privately through GitHub's private vulnerability reporting: go to the
repository's **Security** tab → **Report a vulnerability**. You'll get a
response there, and a fix and advisory will be coordinated with you before
anything is disclosed.

## What's in scope

Especially interesting reports:

- Any way dictated audio or text can leave the machine, e.g. a network
  connection to anything other than `127.0.0.1`/`localhost` (see
  [PRIVACY.md](PRIVACY.md)).
- Other local processes reading MyWhisper's data files (history, replacements,
  modes), which should be owner-only (0700 directory, 0600 files).
- Abuse of the Accessibility/Microphone permissions the app holds.
- Issues in how the bundled `whisper-server` is launched or how the Ollama
  endpoint is verified before text is sent to it.

Vulnerabilities in whisper.cpp or Ollama themselves should go to those
projects.

## Supported versions

Only the latest release is supported.
