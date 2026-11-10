import AppKit
import CoreGraphics
import Darwin
import Foundation

enum MagixAction: String, Codable, CaseIterable, Identifiable, Hashable {
    case missionControl
    case appExpose
    case zoomIn
    case zoomOut
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Exposé"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        case .none: return "None"
        }
    }
}

enum ZoomBackend: String, Codable, CaseIterable, Identifiable, Hashable {
    case appZoom
    case accessibilityZoom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appZoom: return "App zoom (⌘ + scroll)"
        case .accessibilityZoom: return "Accessibility Zoom (⌃ + scroll)"
        }
    }
}

/// Runs system / zoom actions. Private Dock SPI is isolated here behind dlsym.
final class ActionRunner {
    private let dock = CoreDockNotifier()

    func perform(_ action: MagixAction, zoomBackend: ZoomBackend) {
        switch action {
        case .missionControl:
            if !dock.send("com.apple.expose.awake") {
                synthesizeKey(keyCode: 126, flags: .maskControl) // ⌃↑
            }
        case .appExpose:
            if !dock.send("com.apple.expose.front.awake") {
                synthesizeKey(keyCode: 125, flags: .maskControl) // ⌃↓
            }
        case .zoomIn:
            postZoomScroll(direction: 1, backend: zoomBackend)
        case .zoomOut:
            postZoomScroll(direction: -1, backend: zoomBackend)
        case .none:
            break
        }
    }

    /// Posts a continuous scroll wheel event with the zoom modifier held.
    private func postZoomScroll(direction: Int32, backend: ZoomBackend) {
        let flags: CGEventFlags = (backend == .appZoom) ? .maskCommand : .maskControl
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: direction * 30,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    /// Keyboard shortcut fallback when Dock SPI is unavailable.
    private func synthesizeKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

/// Private Dock notification adapter.
/// Preferred: `CoreDockSendNotification` via dlsym from the Dock / SkyLight stack.
/// Fallback: documented in ActionRunner (keyboard shortcuts).
final class CoreDockNotifier {
    typealias SendNotificationFn = @convention(c) (CFString, Int) -> Void

    private var sendFn: SendNotificationFn?

    init() {
        // Scaffold: attempt resolution but tolerate failure.
        // Symbol historically lives in Dock / private frameworks depending on OS version.
        // We probe common images without hard-linking.
        sendFn = Self.resolveSendNotification()
    }

    @discardableResult
    func send(_ name: String) -> Bool {
        guard let sendFn else {
            #if DEBUG
            NSLog("[Magix] CoreDockSendNotification unresolved — using keyboard fallback for %@", name)
            #endif
            return false
        }
        sendFn(name as CFString, 0)
        return true
    }

    private static func resolveSendNotification() -> SendNotificationFn? {
        let handle = dlopen("/System/Library/PrivateFrameworks/Dock.framework/Dock", RTLD_LAZY)
            ?? dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        guard let handle else { return nil }
        guard let sym = dlsym(handle, "CoreDockSendNotification") else { return nil }
        return unsafeBitCast(sym, to: SendNotificationFn.self)
    }
}
