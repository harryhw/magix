import AppKit

/// Helpers for showing windows from an `LSUIElement` / MenuBarExtra agent app.
/// SwiftUI `Settings` + `openSettings()` often fails silently for accessory apps:
/// the scene exists but never becomes key / stays behind other apps.
enum MagixWindowSupport {
    /// Bring Magix forward so a newly opened window is visible.
    /// Temporarily uses `.regular` activation so the window can key and appear in Cmd-Tab.
    static func bringToFrontForWindow() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Return to menu-bar agent behavior once Magix has no visible windows.
    static func restoreAccessoryPolicyIfNeeded() {
        let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeKey }
        if !hasVisibleWindow, NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
