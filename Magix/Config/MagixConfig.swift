import Foundation

struct ActionParameters: Codable, Hashable, Equatable {
    var keyCode: UInt16?
    var keyCharacter: String?
    var keyModifiers: ModifierSet
    var appPath: String?

    static let empty = ActionParameters(keyCode: nil, keyCharacter: nil, keyModifiers: [], appPath: nil)

    var summary: String {
        if let path = appPath, !path.isEmpty {
            return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        }
        if let keyCode {
            let mods = keyModifiers.displayName == "None" ? "" : keyModifiers.displayName
            let key = keyCharacter ?? "key \(keyCode)"
            return mods.isEmpty ? key : "\(mods)\(key)"
        }
        return ""
    }
}

struct GestureBinding: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var gestureKind: GestureKind
    var action: MagixAction
    var parameters: ActionParameters
    var requiresModifier: Bool
    var requiredModifiers: ModifierSet
    var enabled: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        gestureKind: GestureKind,
        action: MagixAction,
        parameters: ActionParameters = .empty,
        requiresModifier: Bool = false,
        requiredModifiers: ModifierSet = [],
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.gestureKind = gestureKind
        self.action = action
        self.parameters = parameters
        self.requiresModifier = requiresModifier
        self.requiredModifiers = requiredModifiers
        self.enabled = enabled
    }

    var displayTitle: String {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty {
            return "\(gestureKind.displayName) → \(action.displayTitle(parameters: parameters))"
        }
        return label
    }

    var summary: String {
        var parts: [String] = [gestureKind.displayName, "→", action.displayTitle(parameters: parameters)]
        if requiresModifier {
            parts.append("· \(requiredModifiers.displayName)")
        }
        parts.append(enabled ? "· On" : "· Off")
        return parts.joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, gestureKind, action, parameters, requiresModifier, requiredModifiers, enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        gestureKind = try container.decode(GestureKind.self, forKey: .gestureKind)
        action = try container.decode(MagixAction.self, forKey: .action)
        parameters = try container.decodeIfPresent(ActionParameters.self, forKey: .parameters) ?? .empty
        requiresModifier = try container.decodeIfPresent(Bool.self, forKey: .requiresModifier) ?? false
        requiredModifiers = try container.decodeIfPresent(ModifierSet.self, forKey: .requiredModifiers) ?? []
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

enum GestureKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case twoFingerSwipeUp
    case twoFingerSwipeDown
    case twoFingerSwipeLeft
    case twoFingerSwipeRight
    case pinchIn
    case pinchOut
    case twoFingerScrollZoom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twoFingerSwipeUp: return "2-finger swipe up"
        case .twoFingerSwipeDown: return "2-finger swipe down"
        case .twoFingerSwipeLeft: return "2-finger swipe left"
        case .twoFingerSwipeRight: return "2-finger swipe right"
        case .pinchIn: return "Pinch in (software)"
        case .pinchOut: return "Pinch out (software)"
        case .twoFingerScrollZoom: return "2-finger scroll zoom"
        }
    }

    var symbolName: String {
        switch self {
        case .twoFingerSwipeUp: return "arrow.up"
        case .twoFingerSwipeDown: return "arrow.down"
        case .twoFingerSwipeLeft: return "arrow.left"
        case .twoFingerSwipeRight: return "arrow.right"
        case .pinchIn: return "minus.magnifyingglass"
        case .pinchOut: return "plus.magnifyingglass"
        case .twoFingerScrollZoom: return "arrow.up.arrow.down"
        }
    }

    /// Pinch / scroll-zoom kinds stay modifier-gated by the global template preference by default.
    var isModifierGatedTemplateKind: Bool {
        switch self {
        case .pinchIn, .pinchOut, .twoFingerScrollZoom: return true
        default: return false
        }
    }

    static func matching(_ gesture: RecognizedGesture) -> GestureKind? {
        switch gesture {
        case .swipeUp: return .twoFingerSwipeUp
        case .swipeDown: return .twoFingerSwipeDown
        case .swipeLeft: return .twoFingerSwipeLeft
        case .swipeRight: return .twoFingerSwipeRight
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

    /// Defaults: swipe up/down + modifier-gated pinch zoom.
    static var defaultBindings: [GestureBinding] {
        [
            GestureBinding(
                id: "swipe-up-mission-control",
                name: "Mission Control",
                gestureKind: .twoFingerSwipeUp,
                action: .missionControl,
                requiresModifier: false,
                requiredModifiers: [],
                enabled: true
            ),
            GestureBinding(
                id: "swipe-down-app-expose",
                name: "App Exposé",
                gestureKind: .twoFingerSwipeDown,
                action: .appExpose,
                requiresModifier: false,
                requiredModifiers: [],
                enabled: true
            ),
            GestureBinding(
                id: "pinch-out-zoom-in",
                name: "Pinch zoom in",
                gestureKind: .pinchOut,
                action: .zoomIn,
                requiresModifier: true,
                requiredModifiers: [.option],
                enabled: true
            ),
            GestureBinding(
                id: "pinch-in-zoom-out",
                name: "Pinch zoom out",
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

    mutating func upsertBinding(_ binding: GestureBinding) {
        if let index = bindings.firstIndex(where: { $0.id == binding.id }) {
            bindings[index] = binding
        } else {
            bindings.append(binding)
        }
    }

    mutating func removeBinding(id: String) {
        bindings.removeAll { $0.id == id }
    }

    mutating func resetToDefaults() {
        self = .default
    }
}

enum MagixConfigStore {
    static let shared = MagixConfigStoreAPI()
}

final class MagixConfigStoreAPI {
    private let defaults = UserDefaults.standard
    private let configKey = "magix.config.v2"
    private let legacyConfigKey = "magix.config.v1"
    private let enabledKey = "magix.enabled"

    var isEnabled: Bool {
        get {
            if defaults.object(forKey: enabledKey) == nil { return true }
            return defaults.bool(forKey: enabledKey)
        }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    func load() -> MagixConfig {
        if let data = defaults.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(MagixConfig.self, from: data) {
            return decoded
        }
        // Migrate v1 if present.
        if let legacy = defaults.data(forKey: legacyConfigKey),
           let decoded = try? JSONDecoder().decode(MagixConfig.self, from: legacy) {
            save(decoded)
            return decoded
        }
        return .default
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
