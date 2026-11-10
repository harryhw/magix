# Magix

macOS menu-bar utility that extends **Apple Magic Mouse** multitouch gestures beyond stock macOS.

Swipe up → Mission Control, swipe down → App Exposé, hold **⌥** and pinch to zoom. Map custom gestures in Settings.

**Requirements:** macOS 14+, Magic Mouse. Built as a universal (arm64 + x86_64) app.

---

## Install from DMG

1. Download the latest **`.dmg`** from [Releases](https://github.com/harryhw/magix/releases).
2. Open the DMG and drag **Magix** into **Applications**.
3. First launch: right-click Magix → **Open** (Gatekeeper may warn — this build is **ad-hoc signed**, not Developer ID / notarized).
4. Magix is menu-bar only (`LSUIElement`) — no Dock icon. Look for the Magix / hand icon in the menu bar.

### Permissions (required)

| Permission | Why |
|------------|-----|
| **Accessibility** | `CGEventTap` scroll suppression + synthetic keys / scroll |
| **Input Monitoring** | MultitouchSupport contact frames |

1. Launch Magix → menu bar icon → **Fix Permissions…** (or **Settings…** → Permissions).
2. Enable **Magix** under **System Settings → Privacy & Security → Accessibility** and **Input Monitoring**.
3. If Magix is missing from the list, use **+** and add the app (or **Reveal Magix.app** / **Copy path** from Settings).
4. Quit Magix and reopen once.
5. Settings → **Status**: **Frames** should climb when you touch the Magic Mouse.

Without Accessibility the engine will not run usefully; without Input Monitoring you will not get live Multitouch frames.

---

## Default gestures

| Gesture | Action | Modifiers |
|---------|--------|-----------|
| 2-finger swipe up | Mission Control | None |
| 2-finger swipe down | App Exposé | None |
| Software pinch out / in | Zoom in / out | **⌥** (Option) by default |

Zoom backend default: **Keyboard (⌘= / ⌘-)** — works in Figma and most apps. Optional backends: ⌘+scroll (Safari/Preview) or ⌃+scroll (Accessibility Zoom). Pinch mappings still require holding **⌥**.

Add or edit mappings in **Settings → Gestures** (Mission Control, App Exposé, Desktop, Launchpad, zoom, keyboard shortcut, open app).

---

## Build from source

```bash
cd ~/projects/magix   # or clone this repo
open Magix.xcodeproj
```

Or:

```bash
xcodebuild -scheme Magix -configuration Release -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build
open build/Build/Products/Release/Magix.app
```

In Xcode: select the **Magix** scheme → set your **Team** under Signing → Run.

Debug builds live under DerivedData / `build/…/Debug/Magix.app`. Prefer granting TCC to a stable path (e.g. `/Applications/Magix.app`) so permissions survive rebuilds.

### Packaging a DMG (local)

```bash
# After a Release build:
mkdir -p dist/dmg-stage
cp -R build/Build/Products/Release/Magix.app dist/dmg-stage/
ln -sf /Applications dist/dmg-stage/Applications
hdiutil create -volname Magix -srcfolder dist/dmg-stage -ov -format UDZO dist/Magix-0.1.0.dmg
```

---

## Architecture

```
Magix/
  App/              MenuBarExtra, Settings, Launch at Login, status/debug tests
  Permissions/      Accessibility + Input Monitoring helpers
  Multitouch/       Private MultitouchSupport boundary (dlopen/dlsym)
  GestureEngine/    Swipe + software-pinch recognizers
  EventTap/         CGEventTap scroll suppression while consuming gestures
  Actions/          Mission Control / Exposé / zoom (CoreDock + keyboard)
  Config/           Defaults, bindings, template catalog
```

**Private API honesty:** MultitouchSupport + `CoreDockSendNotification` (resolved from Dock.app) → **not App Store–eligible**. See `Magix/Resources/SigningNotes.md`.

**Signing status (v0.1.0):** Release DMG is **ad-hoc signed** (“Sign to Run Locally”). It is **not** Developer ID–signed and **not** notarized. Expect a Gatekeeper warning on first open until a Developer ID identity is used.

---

## Manual test checklist

1. Connect Magic Mouse → Settings → Status → **Refresh probe** → expect `fam=112` (or 113).
2. **Test Mission Control** / **Test App Exposé** buttons (no Multitouch needed).
3. Live: swipe up/down; ⌥+pinch for zoom. Watch **Last gesture** / **Last action**.
4. Disable Magix from the menu to restore stock mouse behavior.
