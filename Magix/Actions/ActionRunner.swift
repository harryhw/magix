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

    @discardableResult
    func perform(_ action: MagixAction, zoomBackend: ZoomBackend) -> String {
        switch action {
        case .missionControl:
            if dock.send("com.apple.expose.awake") {
                return "CoreDock"
            }
            synthesizeKey(keyCode: 126, flags: .maskControl) // ⌃↑
            return "keyboard ⌃↑"
        case .appExpose:
            if dock.send("com.apple.expose.front.awake") {
                return "CoreDock"
            }
            synthesizeKey(keyCode: 125, flags: .maskControl) // ⌃↓
            return "keyboard ⌃↓"
        case .zoomIn:
            postZoomScroll(direction: 1, backend: zoomBackend)
            return zoomBackend == .appZoom ? "⌘scroll" : "⌃scroll"
        case .zoomOut:
            postZoomScroll(direction: -1, backend: zoomBackend)
            return zoomBackend == .appZoom ? "⌘scroll" : "⌃scroll"
        case .none:
            return "none"
        }
    }

    private func postZoomScroll(direction: Int32, backend: ZoomBackend) {
        let flags: CGEventFlags = (backend == .appZoom) ? .maskCommand : .maskControl
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: direction * 40,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

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
/// `CoreDockSendNotification` lives inside Dock.app on modern macOS (not a separate Dock.framework).
final class CoreDockNotifier {
    typealias SendNotificationFn = @convention(c) (CFString, Int) -> Void

    private var sendFn: SendNotificationFn?

    init() {
        sendFn = Self.resolveSendNotification()
        #if DEBUG
        NSLog("[Magix] CoreDockSendNotification %@", sendFn == nil ? "UNRESOLVED" : "resolved")
        #endif
    }

    @discardableResult
    func send(_ name: String) -> Bool {
        guard let sendFn else { return false }
        sendFn(name as CFString, 0)
        return true
    }

    private static func resolveSendNotification() -> SendNotificationFn? {
        let candidates = [
            "/System/Library/CoreServices/Dock.app/Contents/MacOS/Dock",
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        ]
        for path in candidates {
            guard let handle = dlopen(path, RTLD_LAZY) else { continue }
            if let sym = dlsym(handle, "CoreDockSendNotification") {
                return unsafeBitCast(sym, to: SendNotificationFn.self)
            }
        }
        return nil
    }
}
