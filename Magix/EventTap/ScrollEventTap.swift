import ApplicationServices
import CoreGraphics
import Foundation

/// CGEventTap that can suppress default scroll while Magix consumes a 2-finger gesture.
/// Requires Accessibility trust (`AXIsProcessTrusted`).
final class ScrollEventTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isEnabled = false
    private(set) var lastError: String?

    private let suppressLock = NSLock()
    private var suppressUntil: CFTimeInterval = 0

    /// Keep the active tap instance reachable from the C callback.
    fileprivate static weak var active: ScrollEventTap?

    var tapPort: CFMachPort? { tap }

    /// Suppress scroll briefly after Magix fires / while a gesture is active.
    func beginSuppressing(duration: TimeInterval = 0.45) {
        suppressLock.lock()
        suppressUntil = CFAbsoluteTimeGetCurrent() + duration
        suppressLock.unlock()
    }

    func endSuppressing() {
        suppressLock.lock()
        suppressUntil = 0
        suppressLock.unlock()
    }

    var shouldSuppressConsumedScroll: Bool {
        get {
            suppressLock.lock()
            defer { suppressLock.unlock() }
            return CFAbsoluteTimeGetCurrent() < suppressUntil
        }
        set {
            if newValue {
                beginSuppressing()
            } else {
                endSuppressing()
            }
        }
    }

    func start() {
        if tap != nil {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            isEnabled = true
            Self.active = self
            return
        }

        guard AXIsProcessTrusted() else {
            lastError = "Accessibility permission required for scroll event tap"
            isEnabled = false
            return
        }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let newTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: scrollTapCallback,
            userInfo: nil
        ) else {
            lastError = "CGEvent.tapCreate failed (check Accessibility)"
            isEnabled = false
            return
        }

        tap = newTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        Self.active = self
        isEnabled = true
        lastError = nil
        NSLog("[Magix] ScrollEventTap installed")
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
        if Self.active === self {
            Self.active = nil
        }
        isEnabled = false
        endSuppressing()
    }

    fileprivate func shouldSwallowScrollEvent(_ event: CGEvent) -> Bool {
        suppressLock.lock()
        let activeSuppress = CFAbsoluteTimeGetCurrent() < suppressUntil
        suppressLock.unlock()
        guard activeSuppress else { return false }

        // Do not swallow synthetic zoom chords (⌘/⌃ + scroll) that Magix posts.
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            return false
        }
        return true
    }

    fileprivate static func reenableIfNeeded() {
        if let tap = active?.tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}

private func scrollTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        ScrollEventTap.reenableIfNeeded()
        NSLog("[Magix] ScrollEventTap re-enabled after disable (\(type.rawValue))")
        return Unmanaged.passUnretained(event)
    }

    guard type == .scrollWheel else {
        return Unmanaged.passUnretained(event)
    }

    if ScrollEventTap.active?.shouldSwallowScrollEvent(event) == true {
        return nil
    }
    return Unmanaged.passUnretained(event)
}
