import Foundation

/// Software pinch: tracks inter-finger distance delta across Multitouch frames.
/// Magic Mouse has no physical pinch — this is a distance-change heuristic.
final class SoftwarePinchRecognizer {
    var threshold: Double = 0.06

    private var startDistance: Double?
    private var fired = false

    func reset() {
        startDistance = nil
        fired = false
    }

    func process(frame: MultitouchFrame) -> RecognizedGesture? {
        let touches = frame.contacts.filter(\.isTouching)
        guard touches.count == 2 else {
            reset()
            return nil
        }

        let a = touches[0]
        let b = touches[1]
        let dx = a.normalizedX - b.normalizedX
        let dy = a.normalizedY - b.normalizedY
        let distance = sqrt(dx * dx + dy * dy)

        if startDistance == nil {
            startDistance = distance
            fired = false
            return nil
        }

        guard !fired, let start = startDistance, start > 0 else { return nil }
        let delta = distance - start

        if delta >= threshold {
            fired = true
            return .pinchOut
        }
        if delta <= -threshold {
            fired = true
            return .pinchIn
        }
        return nil
    }
}
