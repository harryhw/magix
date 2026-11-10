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
    case swipeLeft
    case swipeRight
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

    @discardableResult
    func debugPerform(_ action: MagixAction, parameters: ActionParameters = .empty) -> String {
        eventTap.beginSuppressing(duration: 0.4)
        let result = actions.perform(action, parameters: parameters, zoomBackend: config.zoomBackend)
        lastRecognized = "Debug \(action.displayName)"
        lastActionResult = "\(action.displayTitle(parameters: parameters)) via \(result)"
        return lastActionResult
    }

    func debugInjectSwipe(up: Bool) {
        debugInjectSwipe(direction: up ? .swipeUp : .swipeDown)
    }

    func debugInjectSwipe(direction: RecognizedGesture) {
        let frames: [MultitouchFrame]
        switch direction {
        case .swipeUp, .swipeDown:
            let up = direction == .swipeUp
            let y0 = 0.40
            let y1 = up ? 0.40 + config.swipeThreshold + 0.05 : 0.40 - config.swipeThreshold - 0.05
            frames = [y0, y1].map { y in
                frame(contacts: [
                    contact(id: 1, x: 0.35, y: y, vy: up ? 1 : -1),
                    contact(id: 2, x: 0.65, y: y, vy: up ? 1 : -1),
                ])
            }
        case .swipeLeft, .swipeRight:
            let right = direction == .swipeRight
            let x0 = 0.40
            let x1 = right ? 0.40 + config.swipeThreshold + 0.05 : 0.40 - config.swipeThreshold - 0.05
            frames = [x0, x1].map { x in
                frame(contacts: [
                    contact(id: 1, x: x, y: 0.45, vx: right ? 1 : -1),
                    contact(id: 2, x: x, y: 0.55, vx: right ? 1 : -1),
                ])
            }
        default:
            return
        }

        active = true
        swipeRecognizer.reset()
        for item in frames {
            multitouchBridge(bridge, didReceive: item)
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
            || (config.requireModifiersForTemplates && binding.gestureKind.isModifierGatedTemplateKind)
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
        let result = actions.perform(
            binding.action,
            parameters: binding.parameters,
            zoomBackend: config.zoomBackend
        )
        lastActionResult = "\(binding.action.displayTitle(parameters: binding.parameters)) via \(result)"
        NSLog("[Magix] Gesture %@ → %@ (%@)", lastRecognized, lastActionResult, result)
    }

    private func label(for gesture: RecognizedGesture) -> String {
        switch gesture {
        case .swipeUp: return "Swipe up"
        case .swipeDown: return "Swipe down"
        case .swipeLeft: return "Swipe left"
        case .swipeRight: return "Swipe right"
        case .pinchIn: return "Pinch in"
        case .pinchOut: return "Pinch out"
        case .twoFingerScrollZoom(let delta): return String(format: "Scroll-zoom %.2f", delta)
        }
    }

    private func contact(id: Int, x: Double, y: Double, vx: Double = 0, vy: Double = 0) -> MultitouchContact {
        MultitouchContact(
            identifier: id,
            normalizedX: x,
            normalizedY: y,
            velocityX: vx,
            velocityY: vy,
            size: 0.5,
            state: 4,
            isTouching: true
        )
    }

    private func frame(contacts: [MultitouchContact]) -> MultitouchFrame {
        MultitouchFrame(
            deviceID: 0,
            familyID: 112,
            timestamp: ProcessInfo.processInfo.systemUptime,
            frameNumber: Int.random(in: 1...10_000),
            contacts: contacts,
            isLikelyMagicMouse: true
        )
    }
}
