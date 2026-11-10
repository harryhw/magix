# Magix

Local-only macOS menu-bar utility that extends **Apple Magic Mouse** multitouch gestures.

**Status:** Scaffold (MAG-3) — UI shell, permissions helpers, gesture/action stubs, config + templates. Live MultitouchSupport wiring and CGEventTap install come next.

**Requirements:** macOS 14+, Xcode 15+ (tested against Xcode on Harry’s Mac mini).

---

## Open & build

```bash
cd ~/projects/magix
open Magix.xcodeproj
```

Or from the CLI:

```bash
cd ~/projects/magix
xcodebuild -scheme Magix -configuration Debug -derivedDataPath build build
```

Then run `build/Build/Products/Debug/Magix.app`.

In Xcode:

1. Select the **Magix** scheme.
2. Signing & Capabilities → set your **Team** (Developer ID available; do not invent identities in git).
3. Product → Run.

The app is an `LSUIElement` (Agent) — it appears in the **menu bar**, not the Dock.

---

## First-run permissions

Magix needs:

| Permission | Why |
|------------|-----|
| **Accessibility** | Required for `CGEventTap` (suppress conflicting scroll) and synthetic key/scroll events |
| **Input Monitoring** | Likely needed for Multitouch / HID contact streams on newer macOS |

From the menu bar: **Fix Permissions…**, or Settings → Permissions.

Deep links open System Settings → Privacy & Security. After granting, click **Refresh**. You may need to quit & relaunch Magix once it appears in the Accessibility list.

---

## MVP gesture defaults (configured; engine stubbed)

| Gesture | Action | Modifiers |
|---------|--------|-----------|
| 2-finger swipe up | Mission Control | None |
| 2-finger swipe down | App Exposé | None |
| Software pinch out / in | App zoom in / out | **⌥ required by default** |
| Template: “Pinch with two fingers to zoom in or out” | Zoom | Modifier-gated |

Zoom backend default: **App zoom (⌘ + scroll)**. Settings toggle planned for Accessibility Zoom (⌃ + scroll).

Custom gesture↔action **editor is not MVP** — the template catalog is data-only for now.

---

## Architecture (scaffold)

```
Magix/
  App/              MenuBarExtra, Settings, Launch at Login
  Permissions/      Accessibility + Input Monitoring probes / deep links
  Multitouch/       Private MultitouchSupport boundary (dlopen TBD)
  GestureEngine/    Swipe + software-pinch recognizers
  EventTap/         CGEventTap stub for scroll suppression
  Actions/          Mission Control / Exposé / zoom (+ Dock SPI + key fallback)
  Config/           Defaults, bindings, template catalog
```

**Private API honesty:** Reliable Magic Mouse finger geometry requires Apple’s private `MultitouchSupport.framework`. Mission Control / Exposé prefer undocumented `CoreDockSendNotification` with keyboard-shortcut fallback. This is **not Mac App Store–eligible**. Ship via **Developer ID + notarization** (later). See `Magix/Resources/SigningNotes.md`.

---

## Launch at Login

Wired via `SMAppService.mainApp`. Works best from a proper `.app` bundle. If status is “not found”, run the built app from DerivedData / Applications, not a bare binary.

---

## Repo policy

**Local only.** No GitHub remote. `git init` is fine on this machine; do not `git push` to a public host until Harry chooses hosting.

On-disk path: `/Users/hoanghai/projects/magix`
