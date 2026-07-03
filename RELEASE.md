# Releasing MyWhisper

## Free build (works today)

```sh
make dist        # → build/MyWhisper-<version>.dmg
```

Self-contained (bundled whisper-server), signed with the local "MyWhisper
Dev" certificate. Recipients must use **System Settings → Privacy &
Security → Open Anyway** once, because the build is not notarized.

## Notarized build (removes the "Open Anyway" step)

Status: **prepared but not yet verified** — requires a paid Apple Developer
account ($99/yr) that this project does not have yet. Once enrolled:

1. In Xcode (Settings → Accounts) or developer.apple.com, create a
   **Developer ID Application** certificate; install it in the login keychain.
2. Create an app-specific password (appleid.apple.com), then store notary
   credentials once:
   ```sh
   xcrun notarytool store-credentials mywhisper \
       --apple-id you@example.com --team-id TEAMID --password <app-specific>
   ```
3. Build, sign (hardened runtime + `Resources/MyWhisper.entitlements`),
   notarize, staple:
   ```sh
   MYWHISPER_SIGN_ID="Developer ID Application: Your Name (TEAMID)" \
       ./scripts/notarize.sh
   ```
   Output: `build/MyWhisper-<version>-notarized.dmg`, accepted by Gatekeeper
   with no bypass (the script runs `spctl --assess` as the final check).

Notes:
- The entitlements keep microphone capture working under the hardened
  runtime and allow ggml's dlopen'd backend dylibs
  (`disable-library-validation`); if you later bundle and re-sign every
  dylib with the same Developer ID, drop that entitlement.
- TCC permissions (mic/Accessibility) then persist across updates as long
  as the signing identity stays the same.
- Auto-update (e.g. Sparkle) also requires the stable Developer ID
  signature — add it only after notarization is in place.
