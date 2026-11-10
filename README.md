# Magix

Local-only macOS menu-bar utility that extends **Apple Magic Mouse** multitouch gestures.

**Status:** MAG-4 — live MultitouchSupport probe + contact callbacks, CGEventTap scroll suppression, MVP gesture→action wiring.

**Requirements:** macOS 14+, Xcode 15+ (built on Harry’s Mac mini).

---

## Open & build

```bash
cd ~/projects/magix
open Magix.xcodeproj
```

Or:

```bash
cd ~/projects/magix
xcodebuild -scheme Magix -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Magix.app
```

In Xcode: select **Magix** scheme → set your **Team** under Signing → Run.  
The app is `LSUIElement` — menu bar only, no Dock icon.

---

## First-run permissions (required)

| Permission | Why |
|------------|-----|
| **Accessibility** | `CGEventTap` scroll suppression + synthetic keys/scroll |
| **Input Monitoring** | MultitouchSupport contact frames on modern macOS |

1. Launch Magix → menu bar icon.
2. If blocked: **Fix Permissions…** (or Settings → Permissions).
3. Enable **Magix** under Accessibility **and** Input Monitoring.
4. Quit Magix and reopen once.
5. Settings → **Status**: Frames should climb when you touch the Magic Mouse.

Engine will not stay “Running” usefully without Accessibility; Input Monitoring denial also blocks a clean ready state.

---

## Manual test checklist

### A. Permissions / probe (no gesture needed)

1. Connect Magic Mouse.
2. Settings → Status → **Refresh probe**.
3. Expect a device line with `fam=112` (or 113) labeled Magic Mouse.

### B. Action runners (no Multitouch frames needed)

In Settings → Status:

- **Test Mission Control** — should toggle Mission Control (`CoreDock` preferred).
- **Test App Exposé** — should show App Exposé / Application Windows.
- **Inject synthetic swipe up/down** — runs recognizer → same actions.

### C. Live Magic Mouse gestures (needs permissions + frames > 0)

| Gesture | Expected |
|---------|----------|
| 2-finger swipe up | Mission Control |
| 2-finger swipe down | App Exposé |
| Pinch in/out while holding **⌥** | App zoom out/in (⌘+scroll) |

Watch menu bar / Status for **Last gesture** and **Last action**.  
Disable Magix from the menu to restore stock mouse behavior.

---

## MVP bindings

| Gesture | Action | Modifiers |
|---------|--------|-----------|
| 2-finger swipe up | Mission Control | None |
| 2-finger swipe down | App Exposé | None |
| Software pinch out / in | Zoom in / out | **⌥ by default** |

Zoom backend default: **App zoom (⌘ + scroll)**; Settings can switch to Accessibility Zoom (⌃ + scroll).

---

## Architecture

```
Magix/
  App/              MenuBarExtra, Settings, Launch at Login, status/debug tests
  Permissions/      Accessibility + Input Monitoring
  Multitouch/       Private MultitouchSupport boundary (dlopen/dlsym)
  GestureEngine/    Swipe + software-pinch recognizers
  EventTap/         CGEventTap scroll suppression while consuming gestures
  Actions/          Mission Control / Exposé / zoom (CoreDock + keyboard fallback)
  Config/           Defaults, bindings, template catalog
```

**Private API honesty:** MultitouchSupport + `CoreDockSendNotification` (resolved from Dock.app) → **not App Store–eligible**. Developer ID + notarization later. See `Magix/Resources/SigningNotes.md`.

---

## Repo policy

**Local only.** No GitHub remote. Path: `/Users/hoanghai/projects/magix`
