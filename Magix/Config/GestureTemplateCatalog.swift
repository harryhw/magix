import Foundation

/// Post-MVP editor will bind these templates to actions.
/// Scaffold ships the catalog only — no visual editor yet.
struct GestureTemplate: Identifiable, Hashable {
    var id: String
    var name: String
    var detail: String
    var gestureKind: GestureKind
    var suggestedAction: MagixAction
    var defaultModifiers: ModifierSet
}

enum GestureTemplateCatalog {
    static let all: [GestureTemplate] = [
        GestureTemplate(
            id: "tpl-swipe-up",
            name: "Swipe up with two fingers",
            detail: "MVP default → Mission Control (no modifier).",
            gestureKind: .twoFingerSwipeUp,
            suggestedAction: .missionControl,
            defaultModifiers: []
        ),
        GestureTemplate(
            id: "tpl-swipe-down",
            name: "Swipe down with two fingers",
            detail: "MVP default → App Exposé (no modifier).",
            gestureKind: .twoFingerSwipeDown,
            suggestedAction: .appExpose,
            defaultModifiers: []
        ),
        GestureTemplate(
            id: "tpl-pinch-zoom",
            name: "Pinch with two fingers to zoom in or out",
            detail: "Software pinch on Magic Mouse. Modifier-gated by default (⌥) so normal scroll stays usable.",
            gestureKind: .pinchOut,
            suggestedAction: .zoomIn,
            defaultModifiers: [.option]
        ),
        GestureTemplate(
            id: "tpl-scroll-zoom",
            name: "Scroll with two fingers to zoom",
            detail: "Alternate zoom gesture (2-finger vertical motion → zoom). Prefer modifier gate.",
            gestureKind: .twoFingerScrollZoom,
            suggestedAction: .zoomIn,
            defaultModifiers: [.option]
        ),
        GestureTemplate(
            id: "tpl-swipe-left",
            name: "Swipe left with two fingers",
            detail: "Reserved for post-MVP custom actions (e.g. Back).",
            gestureKind: .twoFingerSwipeDown, // placeholder kind until horizontal kinds exist
            suggestedAction: .none,
            defaultModifiers: [.option]
        ),
        GestureTemplate(
            id: "tpl-swipe-right",
            name: "Swipe right with two fingers",
            detail: "Reserved for post-MVP custom actions (e.g. Forward).",
            gestureKind: .twoFingerSwipeUp, // placeholder kind until horizontal kinds exist
            suggestedAction: .none,
            defaultModifiers: [.option]
        ),
    ]
}
