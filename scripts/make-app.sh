#!/usr/bin/env bash
# Assemble MyWhisper.app from the release build.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/MyWhisper.app
BIN=.build/release/MyWhisper

[[ -x "$BIN" ]] || { echo "run 'make build' first" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin"
cp "$BIN" "$APP/Contents/MacOS/MyWhisper"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# License + attributions travel with every copy of the app (MIT requires it
# for the bundled whisper-server and model).
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"

# Bundle a self-contained whisper-server if a vendored static build exists;
# otherwise the app falls back to the Homebrew binary at runtime.
VENDORED=vendor/whisper.cpp/build/bin/whisper-server
if [[ -x "$VENDORED" ]]; then
  cp "$VENDORED" "$APP/Contents/Resources/bin/whisper-server"
fi

# Prefer the stable self-signed identity so TCC grants (Accessibility)
# survive rebuilds; fall back to ad-hoc signing.
SIGN_ID="${MYWHISPER_SIGN_ID:-MyWhisper Dev}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
  codesign --force --sign "$SIGN_ID" "$APP"
  echo "signed with: $SIGN_ID"
else
  codesign --force --sign - "$APP"
  echo "signed ad-hoc (no '$SIGN_ID' certificate found)"
fi
echo "built $APP"
