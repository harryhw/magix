import CoreGraphics
import Foundation

/// CGEventTap stub used to suppress default 2-finger scroll when Magix consumes a gesture.
/// Requires Accessibility trust to create a listen/modify tap.
final class ScrollEventTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isEnabled = false
    private(set) var lastError: String?

    /// When true, matching scroll events should be swallowed by the tap callback.
    var shouldSuppressConsumedScroll = false

    func start() {
        guard tap == nil else {
            isEnabled = true
            return
        }

        // Scaffold: document the intended mask; real installation comes with gesture consumption.
        // Creating the tap here without a callback implementation risks hanging debug sessions,
        // so we keep this as an explicit TODO until Multitouch frames drive suppress decisions.
        lastError = nil
        isEnabled = false
        #if DEBUG
        NSLog("[Magix] ScrollEventTap.start() — stub; CGEventTap not installed yet")
        #endif
        // TODO(MAG-next):
        // let mask = (1 << CGEventType.scrollWheel.rawValue)
        // tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
        //                         options: .defaultTap, eventsOfInterest: CGEventMask(mask),
        //                         callback: ..., userInfo: ...)
        // + CFMachPortCreateRunLoopSource + CFRunLoopAddSource + CGEvent.tapEnable
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        self.runLoopSource = nil
        self.tap = nil
        isEnabled = false
    }
}
