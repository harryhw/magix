import Foundation

/// Starter templates shown in the Add Gesture sheet.
struct GestureTemplate: Identifiable, Hashable {
    var id: String
    var name: String
    var detail: String
    var gestureKind: GestureKind
    var suggestedAction: MagixAction
    var defaultModifiers: ModifierSet
    var requiresModifier: Bool
}

enum GestureTemplateCatalog {
    static let all: [GestureTemplate] = [
        GestureTemplate(
            id: "tpl-swipe-up",
            name: "Swipe up → Mission Control",
            detail: "Default. No modifier.",
            gestureKind: .twoFingerSwipeUp,
            suggestedAction: .missionControl,
            defaultModifiers: [],
            requiresModifier: false
        ),
        GestureTemplate(
            id: "tpl-swipe-down",
            name: "Swipe down → App Exposé",
            detail: "Default. No modifier.",
            gestureKind: .twoFingerSwipeDown,
            suggestedAction: .appExpose,
            defaultModifiers: [],
            requiresModifier: false
        ),
        GestureTemplate(
            id: "tpl-pinch-zoom",
            name: "Pinch with two fingers to zoom",
            detail: "Software pinch. Modifier-gated (⌥) by default.",
            gestureKind: .pinchOut,
            suggestedAction: .zoomIn,
            defaultModifiers: [.option],
            requiresModifier: true
        ),
        GestureTemplate(
            id: "tpl-scroll-zoom",
            name: "Scroll with two fingers to zoom",
            detail: "Alternate zoom path. Prefer ⌥ gate.",
            gestureKind: .twoFingerScrollZoom,
            suggestedAction: .zoomIn,
            defaultModifiers: [.option],
            requiresModifier: true
        ),
        GestureTemplate(
            id: "tpl-swipe-left",
            name: "Swipe left",
            detail: "Map to Back shortcut or Open app.",
            gestureKind: .twoFingerSwipeLeft,
            suggestedAction: .keyboardShortcut,
            defaultModifiers: [.option],
            requiresModifier: true
        ),
        GestureTemplate(
            id: "tpl-swipe-right",
            name: "Swipe right",
            detail: "Map to Forward shortcut or Open app.",
            gestureKind: .twoFingerSwipeRight,
            suggestedAction: .keyboardShortcut,
            defaultModifiers: [.option],
            requiresModifier: true
        ),
        GestureTemplate(
            id: "tpl-desktop",
            name: "Swipe up → Show Desktop",
            detail: "Alternative to Mission Control.",
            gestureKind: .twoFingerSwipeUp,
            suggestedAction: .showDesktop,
            defaultModifiers: [.option],
            requiresModifier: true
        ),
    ]
}
