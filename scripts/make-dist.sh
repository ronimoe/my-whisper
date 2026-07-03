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
cp scripts/dist/INSTALL.txt "$STAGE/README.txt"
ln -s /Applications "$STAGE/Applications"

DMG="build/MyWhisper-$VERSION.dmg"
rm -f "$DMG"

# Detach any stale mount from a previous run before we build a fresh one.
if [[ -d /Volumes/MyWhisper ]]; then
  hdiutil detach "/Volumes/MyWhisper" -force || true
fi

# Build a read-write staging image so Finder can set icon positions on it.
RW_DMG=build/tmp-rw.dmg
rm -f "$RW_DMG"
hdiutil create -quiet -volname "MyWhisper" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW_DMG"

hdiutil attach "$RW_DMG" -noautoopen

# Style the volume: icon view, no toolbar, fixed window bounds, and explicit
# icon positions (app on the left, /Applications alias on the right).
osascript <<'OSA'
tell application "Finder"
  tell disk "MyWhisper"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 840, 560}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 100
    set text size of theViewOptions to 13
    set position of item "MyWhisper.app" of container window to {160, 175}
    set position of item "Applications" of container window to {480, 175}
    set position of item "README.txt" of container window to {320, 350}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA

sync
sleep 2
hdiutil detach "/Volumes/MyWhisper" || { sleep 2; hdiutil detach "/Volumes/MyWhisper" -force; }

hdiutil convert -quiet "$RW_DMG" -format UDZO -o "$DMG"
rm -f "$RW_DMG"

echo "$DMG"
