import ApplicationServices
import AppKit
import Foundation
import IOKit.hid

struct PermissionsStatus: Equatable {
    var accessibilityGranted: Bool
    var inputMonitoringGranted: Bool

    /// MVP: Accessibility is required. Input Monitoring is surfaced but not yet a hard gate
    /// until MultitouchSupport probing proves it is mandatory on Harry's OS build.
    var isReady: Bool { accessibilityGranted }
}

struct PermissionsHelper {
    func currentStatus() -> PermissionsStatus {
        PermissionsStatus(
            accessibilityGranted: AXIsProcessTrusted(),
            inputMonitoringGranted: Self.isInputMonitoringGranted()
        )
    }

    /// Triggers the system Accessibility trust prompt when possible.
    @discardableResult
    func requestAccessibilityPromptIfNeeded() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    static func openLoginItemsSettings() {
        openURL("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
    }

    private static func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Best-effort Input Monitoring probe via IOHID.
    private static func isInputMonitoringGranted() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Optional prompt path for Input Monitoring (call when Multitouch path needs it).
    @discardableResult
    static func requestInputMonitoringIfNeeded() -> Bool {
        if isInputMonitoringGranted() { return true }
        return IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
}
