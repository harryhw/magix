# Magix — Project Context

**Project:** Magix  
**For:** Harry Huang  
**Updated:** 2026-11-10 (MAG-4 live MVP bindings)  
**On-disk path:** `/Users/hoanghai/projects/magix`

## Goals

- Extend Apple Magic Mouse with useful multitouch gestures beyond stock macOS behavior.
- MVP defaults:
  - 2-finger swipe up → Mission Control
  - 2-finger swipe down → App Exposé
  - Pinch / zoom templates, **modifier-gated by default** (⌥)
- Later: custom gesture ↔ action mapping UI (catalog stubbed).

## Decisions (locked)

| Decision | Choice |
|----------|--------|
| Min OS | macOS 14+ |
| Stack | Swift + SwiftUI `MenuBarExtra` |
| Input | MultitouchSupport contact frames + CGEventTap |
| Mission Control / Exposé | `CoreDockSendNotification` from Dock.app; keyboard ⌃↑/⌃↓ fallback |
| Zoom | App zoom ⌘+scroll default; Accessibility Zoom optional |
| Templates | Modifier-gated by default; includes pinch-to-zoom |
| Repo | Local only at `/Users/hoanghai/projects/magix` |
| Signing | Developer ID available — placeholders/notes only in repo |

## What works on this Mac (2026-11-10)

**Hardware present:** “Hoang’s Magic Mouse” (Bluetooth), Multitouch family **112**, deviceID embeds `…429b33c9`.

| Capability | Verified? | Notes |
|------------|-----------|-------|
| MultitouchSupport `dlopen` + `MTDeviceCreateList` | Yes | Enumerates Magic Mouse fam=112 |
| Contact-frame callbacks delivering touches | **Pending user TCC** | CLI probe got 0 frames without Input Monitoring grant; app requests TCC on launch |
| `CoreDockSendNotification` Mission Control | Yes | Resolved from Dock.app; toggled successfully from probe |
| CGEventTap install | Code complete | Needs Accessibility trust for Magix.app |
| Synthetic swipe → action path | Yes (in-app Status tests) | Debug inject / Test Mission Control buttons |
| Live 2-finger swipe / pinch on mouse | Manual after permissions | Grant Accessibility + Input Monitoring, relaunch, confirm Frames > 0 |

## Scaffold / MVP code layout

Open: `Magix.xcodeproj`  
Live modules: `Multitouch`, `EventTap`, `GestureEngine`, `Actions`, `Permissions`, `Config`, `App`.

## Open questions

1. Git hosting when Harry wants a remote.
2. Pinch vs scroll-zoom feel after live frame tuning.
3. Whether swipe Y axis needs invert after first successful live frames.
