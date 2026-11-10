import Foundation

/// Recognizes discrete 2-finger swipes in four directions (fire once per contact set).
final class TwoFingerSwipeRecognizer {
    var threshold: Double = 0.12

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

        guard max(abs(dx), abs(dy)) >= threshold else { return nil }

        fired = true
        if abs(dy) >= abs(dx) {
            return dy >= 0 ? .swipeUp : .swipeDown
        }
        return dx >= 0 ? .swipeRight : .swipeLeft
    }
}
