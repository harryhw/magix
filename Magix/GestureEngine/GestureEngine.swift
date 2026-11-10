import Foundation

enum GestureEngineStatus: Equatable {
    case idle
    case running
    case disabled
    case needsPermissions
    case error(String)
}

enum RecognizedGesture: Equatable {
    case swipeUp
    case swipeDown
    case pinchIn
    case pinchOut
    case twoFingerScrollZoom(delta: Double)
}

/// Classifies Multitouch frames into Magix gestures and dispatches actions.
final class GestureEngine: MultitouchFrameSink {
    private let bridge = MultitouchSupportBridge()
    private let eventTap = ScrollEventTap()
    private let actions = ActionRunner()
    private let swipeRecognizer = TwoFingerSwipeRecognizer()
    private let pinchRecognizer = SoftwarePinchRecognizer()
    private let modifierChecker = ModifierGate()

    private var config: MagixConfig
    private var active = false

    init(config: MagixConfig) {
        self.config = config
        bridge.sink = self
    }

    func updateConfig(_ config: MagixConfig) {
        self.config = config
        swipeRecognizer.threshold = config.swipeThreshold
        pinchRecognizer.threshold = config.pinchThreshold
    }

    func start() {
        active = true
        bridge.start()
        eventTap.start()
    }

    func stop() {
        active = false
        eventTap.shouldSuppressConsumedScroll = false
        eventTap.stop()
        bridge.stop()
        swipeRecognizer.reset()
        pinchRecognizer.reset()
    }

    func multitouchBridge(_ bridge: MultitouchSupportBridge, didReceive frame: MultitouchFrame) {
        guard active else { return }
        guard frame.isLikelyMagicMouse || !config.magicMouseOnly else { return }

        if let swipe = swipeRecognizer.process(frame: frame) {
            handle(gesture: swipe)
            return
        }

        if config.enableSoftwarePinch, let pinch = pinchRecognizer.process(frame: frame) {
            handle(gesture: pinch)
        }
    }

    private func handle(gesture: RecognizedGesture) {
        guard let binding = config.binding(for: gesture) else { return }

        if binding.requiresModifier, !modifierChecker.isSatisfied(binding.requiredModifiers) {
            return
        }

        eventTap.shouldSuppressConsumedScroll = true
        defer { eventTap.shouldSuppressConsumedScroll = false }

        actions.perform(binding.action, zoomBackend: config.zoomBackend)
    }
}
