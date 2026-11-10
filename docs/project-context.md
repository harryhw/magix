# Magix — Project Context

**Project:** Magix  
**For:** Harry Huang  
**Updated:** 2026-11-10 (AppIcon + Release DMG + GitHub publish)  
**On-disk path:** `/Users/hoanghai/projects/magix`  
**Remote:** `https://github.com/harryhw/magix`

## Goals

- Extend Apple Magic Mouse with multitouch gestures beyond stock macOS.
- Defaults: swipe up → Mission Control, swipe down → App Exposé, modifier-gated pinch zoom.
- Custom gesture ↔ action mappings in Settings (add / edit / delete, persisted).
- Clear menu-bar + Settings control UX.

## Decisions (locked)

| Decision | Choice |
|----------|--------|
| Min OS | macOS 14+ |
| UI | MenuBarExtra + `Window("Magix Settings")` |
| Input | MultitouchSupport + CGEventTap |
| Mission Control / Exposé / Desktop / Launchpad | CoreDock + keyboard fallbacks |
| Zoom | Default **⌘= / ⌘-** (Figma); optional ⌘+scroll / ⌃+scroll |
| Templates | Modifier-gated by default (⌥) |
| Repo | `https://github.com/harryhw/magix` (prefer private) |
| v0.1.0 signing | Ad-hoc only — not Developer ID / not notarized |

## What Harry can use now

**Settings → Gestures**
- Scannable list of mappings with enable toggles
- **Add Gesture** sheet: template quick-start, gesture type, action, modifiers
- Actions: Mission Control, App Exposé, Show Desktop, Launchpad, Zoom in/out, Keyboard shortcut, Open app
- Edit / delete / Restore Defaults
- Persisted in UserDefaults (`magix.config.v2`)

**Settings → Control**
- Big on/off, engine + permission status, Fix Permissions CTA, Launch at Login, zoom options

**Menu bar**
- Enable gestures, status lines, Settings…, Fix Permissions…, Quit

## Remaining stubs / caveats

- Live Multitouch frames still need Accessibility + Input Monitoring granted; tune thresholds after first live use.
- Show Desktop / Launchpad depend on CoreDock notification names; keyboard fallbacks are best-effort.
- Keyboard shortcut picker is a fixed key catalog (not a live key recorder).
- Open app uses a file path (no security-scoped bookmark renewal yet).
- 2-finger scroll-zoom recognizer kind exists in config; continuous scroll→zoom path is still lighter than swipe/pinch.
- Custom editor does not yet do per-app overrides or import/export presets.

## Hardware note (this Mac)

Magic Mouse present earlier as Multitouch family **112** (“Hoang’s Magic Mouse”).
