import Foundation

enum GestureEngineStatus: Equatable {
    case idle
    case running
    case disabled
    case needsPermissions
    case noMagicMouse
    case error(String)

    var menuLabel: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .disabled: return "Disabled"
        case .needsPermissions: return "Needs permissions"
        case .noMagicMouse: return "No Magic Mouse"
        case .error(let message): return message
        }
    }
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
    private var lastActionAt: TimeInterval = 0
    private let actionCooldown: TimeInterval = 0.55

    private(set) var lastRecognized: String = "—"
    private(set) var lastActionResult: String = "—"

    var probeSummary: String { bridge.probeSummary() }
    var frameCount: UInt64 { bridge.frameCount }
    var multitouchRunning: Bool { bridge.isRunning }
    var eventTapEnabled: Bool { eventTap.isEnabled }
    var eventTapError: String? { eventTap.lastError }
    var multitouchError: String? { bridge.lastError }
    var discoveredDevices: [MultitouchDeviceInfo] { bridge.discoveredDevices }

    init(config: MagixConfig) {
        self.config = config
        bridge.sink = self
        swipeRecognizer.threshold = config.swipeThreshold
        pinchRecognizer.threshold = config.pinchThreshold
    }

    func updateConfig(_ config: MagixConfig) {
        self.config = config
        swipeRecognizer.threshold = config.swipeThreshold
        pinchRecognizer.threshold = config.pinchThreshold
    }

    @discardableResult
    func start() -> GestureEngineStatus {
        active = true
        eventTap.start()
        bridge.start(magicMouseOnly: config.magicMouseOnly)

        if let error = bridge.lastError, !bridge.isRunning {
            active = false
            if error.localizedCaseInsensitiveContains("magic mouse") {
                return .noMagicMouse
            }
            return .error(error)
        }

        lastRecognized = "Listening…"
        return .running
    }

    func stop() {
        active = false
        eventTap.shouldSuppressConsumedScroll = false
        eventTap.stop()
        bridge.stop()
        swipeRecognizer.reset()
        pinchRecognizer.reset()
    }

    func probeDevices() -> [MultitouchDeviceInfo] {
        bridge.probeDevices()
    }

    /// Manual / debug: fire an action binding without Multitouch hardware.
    @discardableResult
    func debugPerform(_ action: MagixAction) -> String {
        eventTap.beginSuppressing(duration: 0.4)
        let result = actions.perform(action, zoomBackend: config.zoomBackend)
        lastRecognized = "Debug \(action.displayName)"
        lastActionResult = "\(action.displayName) via \(result)"
        return lastActionResult
    }

    /// Manual / debug: inject a synthetic 2-finger vertical swipe through recognizers.
    func debugInjectSwipe(up: Bool) {
        let y0 = 0.40
        let y1 = up ? 0.40 + config.swipeThreshold + 0.05 : 0.40 - config.swipeThreshold - 0.05
        let frames = [y0, y1].map { y -> MultitouchFrame in
            MultitouchFrame(
                deviceID: 0,
                familyID: 112,
                timestamp: ProcessInfo.processInfo.systemUptime,
                frameNumber: Int.random(in: 1...10_000),
                contacts: [
                    MultitouchContact(identifier: 1, normalizedX: 0.35, normalizedY: y, velocityX: 0, velocityY: up ? 1 : -1, size: 0.5, state: 4, isTouching: true),
                    MultitouchContact(identifier: 2, normalizedX: 0.65, normalizedY: y, velocityX: 0, velocityY: up ? 1 : -1, size: 0.5, state: 4, isTouching: true),
                ],
                isLikelyMagicMouse: true
            )
        }
        active = true
        for frame in frames {
            multitouchBridge(bridge, didReceive: frame)
        }
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

        let requiresModifier = binding.requiresModifier
            || (config.requireModifiersForTemplates && isTemplateGesture(gesture))
        if requiresModifier {
            let required = binding.requiredModifiers.isEmpty ? ModifierSet([.option]) : binding.requiredModifiers
            if !modifierChecker.isSatisfied(required) {
                lastRecognized = "\(label(for: gesture)) (hold \(required.displayName))"
                return
            }
        }

        let now = ProcessInfo.processInfo.systemUptime
        if now - lastActionAt < actionCooldown {
            return
        }
        lastActionAt = now
        lastRecognized = label(for: gesture)

        eventTap.beginSuppressing(duration: 0.5)
        let result = actions.perform(binding.action, zoomBackend: config.zoomBackend)
        lastActionResult = "\(binding.action.displayName) via \(result)"
        NSLog("[Magix] Gesture %@ → %@ (%@)", lastRecognized, binding.action.displayName, result)
    }

    private func isTemplateGesture(_ gesture: RecognizedGesture) -> Bool {
        switch gesture {
        case .pinchIn, .pinchOut, .twoFingerScrollZoom: return true
        case .swipeUp, .swipeDown: return false
        }
    }

    private func label(for gesture: RecognizedGesture) -> String {
        switch gesture {
        case .swipeUp: return "Swipe up"
        case .swipeDown: return "Swipe down"
        case .pinchIn: return "Pinch in"
        case .pinchOut: return "Pinch out"
        case .twoFingerScrollZoom(let delta): return String(format: "Scroll-zoom %.2f", delta)
        }
    }
}
