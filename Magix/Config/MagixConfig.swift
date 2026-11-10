import Foundation

struct GestureBinding: Identifiable, Codable, Hashable {
    var id: String
    var gestureKind: GestureKind
    var action: MagixAction
    var requiresModifier: Bool
    var requiredModifiers: ModifierSet
    var enabled: Bool

    var displayTitle: String {
        "\(gestureKind.displayName) → \(action.displayName)"
    }

    var summary: String {
        if requiresModifier {
            return "Requires \(requiredModifiers.displayName) · \(enabled ? "On" : "Off")"
        }
        return enabled ? "Always · On" : "Off"
    }
}

enum GestureKind: String, Codable, CaseIterable, Hashable {
    case twoFingerSwipeUp
    case twoFingerSwipeDown
    case pinchIn
    case pinchOut
    case twoFingerScrollZoom

    var displayName: String {
        switch self {
        case .twoFingerSwipeUp: return "2-finger swipe up"
        case .twoFingerSwipeDown: return "2-finger swipe down"
        case .pinchIn: return "Pinch in (software)"
        case .pinchOut: return "Pinch out (software)"
        case .twoFingerScrollZoom: return "2-finger scroll zoom"
        }
    }

    static func matching(_ gesture: RecognizedGesture) -> GestureKind? {
        switch gesture {
        case .swipeUp: return .twoFingerSwipeUp
        case .swipeDown: return .twoFingerSwipeDown
        case .pinchIn: return .pinchIn
        case .pinchOut: return .pinchOut
        case .twoFingerScrollZoom: return .twoFingerScrollZoom
        }
    }
}

struct MagixConfig: Codable, Equatable {
    var bindings: [GestureBinding]
    var zoomBackend: ZoomBackend
    var requireModifiersForTemplates: Bool
    var enableSoftwarePinch: Bool
    var magicMouseOnly: Bool
    var swipeThreshold: Double
    var pinchThreshold: Double

    static let `default` = MagixConfig(
        bindings: MagixConfig.defaultBindings,
        zoomBackend: .appZoom,
        requireModifiersForTemplates: true,
        enableSoftwarePinch: true,
        magicMouseOnly: true,
        swipeThreshold: 0.12,
        pinchThreshold: 0.05
    )

    /// MVP fixed bindings: swipes fire without modifiers; pinch/zoom templates are modifier-gated.
    static var defaultBindings: [GestureBinding] {
        [
            GestureBinding(
                id: "swipe-up-mission-control",
                gestureKind: .twoFingerSwipeUp,
                action: .missionControl,
                requiresModifier: false,
                requiredModifiers: [],
                enabled: true
            ),
            GestureBinding(
                id: "swipe-down-app-expose",
                gestureKind: .twoFingerSwipeDown,
                action: .appExpose,
                requiresModifier: false,
                requiredModifiers: [],
                enabled: true
            ),
            GestureBinding(
                id: "pinch-out-zoom-in",
                gestureKind: .pinchOut,
                action: .zoomIn,
                requiresModifier: true,
                requiredModifiers: [.option],
                enabled: true
            ),
            GestureBinding(
                id: "pinch-in-zoom-out",
                gestureKind: .pinchIn,
                action: .zoomOut,
                requiresModifier: true,
                requiredModifiers: [.option],
                enabled: true
            ),
        ]
    }

    func binding(for gesture: RecognizedGesture) -> GestureBinding? {
        guard let kind = GestureKind.matching(gesture) else { return nil }
        return bindings.first { $0.gestureKind == kind && $0.enabled }
    }
}

enum MagixConfigStore {
    static let shared = MagixConfigStoreAPI()
}

final class MagixConfigStoreAPI {
    private let defaults = UserDefaults.standard
    private let configKey = "magix.config.v1"
    private let enabledKey = "magix.enabled"

    var isEnabled: Bool {
        get {
            if defaults.object(forKey: enabledKey) == nil { return true }
            return defaults.bool(forKey: enabledKey)
        }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    func load() -> MagixConfig {
        guard let data = defaults.data(forKey: configKey) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(MagixConfig.self, from: data)
        } catch {
            return .default
        }
    }

    func save(_ config: MagixConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: configKey)
        } catch {
            #if DEBUG
            NSLog("[Magix] Failed to save config: %@", error.localizedDescription)
            #endif
        }
    }
}
