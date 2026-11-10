# Signing & Notarization Notes

Harry has a **Developer ID** certificate. This scaffold intentionally does **not** invent team IDs or identity names.

## Local Xcode setup (on Harry’s Mac)

1. Open `Magix.xcodeproj`.
2. Select the **Magix** target → **Signing & Capabilities**.
3. Enable **Automatically manage signing** *or* pick your Development / Developer ID identity manually.
4. Set **Bundle Identifier** if `com.harryhuang.magix` is unavailable (keep it stable once chosen).
5. For distribution builds, use **Developer ID Application** (not Apple Development, not Mac App Store).

## Build settings placeholders

| Setting | Scaffold value | Notes |
|---------|----------------|-------|
| `CODE_SIGN_STYLE` | `Automatic` | Change to Manual if preferred |
| `DEVELOPMENT_TEAM` | *(empty)* | Fill with Harry’s Team ID in Xcode |
| `CODE_SIGN_IDENTITY` | `-` / Apple Development default | Switch to Developer ID for release |
| `ENABLE_HARDENED_RUNTIME` | `YES` | Required for notarization |
| `APP_SANDBOX` | Off | Required for this utility class |

## Notarization (later)

```bash
# After archive + export Developer ID .app:
xcrun notarytool submit Magix.zip --apple-id <apple-id> --team-id <team-id> --wait
xcrun stapler staple Magix.app
```

Do not commit secrets, app-specific passwords, or identity names that are not Harry’s.
