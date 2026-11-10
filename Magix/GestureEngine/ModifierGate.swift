import AppKit
import Foundation

struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    static let command = ModifierSet(rawValue: 1 << 0)
    static let option = ModifierSet(rawValue: 1 << 1)
    static let control = ModifierSet(rawValue: 1 << 2)
    static let shift = ModifierSet(rawValue: 1 << 3)

    var displayName: String {
        var parts: [String] = []
        if contains(.control) { parts.append("⌃") }
        if contains(.option) { parts.append("⌥") }
        if contains(.shift) { parts.append("⇧") }
        if contains(.command) { parts.append("⌘") }
        return parts.isEmpty ? "None" : parts.joined()
    }
}

/// Checks currently held keyboard modifiers before firing modifier-gated templates.
struct ModifierGate {
    func isSatisfied(_ required: ModifierSet) -> Bool {
        if required.isEmpty { return true }
        let flags = NSEvent.modifierFlags
        var current = ModifierSet()
        if flags.contains(.command) { current.insert(.command) }
        if flags.contains(.option) { current.insert(.option) }
        if flags.contains(.control) { current.insert(.control) }
        if flags.contains(.shift) { current.insert(.shift) }
        return current.contains(required)
    }
}
