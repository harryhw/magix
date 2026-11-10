# Signing & Notarization Notes

## Current release builds

v0.1.0 ships **ad-hoc signed** (`codesign -s -`, identity “Sign to Run Locally”). There is **no** Developer ID Application signature and **no** notarization on the published DMG. Gatekeeper will warn on first open; use right-click → **Open**.

On this Mac, `security find-identity -v -p codesigning` currently shows an **Apple Development** identity only. Switch to **Developer ID Application** before claiming a notarized distribution.

## Local Xcode setup

1. Open `Magix.xcodeproj`.
2. Select the **Magix** target → **Signing & Capabilities**.
3. Enable **Automatically manage signing** *or* pick Development / Developer ID manually.
4. Keep bundle id `com.harryhuang.magix` stable once chosen.
5. For Gatekeeper-friendly distribution: **Developer ID Application** (not Apple Development, not Mac App Store).

## Build settings

| Setting | Scaffold value | Notes |
|---------|----------------|-------|
| `CODE_SIGN_STYLE` | `Automatic` | Change to Manual if preferred |
| `DEVELOPMENT_TEAM` | *(empty)* | Fill with Harry’s Team ID in Xcode |
| `CODE_SIGN_IDENTITY` | ad-hoc / Apple Development | Switch to Developer ID for release |
| `ENABLE_HARDENED_RUNTIME` | `YES` | Required for notarization |
| `APP_SANDBOX` | Off | Required for this utility class |

## Notarization (later — when Developer ID is available)

```bash
# After archive + export Developer ID .app:
xcrun notarytool submit Magix.zip --apple-id <apple-id> --team-id <team-id> --wait
xcrun stapler staple Magix.app
```

Do not commit secrets, app-specific passwords, `.p12` files, or notary credentials. Those patterns are listed in `.gitignore`.
