import ApplicationServices
import AppKit
import Foundation
import IOKit.hid

struct PermissionsStatus: Equatable {
    var accessibilityGranted: Bool
    var inputMonitoringGranted: Bool
    var inputMonitoringUnknown: Bool

    /// Engine requires Accessibility. Input Monitoring must not be explicitly denied;
    /// unknown is allowed but we keep prompting until granted for reliable Multitouch frames.
    var isReady: Bool {
        accessibilityGranted && (inputMonitoringGranted || inputMonitoringUnknown)
    }

    var blocksEngine: Bool {
        !accessibilityGranted || (!inputMonitoringGranted && !inputMonitoringUnknown)
    }

    var statusSummary: String {
        if accessibilityGranted && inputMonitoringGranted {
            return "Permissions OK"
        }
        var missing: [String] = []
        if !accessibilityGranted { missing.append("Accessibility") }
        if !inputMonitoringGranted { missing.append("Input Monitoring") }
        return "Missing: " + missing.joined(separator: ", ")
    }
}

struct PermissionsHelper {
    func currentStatus() -> PermissionsStatus {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let granted = access == kIOHIDAccessTypeGranted
        let denied = access == kIOHIDAccessTypeDenied
        return PermissionsStatus(
            accessibilityGranted: AXIsProcessTrusted(),
            inputMonitoringGranted: granted,
            inputMonitoringUnknown: !granted && !denied
        )
    }

    @discardableResult
    func requestAccessibilityPromptIfNeeded() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func requestInputMonitoringIfNeeded() -> Bool {
        let status = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        if status == kIOHIDAccessTypeGranted { return true }
        return IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func requestAllPrompts() {
        _ = requestAccessibilityPromptIfNeeded()
        _ = requestInputMonitoringIfNeeded()
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
}
