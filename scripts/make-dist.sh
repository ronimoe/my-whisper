#!/usr/bin/env bash
# Build the free-download distribution zip: self-contained app +
# model downloader + install instructions.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

[[ -x vendor/whisper.cpp/build/bin/whisper-server ]] || {
  echo "vendored whisper-server missing — run 'make deps' first" >&2; exit 1; }

./scripts/make-app.sh

# The bundle must carry the self-contained server for machines without Homebrew.
[[ -x build/MyWhisper.app/Contents/Resources/bin/whisper-server ]] || {
  echo "bundled whisper-server missing from app" >&2; exit 1; }

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
