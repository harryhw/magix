import AppKit
import ApplicationServices
import Carbon.HIToolbox
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

    /// Keyboard / scroll actions must target the frontmost user app, not Magix Settings.
    var requiresFrontmostAppFocus: Bool {
        switch self {
        case .zoomIn, .zoomOut, .keyboardShortcut: return true
        case .missionControl, .appExpose, .showDesktop, .launchpad, .openApp, .none: return false
        }
    }
}

enum ZoomBackend: String, Codable, CaseIterable, Identifiable, Hashable {
    case keyboardChord
    case appZoom
    case accessibilityZoom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keyboardChord: return "Keyboard (⌘= / ⌘-) — Figma-friendly"
        case .appZoom: return "App zoom (⌘ + scroll)"
        case .accessibilityZoom: return "Accessibility Zoom (⌃ + scroll)"
        }
    }
}

struct ActionDeliveryResult: Equatable {
    var summary: String
    var error: String?
    var path: String
    var accessibilityTrusted: Bool
    var targetApp: String?
}

/// Runs system / zoom / custom actions with reliable CGEvent delivery.
final class ActionRunner {
    private let dock = CoreDockNotifier()

    var dockAvailable: Bool { dock.isAvailable }

    @discardableResult
    func perform(
        _ action: MagixAction,
        parameters: ActionParameters = .empty,
        zoomBackend: ZoomBackend,
        ensureFrontmostApp: Bool = true
    ) -> ActionDeliveryResult {
        let axTrusted = AXIsProcessTrusted()
        var targetName: String?

        if ensureFrontmostApp, action.requiresFrontmostAppFocus {
            targetName = Self.activateFrontmostUserApp()?.localizedName
        }

        if !axTrusted, action.requiresFrontmostAppFocus || action == .missionControl || action == .appExpose {
            // Dock SPI may still work without AX; keyboard/scroll will not.
            if action.requiresFrontmostAppFocus {
                return ActionDeliveryResult(
                    summary: action.displayTitle(parameters: parameters),
                    error: "Accessibility not trusted for \(PermissionsHelper.runningAppBundlePath) — CGEvent posts ignored",
                    path: "blocked",
                    accessibilityTrusted: false,
                    targetApp: targetName
                )
            }
        }

        let path: String
        switch action {
        case .missionControl:
            if dock.send("com.apple.expose.awake") {
                path = "CoreDock"
            } else {
                Self.synthesizeKey(keyCode: CGKeyCode(kVK_UpArrow), flags: .maskControl)
                path = "keyboard ⌃↑"
            }
        case .appExpose:
            if dock.send("com.apple.expose.front.awake") {
                path = "CoreDock"
            } else {
                Self.synthesizeKey(keyCode: CGKeyCode(kVK_DownArrow), flags: .maskControl)
                path = "keyboard ⌃↓"
            }
        case .showDesktop:
            if dock.send("com.apple.showdesktop.awake") {
                path = "CoreDock"
            } else {
                Self.synthesizeKey(keyCode: CGKeyCode(kVK_F11), flags: [])
                path = "keyboard F11"
            }
        case .launchpad:
            path = dock.send("com.apple.launchpad.toggle") ? "CoreDock" : "unavailable"
        case .zoomIn:
            path = Self.postZoom(direction: .in, backend: zoomBackend)
        case .zoomOut:
            path = Self.postZoom(direction: .out, backend: zoomBackend)
        case .keyboardShortcut:
            guard let keyCode = parameters.keyCode else {
                return ActionDeliveryResult(
                    summary: action.displayName,
                    error: "missing key",
                    path: "error",
                    accessibilityTrusted: axTrusted,
                    targetApp: targetName
                )
            }
            Self.synthesizeKey(keyCode: CGKeyCode(keyCode), flags: parameters.keyModifiers.cgEventFlags)
            path = parameters.summary.isEmpty ? "key \(keyCode)" : parameters.summary
        case .openApp:
            guard let appPath = parameters.appPath, !appPath.isEmpty else {
                return ActionDeliveryResult(
                    summary: action.displayName,
                    error: "missing app",
                    path: "error",
                    accessibilityTrusted: axTrusted,
                    targetApp: targetName
                )
            }
            let url = URL(fileURLWithPath: appPath)
            let ok = NSWorkspace.shared.open(url)
            path = ok ? url.lastPathComponent : "open failed"
        case .none:
            path = "none"
        }

        let error: String?
        if path == "unavailable" || path == "open failed" {
            error = "Action path failed: \(path)"
        } else if !axTrusted, action.requiresFrontmostAppFocus {
            error = "Posted without Accessibility — may be ignored"
        } else {
            error = nil
        }

        return ActionDeliveryResult(
            summary: "\(action.displayTitle(parameters: parameters)) via \(path)",
            error: error,
            path: path,
            accessibilityTrusted: axTrusted,
            targetApp: targetName
        )
    }

    /// Prefer Figma if running; otherwise the frontmost regular non-Magix app.
    @discardableResult
    static func activateFrontmostUserApp() -> NSRunningApplication? {
        let magixID = Bundle.main.bundleIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != magixID && !$0.isTerminated
        }
        let figma = apps.first {
            ($0.bundleIdentifier ?? "").localizedCaseInsensitiveContains("figma")
        }
        let target = figma
            ?? apps.first { $0.isActive }
            ?? apps.first
        target?.activate(options: [.activateIgnoringOtherApps])
        MagixWindowSupport.restoreAccessoryPolicyIfNeeded()
        return target
    }

    private enum ZoomDirection {
        case `in`, out
    }

    private static func postZoom(direction: ZoomDirection, backend: ZoomBackend) -> String {
        switch backend {
        case .keyboardChord:
            let keyCode = CGKeyCode(direction == .in ? kVK_ANSI_Equal : kVK_ANSI_Minus)
            synthesizeKey(keyCode: keyCode, flags: .maskCommand)
            return direction == .in ? "⌘=" : "⌘-"
        case .appZoom:
            postZoomScroll(direction: direction == .in ? 1 : -1, flags: .maskCommand)
            return "⌘scroll"
        case .accessibilityZoom:
            postZoomScroll(direction: direction == .in ? 1 : -1, flags: .maskControl)
            return "⌃scroll"
        }
    }

    private static func postZoomScroll(direction: Int32, flags: CGEventFlags) {
        // Private source so physical ⌥ (pinch gate) is not merged into the synthetic scroll.
        let source = CGEventSource(stateID: .privateState)
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 1,
            wheel1: direction * 40,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.flags = flags
        post(event)
    }

    /// Posts a key chord using a private event source so held physical modifiers
    /// (especially ⌥ required for pinch) do not contaminate ⌘=/⌘-.
    static func synthesizeKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .privateState)
        source?.localEventsSuppressionInterval = 0

        // Explicitly release common physical modifiers that are NOT part of the chord.
        let physicalReleases = interferingModifierKeyUps(desiredFlags: flags)
        for up in physicalReleases {
            post(up)
        }

        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        post(down)
        post(up)

        // Re-assert desired modifier key-ups so we don't leave synthetic ⌘ stuck down.
        for key in modifierKeyCodes(in: flags) {
            if let modUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
                modUp.flags = []
                post(modUp)
            }
        }
    }

    private static func interferingModifierKeyUps(desiredFlags: CGEventFlags) -> [CGEvent] {
        let source = CGEventSource(stateID: .privateState)
        var events: [CGEvent] = []
        let candidates: [(CGEventFlags, CGKeyCode)] = [
            (.maskAlternate, CGKeyCode(kVK_Option)),
            (.maskAlternate, CGKeyCode(kVK_RightOption)),
            (.maskShift, CGKeyCode(kVK_Shift)),
            (.maskShift, CGKeyCode(kVK_RightShift)),
            (.maskControl, CGKeyCode(kVK_Control)),
            (.maskControl, CGKeyCode(kVK_RightControl)),
            (.maskCommand, CGKeyCode(kVK_Command)),
            (.maskCommand, CGKeyCode(kVK_RightCommand)),
        ]
        for (flag, code) in candidates {
            // Release modifiers that are currently not intended for this chord.
            if !desiredFlags.contains(flag) {
                if let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) {
                    up.flags = []
                    events.append(up)
                }
            }
        }
        return events
    }

    private static func modifierKeyCodes(in flags: CGEventFlags) -> [CGKeyCode] {
        var codes: [CGKeyCode] = []
        if flags.contains(.maskCommand) { codes.append(CGKeyCode(kVK_Command)) }
        if flags.contains(.maskAlternate) { codes.append(CGKeyCode(kVK_Option)) }
        if flags.contains(.maskControl) { codes.append(CGKeyCode(kVK_Control)) }
        if flags.contains(.maskShift) { codes.append(CGKeyCode(kVK_Shift)) }
        return codes
    }

    private static func post(_ event: CGEvent) {
        // HID + session taps: some apps only see one of them for synthetic input.
        event.post(tap: .cghidEventTap)
        event.post(tap: .cgSessionEventTap)
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

    var isAvailable: Bool { sendFn != nil }

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
            Item(keyCode: UInt16(kVK_ANSI_Equal), label: "="),
            Item(keyCode: UInt16(kVK_ANSI_Minus), label: "-"),
            Item(keyCode: 49, label: "Space"), Item(keyCode: 36, label: "Return"),
            Item(keyCode: 48, label: "Tab"), Item(keyCode: 53, label: "Esc"),
            Item(keyCode: 123, label: "←"), Item(keyCode: 124, label: "→"),
            Item(keyCode: 125, label: "↓"), Item(keyCode: 126, label: "↑"),
        ])
        return list
    }()
}
