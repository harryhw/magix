import AppKit
import CoreGraphics
import Darwin
import Foundation

enum MagixAction: String, Codable, CaseIterable, Identifiable, Hashable {
    case missionControl
    case appExpose
    case showDesktop
    case launchpad
    case zoomIn
    case zoomOut
    case keyboardShortcut
    case openApp
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Exposé"
        case .showDesktop: return "Show Desktop"
        case .launchpad: return "Launchpad"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        case .keyboardShortcut: return "Keyboard shortcut"
        case .openApp: return "Open app"
        case .none: return "None"
        }
    }

    func displayTitle(parameters: ActionParameters) -> String {
        switch self {
        case .keyboardShortcut:
            let detail = parameters.summary
            return detail.isEmpty ? displayName : "\(displayName) (\(detail))"
        case .openApp:
            let detail = parameters.summary
            return detail.isEmpty ? displayName : "Open \(detail)"
        default:
            return displayName
        }
    }

    var needsParameters: Bool {
        switch self {
        case .keyboardShortcut, .openApp: return true
        default: return false
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

/// Runs system / zoom / custom actions.
final class ActionRunner {
    private let dock = CoreDockNotifier()

    @discardableResult
    func perform(
        _ action: MagixAction,
        parameters: ActionParameters = .empty,
        zoomBackend: ZoomBackend
    ) -> String {
        switch action {
        case .missionControl:
            if dock.send("com.apple.expose.awake") { return "CoreDock" }
            synthesizeKey(keyCode: 126, flags: .maskControl)
            return "keyboard ⌃↑"
        case .appExpose:
            if dock.send("com.apple.expose.front.awake") { return "CoreDock" }
            synthesizeKey(keyCode: 125, flags: .maskControl)
            return "keyboard ⌃↓"
        case .showDesktop:
            if dock.send("com.apple.showdesktop.awake") { return "CoreDock" }
            // Common default: Mission Control shortcut chord isn't universal; F11 varies by keyboard.
            synthesizeKey(keyCode: 103, flags: [])
            return "keyboard F11"
        case .launchpad:
            if dock.send("com.apple.launchpad.toggle") { return "CoreDock" }
            return "unavailable"
        case .zoomIn:
            postZoomScroll(direction: 1, backend: zoomBackend)
            return zoomBackend == .appZoom ? "⌘scroll" : "⌃scroll"
        case .zoomOut:
            postZoomScroll(direction: -1, backend: zoomBackend)
            return zoomBackend == .appZoom ? "⌘scroll" : "⌃scroll"
        case .keyboardShortcut:
            guard let keyCode = parameters.keyCode else { return "missing key" }
            synthesizeKey(keyCode: CGKeyCode(keyCode), flags: parameters.keyModifiers.cgEventFlags)
            return parameters.summary.isEmpty ? "key \(keyCode)" : parameters.summary
        case .openApp:
            guard let path = parameters.appPath, !path.isEmpty else { return "missing app" }
            let url = URL(fileURLWithPath: path)
            let ok = NSWorkspace.shared.open(url)
            return ok ? url.lastPathComponent : "open failed"
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

extension ModifierSet {
    var cgEventFlags: CGEventFlags {
        var flags = CGEventFlags()
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.shift) { flags.insert(.maskShift) }
        return flags
    }
}

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

/// Common keys for the shortcut picker.
enum ShortcutKeyCatalog {
    struct Item: Identifiable, Hashable {
        var id: UInt16 { keyCode }
        var keyCode: UInt16
        var label: String
    }

    static let items: [Item] = {
        var list: [Item] = []
        let letters: [(UInt16, String)] = [
            (0, "A"), (11, "B"), (8, "C"), (2, "D"), (14, "E"), (3, "F"), (5, "G"), (4, "H"),
            (34, "I"), (38, "J"), (40, "K"), (37, "L"), (46, "M"), (45, "N"), (31, "O"), (35, "P"),
            (12, "Q"), (15, "R"), (1, "S"), (17, "T"), (32, "U"), (9, "V"), (13, "W"), (7, "X"),
            (16, "Y"), (6, "Z"),
        ]
        list.append(contentsOf: letters.map { Item(keyCode: $0.0, label: $0.1) })
        list.append(contentsOf: [
            Item(keyCode: 18, label: "1"), Item(keyCode: 19, label: "2"), Item(keyCode: 20, label: "3"),
            Item(keyCode: 21, label: "4"), Item(keyCode: 23, label: "5"), Item(keyCode: 22, label: "6"),
            Item(keyCode: 26, label: "7"), Item(keyCode: 28, label: "8"), Item(keyCode: 25, label: "9"),
            Item(keyCode: 29, label: "0"),
            Item(keyCode: 49, label: "Space"), Item(keyCode: 36, label: "Return"),
            Item(keyCode: 48, label: "Tab"), Item(keyCode: 53, label: "Esc"),
            Item(keyCode: 123, label: "←"), Item(keyCode: 124, label: "→"),
            Item(keyCode: 125, label: "↓"), Item(keyCode: 126, label: "↑"),
        ])
        return list
    }()
}
