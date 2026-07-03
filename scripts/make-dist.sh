#!/usr/bin/env bash
# Build the free-download distribution zip: self-contained app +
# bundled starter model + model downloader + install instructions.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

[[ -x vendor/whisper.cpp/build/bin/whisper-server ]] || {
  echo "vendored whisper-server missing — run 'make deps' first" >&2; exit 1; }

# Small quantized model bundled into the app so a fresh install can dictate
# immediately, before the user downloads the full large-v3-turbo model.
STARTER_FILE=ggml-small-q5_1.bin
STARTER_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${STARTER_FILE}"
STARTER_CACHE="vendor/models/${STARTER_FILE}"
if [[ ! -f "$STARTER_CACHE" ]]; then
  echo "downloading starter model ($STARTER_FILE) ..."
  mkdir -p vendor/models
  curl -L --fail -C - --progress-bar -o "${STARTER_CACHE}.part" "$STARTER_URL"
  mv "${STARTER_CACHE}.part" "$STARTER_CACHE"
fi

./scripts/make-app.sh

# The bundle must carry the self-contained server for machines without Homebrew.
[[ -x build/MyWhisper.app/Contents/Resources/bin/whisper-server ]] || {
  echo "bundled whisper-server missing from app" >&2; exit 1; }

# Bundle the starter model, then re-sign — make-app.sh already signed the app,
# and adding a file after signing invalidates that signature.
mkdir -p build/MyWhisper.app/Contents/Resources/models
cp "$STARTER_CACHE" "build/MyWhisper.app/Contents/Resources/models/${STARTER_FILE}"

SIGN_ID="${MYWHISPER_SIGN_ID:-MyWhisper Dev}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
  codesign --force --sign "$SIGN_ID" build/MyWhisper.app
  echo "re-signed with: $SIGN_ID"
else
  codesign --force --sign - build/MyWhisper.app
  echo "re-signed ad-hoc (no '$SIGN_ID' certificate found)"
fi

STAGE=build/dist/MyWhisper
rm -rf build/dist
mkdir -p "$STAGE"
cp -R build/MyWhisper.app "$STAGE/"
cp scripts/dist/Download-Model.command "$STAGE/Download Model.command"
cp scripts/dist/INSTALL.txt "$STAGE/README.txt"
chmod +x "$STAGE/Download Model.command"

DMG="build/MyWhisper-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "MyWhisper" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
echo "$DMG"
