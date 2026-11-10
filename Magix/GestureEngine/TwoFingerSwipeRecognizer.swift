import Foundation

/// Recognizes discrete 2-finger vertical swipes (fire once per contact set).
final class TwoFingerSwipeRecognizer {
    var threshold: Double = 0.18

    private var startCentroidY: Double?
    private var fired = false

    func reset() {
        startCentroidY = nil
        fired = false
    }

    func process(frame: MultitouchFrame) -> RecognizedGesture? {
        let touches = frame.contacts.filter(\.isTouching)
        guard touches.count == 2 else {
            reset()
            return nil
        }

        let centroidY = touches.map(\.normalizedY).reduce(0, +) / Double(touches.count)

        if startCentroidY == nil {
            startCentroidY = centroidY
            fired = false
            return nil
        }

        guard !fired, let start = startCentroidY else { return nil }
        let delta = centroidY - start

        // Multitouch normalized Y: increasing Y is typically upward on device surface —
        // tune against live Magic Mouse frames during hardware probe.
        if delta >= threshold {
            fired = true
            return .swipeUp
        }
        if delta <= -threshold {
            fired = true
            return .swipeDown
        }
        return nil
    }
}
