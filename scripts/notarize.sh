#!/usr/bin/env bash
# Notarized-distribution build. PREREQUISITES (one-time, needs a paid
# Apple Developer account — see docs/RELEASE.md):
#   1. A "Developer ID Application" certificate in the login keychain.
#   2. Credentials stored for notarytool:
#      xcrun notarytool store-credentials mywhisper \
#          --apple-id <you@example.com> --team-id <TEAMID> --password <app-specific>
# Usage:
#   MYWHISPER_SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/notarize.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SIGN_ID="${MYWHISPER_SIGN_ID:-}"
PROFILE="${MYWHISPER_NOTARY_PROFILE:-mywhisper}"
[[ -n "$SIGN_ID" ]] || { echo "set MYWHISPER_SIGN_ID to your 'Developer ID Application: …' identity" >&2; exit 1; }
security find-identity -v -p codesigning | grep -q "Developer ID Application" || {
  echo "no Developer ID Application certificate in the keychain — enroll first (docs/RELEASE.md)" >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

# Build the app + staging dir via the normal dist path (it signs ad-hoc/dev;
# we re-sign below with the Developer ID + hardened runtime).
./scripts/make-dist.sh >/dev/null
APP=build/dist/MyWhisper/MyWhisper.app

# Deep-sign with hardened runtime. Bundled helper first, then the app.
codesign --force --options runtime --timestamp --sign "$SIGN_ID" \
  "$APP/Contents/Resources/bin/whisper-server"
codesign --force --options runtime --timestamp \
  --entitlements Resources/MyWhisper.entitlements --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP"

DMG="build/MyWhisper-$VERSION-notarized.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "MyWhisper" -srcfolder build/dist/MyWhisper -ov -format UDZO "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
echo "notarized: $DMG"
spctl --assess --type open --context context:primary-signature "$DMG" && echo "Gatekeeper: accepted"
