import Foundation

// MARK: - Private API boundary
//
// Everything that touches Apple's private MultitouchSupport.framework MUST stay in this file
// (or a sibling under Multitouch/). Do not leak `MTDeviceRef` / private typedefs into UI code.
//
// Framework path (typical):
//   /System/Library/PrivateFrameworks/MultitouchSupport.framework
//
// Symbols of interest (loaded dynamically at runtime — never link the private framework):
//   MTDeviceCreateList
//   MTRegisterContactFrameCallback
//   MTDeviceStart / MTDeviceStop
//   MTDeviceGetDeviceID / family helpers for Magic Mouse filtering
//
// Scaffold status: stubs only. Real dlopen/dlsym wiring comes after permissions + device probe.

/// Public, stable contact snapshot Magix uses above the private boundary.
struct MultitouchContact: Equatable {
    var identifier: Int
    var normalizedX: Double
    var normalizedY: Double
    var size: Double
    var isTouching: Bool
}

struct MultitouchFrame: Equatable {
    var deviceID: UInt64
    var timestamp: TimeInterval
    var contacts: [MultitouchContact]
    var isLikelyMagicMouse: Bool
}

protocol MultitouchFrameSink: AnyObject {
    func multitouchBridge(_ bridge: MultitouchSupportBridge, didReceive frame: MultitouchFrame)
}

/// Thin wrapper around MultitouchSupport. Scaffold does not load the private framework yet.
final class MultitouchSupportBridge {
    weak var sink: MultitouchFrameSink?

    private(set) var isRunning = false
    private(set) var lastError: String?

    /// Devices discovered during the last probe (empty until private API is wired).
    private(set) var discoveredDeviceIDs: [UInt64] = []

    func start() {
        // TODO(MAG-next): dlopen MultitouchSupport, enumerate MTDeviceCreateList,
        // filter Magic Mouse, register contact-frame callback, MTDeviceStart.
        isRunning = true
        lastError = nil
        discoveredDeviceIDs = []
        #if DEBUG
        NSLog("[Magix] MultitouchSupportBridge.start() — stub; private API not loaded yet")
        #endif
    }

    func stop() {
        // TODO(MAG-next): MTDeviceStop + unregister callbacks + dlclose if owned.
        isRunning = false
        #if DEBUG
        NSLog("[Magix] MultitouchSupportBridge.stop() — stub")
        #endif
    }

    /// Debug helper for future hardware probe UI.
    func probeSummary() -> String {
        if !isRunning {
            return "Multitouch bridge stopped (scaffold stub)."
        }
        return "Multitouch bridge running in stub mode — no private symbols resolved yet."
    }

    // MARK: Test / simulator injection (keeps private API out of unit paths)

    func injectDebugFrame(_ frame: MultitouchFrame) {
        sink?.multitouchBridge(self, didReceive: frame)
    }
}
