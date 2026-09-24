# Contributing

Thanks for your interest in MyWhisper! Bug reports, fixes, and small
focused improvements are welcome.

## Before you start

- For anything bigger than a bug fix, open an issue first so we can agree
  on the approach.
- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit
  together and [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for build targets
  and conventions.

## Development setup

Requirements: an Apple Silicon Mac, macOS 13+, full Xcode (the Command Line
Tools alone lack XCTest), and Homebrew.

```sh
brew install whisper-cpp
make test        # run the XCTest suite
make run         # build MyWhisper.app and launch it
```

## Pull requests

- Keep each PR to one change, and add or update tests for behavior changes.
- `make test` must pass.
- **Privacy is a hard rule:** the app may only talk to `127.0.0.1`/`localhost`.
  `NetworkAuditTests` fails if a remote URL appears in `Sources/MyWhisper`
  outside its narrow allowlist. Don't widen the allowlist without discussing it
  in an issue first; see [PRIVACY.md](PRIVACY.md).
- Update the docs (`docs/USER-GUIDE.md`, `README.md`) when user-visible
  behavior changes.

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
