# Magix — Project Context

**Project:** Magix  
**For:** Harry Huang  
**Updated:** 2026-11-10 (scaffold MAG-3)  
**On-disk path:** `/Users/hoanghai/projects/magix`

## Goals

- Extend Apple Magic Mouse with useful multitouch gestures beyond stock macOS behavior.
- MVP defaults:
  - 2-finger swipe up → Mission Control
  - 2-finger swipe down → App Exposé (Application Windows)
  - Pinch / zoom templates (software pinch + scroll-zoom), **modifier-gated by default**
- Later: custom gesture ↔ action mapping UI (data model + template catalog stubbed in scaffold).
- Ship as a lightweight always-on **menu-bar** utility Harry will actually leave running.

## Constraints

- Magic Mouse is multitouch but **not** a trackpad: no physical pinch; 1-finger = scroll; 2-finger needs MultitouchSupport / event-tap work for reliable geometry.
- Meaningful implementation uses **private** `MultitouchSupport` and likely undocumented Dock notifications (`CoreDockSendNotification`) → **not App Store–eligible**.
- Needs **Accessibility** (and likely **Input Monitoring**) permissions.
- Distribution path: Developer ID signed + notarized direct download — not MAS.
- **Local-only git** for now (no GitHub remote / no push).

## Decisions (locked)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Product name | Magix | Per project brief |
| Platform | macOS only | Magic Mouse target |
| Min OS | **macOS 14+** | Locked |
| UI shape | Menu-bar app (SwiftUI `MenuBarExtra`) | Always-on utility, minimal chrome |
| Stack | Swift + SwiftUI native | Best fit for CGEvent + MultitouchSupport |
| Input strategy | MultitouchSupport contact frames + CGEventTap | Public NSTouch insufficient for Magic Mouse globally |
| Mission Control / Exposé | Prefer Dock `CoreDockSendNotification`; keyboard shortcut fallback | Most reliable toggle behavior |
| Zoom default | App zoom via Cmd+scroll (toggle for system Ctrl+scroll later) | Matches user expectation in browsers/docs |
| Zoom / custom templates | **Modifier-gated by default**; include “Pinch with two fingers to zoom in or out” | Keep normal 2-finger scroll usable |
| Custom mapping UI | Post-MVP (stub catalog only in scaffold) | Prove fixed bindings first |
| Distribution | Outside App Store, notarized Developer ID | Private API + Accessibility utility reality |
| Signing | Harry has Developer ID — wire placeholders/notes only | Do not invent identities in repo |
| Repo | **Local only** at `/Users/hoanghai/projects/magix` | No remote until Harry chooses hosting |

## Scaffold layout

Open: `Magix.xcodeproj`  
Modules under `Magix/`: `App`, `Permissions`, `Multitouch`, `GestureEngine`, `EventTap`, `Actions`, `Config`.

## Active planning docs

- Full plan: Project store `docs/magix-plan.md` (also referenced from Magix planning)
- This context: `/Users/hoanghai/projects/magix/docs/project-context.md` and Project store mirror

## Open questions (non-blocking for scaffold)

1. Git hosting location when Harry wants a remote.
2. Harry’s Magic Mouse generation confirmation for first MultitouchSupport probe.
3. Exact pinch vs 2-finger-scroll-zoom default after hardware tuning.
