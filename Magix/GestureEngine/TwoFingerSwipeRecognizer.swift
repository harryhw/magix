import Foundation

/// Recognizes discrete 2-finger vertical swipes (fire once per contact set).
final class TwoFingerSwipeRecognizer {
    var threshold: Double = 0.12
    /// Reject swipes that drift too far horizontally relative to vertical travel.
    var maxHorizontalRatio: Double = 0.85

    private var startCentroidX: Double?
    private var startCentroidY: Double?
    private var fired = false

    func reset() {
        startCentroidX = nil
        startCentroidY = nil
        fired = false
    }

    func process(frame: MultitouchFrame) -> RecognizedGesture? {
        let touches = frame.contacts.filter(\.isTouching)
        guard touches.count == 2 else {
            reset()
            return nil
        }

        let centroidX = touches.map(\.normalizedX).reduce(0, +) / 2
        let centroidY = touches.map(\.normalizedY).reduce(0, +) / 2

        if startCentroidY == nil {
            startCentroidX = centroidX
            startCentroidY = centroidY
            fired = false
            return nil
        }

        guard !fired, let startX = startCentroidX, let startY = startCentroidY else { return nil }

        let dx = centroidX - startX
        let dy = centroidY - startY

        // Prefer velocity if fingers report meaningful motion.
        let avgVY = touches.map(\.velocityY).reduce(0, +) / 2
        let vertical = abs(dy) >= abs(avgVY) * 0.002 ? dy : avgVY

        if abs(dx) > abs(vertical) * maxHorizontalRatio, abs(vertical) < threshold {
            return nil
        }

        // On Magic Mouse, increasing normalized Y is toward the front of the mouse
        // (user's "swipe up" / away from themselves) in practice for family 112 — tune if inverted.
        if vertical >= threshold {
            fired = true
            return .swipeUp
        }
        if vertical <= -threshold {
            fired = true
            return .swipeDown
        }
        return nil
    }
}
