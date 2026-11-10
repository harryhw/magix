import CoreFoundation
import Darwin
import Foundation
import IOKit.hid

// MARK: - Private API boundary
//
// All MultitouchSupport private symbols stay in this file.
// Loaded via dlopen/dlsym — never link the private framework.

/// Public, stable contact snapshot Magix uses above the private boundary.
struct MultitouchContact: Equatable, Sendable {
    var identifier: Int
    var normalizedX: Double
    var normalizedY: Double
    var velocityX: Double
    var velocityY: Double
    var size: Double
    var state: Int
    var isTouching: Bool
}

struct MultitouchFrame: Equatable, Sendable {
    var deviceID: UInt64
    var familyID: Int
    var timestamp: TimeInterval
    var frameNumber: Int
    var contacts: [MultitouchContact]
    var isLikelyMagicMouse: Bool
}

struct MultitouchDeviceInfo: Equatable, Sendable, Identifiable {
    var id: UInt64 { deviceID }
    var deviceID: UInt64
    var familyID: Int
    var isBuiltIn: Bool
    var isLikelyMagicMouse: Bool
    var surfaceWidth: Int
    var surfaceHeight: Int
}

protocol MultitouchFrameSink: AnyObject {
    func multitouchBridge(_ bridge: MultitouchSupportBridge, didReceive frame: MultitouchFrame)
}

/// Thin wrapper around MultitouchSupport.framework (private).
final class MultitouchSupportBridge {
    weak var sink: MultitouchFrameSink?

    private(set) var isRunning = false
    private(set) var lastError: String?
    private(set) var discoveredDevices: [MultitouchDeviceInfo] = []
    private(set) var frameCount: UInt64 = 0
    private(set) var lastFrameSummary: String = "No frames yet"

    /// Magic Mouse family IDs observed in the wild (Jitouch / peers): 112, 113.
    static let magicMouseFamilyIDs: Set<Int> = [112, 113]

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var startedDevices: [MTDeviceRef] = []
    private var retainedDeviceList: CFArray?
    private let lock = NSLock()

    // Bound C function pointers
    private var createList: MTDeviceCreateList_t?
    private var registerCallback: MTRegisterContactFrameCallbackWithRefcon_t?
    private var unregisterCallback: MTUnregisterContactFrameCallback_t?
    private var deviceStart: MTDeviceStart_t?
    private var deviceStop: MTDeviceStop_t?
    private var scheduleOnRunLoop: MTDeviceScheduleOnRunLoop_t?
    private var createRunLoopSource: MTDeviceCreateMultitouchRunLoopSource_t?
    private var getDeviceID: MTDeviceGetDeviceID_t?
    private var getFamilyID: MTDeviceGetFamilyID_t?
    private var isBuiltIn: MTDeviceIsBuiltIn_t?
    private var getSurfaceDims: MTDeviceGetSensorSurfaceDimensions_t?

    private var runLoopSources: [CFRunLoopSource] = []

    var discoveredDeviceIDs: [UInt64] { discoveredDevices.map(\.deviceID) }

    deinit {
        stop()
    }

    @discardableResult
    func loadSymbolsIfNeeded() -> Bool {
        if frameworkHandle != nil, createList != nil, registerCallback != nil, deviceStart != nil {
            return true
        }

        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            lastError = "dlopen MultitouchSupport failed: \(String(cString: dlerror()))"
            return false
        }
        frameworkHandle = handle

        createList = unsafeBitCast(dlsym(handle, "MTDeviceCreateList"), to: MTDeviceCreateList_t?.self)
        registerCallback = unsafeBitCast(
            dlsym(handle, "MTRegisterContactFrameCallbackWithRefcon"),
            to: MTRegisterContactFrameCallbackWithRefcon_t?.self
        )
        unregisterCallback = unsafeBitCast(
            dlsym(handle, "MTUnregisterContactFrameCallback"),
            to: MTUnregisterContactFrameCallback_t?.self
        )
        deviceStart = unsafeBitCast(dlsym(handle, "MTDeviceStart"), to: MTDeviceStart_t?.self)
        deviceStop = unsafeBitCast(dlsym(handle, "MTDeviceStop"), to: MTDeviceStop_t?.self)
        scheduleOnRunLoop = unsafeBitCast(
            dlsym(handle, "MTDeviceScheduleOnRunLoop"),
            to: MTDeviceScheduleOnRunLoop_t?.self
        )
        createRunLoopSource = unsafeBitCast(
            dlsym(handle, "MTDeviceCreateMultitouchRunLoopSource"),
            to: MTDeviceCreateMultitouchRunLoopSource_t?.self
        )
        getDeviceID = unsafeBitCast(dlsym(handle, "MTDeviceGetDeviceID"), to: MTDeviceGetDeviceID_t?.self)
        getFamilyID = unsafeBitCast(dlsym(handle, "MTDeviceGetFamilyID"), to: MTDeviceGetFamilyID_t?.self)
        isBuiltIn = unsafeBitCast(dlsym(handle, "MTDeviceIsBuiltIn"), to: MTDeviceIsBuiltIn_t?.self)
        getSurfaceDims = unsafeBitCast(
            dlsym(handle, "MTDeviceGetSensorSurfaceDimensions"),
            to: MTDeviceGetSensorSurfaceDimensions_t?.self
        )

        guard createList != nil, registerCallback != nil, deviceStart != nil, deviceStop != nil else {
            lastError = "Required MultitouchSupport symbols missing"
            return false
        }
        lastError = nil
        return true
    }

    /// Enumerate multitouch devices without starting callbacks.
    @discardableResult
    func probeDevices() -> [MultitouchDeviceInfo] {
        guard loadSymbolsIfNeeded(), let createList else {
            discoveredDevices = []
            return []
        }

        let list = createList().takeRetainedValue()
        let count = CFArrayGetCount(list)
        var devices: [MultitouchDeviceInfo] = []

        for index in 0..<count {
            let raw = CFArrayGetValueAtIndex(list, index)
            let device = unsafeBitCast(raw, to: MTDeviceRef.self)
            devices.append(makeDeviceInfo(device))
        }

        discoveredDevices = devices
        return devices
    }

    func start(magicMouseOnly: Bool = true) {
        stop()

        guard loadSymbolsIfNeeded() else { return }
        guard let createList, let registerCallback, let deviceStart else { return }

        // Request Input Monitoring — required on newer macOS for contact streams.
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

        let list = createList().takeRetainedValue()
        retainedDeviceList = list
        let count = CFArrayGetCount(list)
        var started: [MTDeviceRef] = []
        var infos: [MultitouchDeviceInfo] = []

        let runLoop = CFRunLoopGetMain()

        for index in 0..<count {
            let raw = CFArrayGetValueAtIndex(list, index)
            let device = unsafeBitCast(raw, to: MTDeviceRef.self)
            let info = makeDeviceInfo(device)
            infos.append(info)

            if magicMouseOnly, !info.isLikelyMagicMouse {
                continue
            }

            // Prefer refcon callback so we can recover `self`.
            registerCallback(device, multitouchContactFrameCallback, Unmanaged.passUnretained(self).toOpaque())

            if let scheduleOnRunLoop, let runLoop {
                let mode = CFRunLoopMode.defaultMode.rawValue as CFString
                scheduleOnRunLoop(
                    device,
                    Unmanaged.passUnretained(runLoop).toOpaque(),
                    Unmanaged.passUnretained(mode).toOpaque()
                )
            } else if let createRunLoopSource,
                      let sourcePtr = createRunLoopSource(device, 0),
                      let runLoop {
                let source = Unmanaged<CFRunLoopSource>.fromOpaque(sourcePtr).takeRetainedValue()
                CFRunLoopAddSource(runLoop, source, .defaultMode)
                runLoopSources.append(source)
            }

            deviceStart(device, 0)
            started.append(device)
            NSLog(
                "[Magix] Multitouch started deviceID=0x%llx family=%d magicMouse=%d",
                info.deviceID,
                info.familyID,
                info.isLikelyMagicMouse
            )
        }

        discoveredDevices = infos
        startedDevices = started
        isRunning = !started.isEmpty
        frameCount = 0

        if started.isEmpty {
            lastError = magicMouseOnly
                ? "No Magic Mouse multitouch device found (family 112/113)."
                : "No multitouch devices found."
            isRunning = false
        } else {
            lastError = nil
            lastFrameSummary = "Listening on \(started.count) device(s)…"
        }
    }

    func stop() {
        if let deviceStop {
            for device in startedDevices {
                deviceStop(device)
            }
        }

        let runLoop = CFRunLoopGetMain()
        for source in runLoopSources {
            CFRunLoopRemoveSource(runLoop, source, .defaultMode)
        }
        runLoopSources.removeAll()
        startedDevices.removeAll()
        retainedDeviceList = nil
        isRunning = false
    }

    func probeSummary() -> String {
        let devices = discoveredDevices.isEmpty ? probeDevices() : discoveredDevices
        if devices.isEmpty {
            return lastError ?? "No multitouch devices."
        }
        let lines = devices.map { info in
            let kind = info.isLikelyMagicMouse ? "Magic Mouse" : (info.isBuiltIn ? "Built-in" : "Other")
            return String(
                format: "0x%llx fam=%d %@ %dx%d",
                info.deviceID,
                info.familyID,
                kind,
                info.surfaceWidth,
                info.surfaceHeight
            )
        }
        let status = isRunning ? "running" : "stopped"
        return "Multitouch \(status) · frames=\(frameCount) · " + lines.joined(separator: " | ")
            + " · \(lastFrameSummary)"
    }

    func injectDebugFrame(_ frame: MultitouchFrame) {
        sink?.multitouchBridge(self, didReceive: frame)
    }

    // MARK: - Callback entry (from C)

    fileprivate func handleContactFrame(
        device: MTDeviceRef,
        touches: UnsafeRawPointer,
        count: Int32,
        timestamp: Double,
        frameNumber: Int32
    ) {
        let info = makeDeviceInfo(device)
        var contacts: [MultitouchContact] = []
        contacts.reserveCapacity(Int(count))
        let touchBuffer = touches.bindMemory(to: MTTouch.self, capacity: Int(count))

        for i in 0..<Int(count) {
            let touch = touchBuffer[i]
            // States commonly observed: 1=hover/start … 4–7=active/lifting. Treat nonzero size / active states as touching.
            let touching = touch.state >= 1 && touch.state <= 7 && touch.size > 0.01
            contacts.append(
                MultitouchContact(
                    identifier: Int(touch.pathIndex),
                    normalizedX: Double(touch.normalizedX),
                    normalizedY: Double(touch.normalizedY),
                    velocityX: Double(touch.velocityX),
                    velocityY: Double(touch.velocityY),
                    size: Double(touch.size),
                    state: Int(touch.state),
                    isTouching: touching
                )
            )
        }

        let frame = MultitouchFrame(
            deviceID: info.deviceID,
            familyID: info.familyID,
            timestamp: timestamp,
            frameNumber: Int(frameNumber),
            contacts: contacts,
            isLikelyMagicMouse: info.isLikelyMagicMouse
        )

        lock.lock()
        frameCount &+= 1
        let touchingCount = contacts.filter(\.isTouching).count
        lastFrameSummary = "frame #\(frameNumber) touches=\(touchingCount)/\(count)"
        lock.unlock()

        sink?.multitouchBridge(self, didReceive: frame)
    }

    private func makeDeviceInfo(_ device: MTDeviceRef) -> MultitouchDeviceInfo {
        var deviceID: UInt64 = 0
        var familyID: Int32 = 0
        var width: Int32 = 0
        var height: Int32 = 0

        getDeviceID?(device, &deviceID)
        getFamilyID?(device, &familyID)
        getSurfaceDims?(device, &width, &height)

        let builtIn = isBuiltIn?(device) ?? false
        let family = Int(familyID)
        let magic = Self.magicMouseFamilyIDs.contains(family) || (!builtIn && family != 0)

        return MultitouchDeviceInfo(
            deviceID: deviceID,
            familyID: family,
            isBuiltIn: builtIn,
            isLikelyMagicMouse: magic,
            surfaceWidth: Int(width),
            surfaceHeight: Int(height)
        )
    }
}

// MARK: - Private C types / callback

private typealias MTDeviceRef = UnsafeMutableRawPointer

private struct MTTouch {
    var frame: Int32
    var padding: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalizedX: Float
    var normalizedY: Float
    var velocityX: Float
    var velocityY: Float
    var size: Float
    var pressure: Float
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var density: Float
    var absoluteX: Float
    var absoluteVelocityX: Float
    var absoluteVelocityY: Float
    var reserved1: Int32
    var reserved2: Int32
    var zPressure: Float
}

private typealias MTDeviceCreateList_t = @convention(c) () -> Unmanaged<CFArray>
private typealias MTContactFrameCallbackWithRefcon_t = @convention(c) (
    UnsafeMutableRawPointer,
    UnsafeRawPointer,
    Int32,
    Double,
    Int32,
    UnsafeMutableRawPointer
) -> Void
private typealias MTRegisterContactFrameCallbackWithRefcon_t = @convention(c) (
    UnsafeMutableRawPointer,
    MTContactFrameCallbackWithRefcon_t,
    UnsafeMutableRawPointer
) -> Void
private typealias MTUnregisterContactFrameCallback_t = @convention(c) (
    UnsafeMutableRawPointer,
    UnsafeMutableRawPointer
) -> Void
private typealias MTDeviceStart_t = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
private typealias MTDeviceStop_t = @convention(c) (UnsafeMutableRawPointer) -> Void
private typealias MTDeviceScheduleOnRunLoop_t = @convention(c) (
    UnsafeMutableRawPointer,
    UnsafeMutableRawPointer,
    UnsafeRawPointer
) -> Void
private typealias MTDeviceCreateMultitouchRunLoopSource_t = @convention(c) (
    UnsafeMutableRawPointer,
    Int32
) -> UnsafeMutableRawPointer?
private typealias MTDeviceGetDeviceID_t = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Void
private typealias MTDeviceGetFamilyID_t = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>) -> Void
private typealias MTDeviceIsBuiltIn_t = @convention(c) (UnsafeMutableRawPointer) -> Bool
private typealias MTDeviceGetSensorSurfaceDimensions_t = @convention(c) (
    UnsafeMutableRawPointer,
    UnsafeMutablePointer<Int32>,
    UnsafeMutablePointer<Int32>
) -> Void

/// Global C callback — recovers bridge via refcon.
private func multitouchContactFrameCallback(
    device: UnsafeMutableRawPointer,
    touches: UnsafeRawPointer,
    count: Int32,
    timestamp: Double,
    frame: Int32,
    refcon: UnsafeMutableRawPointer
) {
    let bridge = Unmanaged<MultitouchSupportBridge>.fromOpaque(refcon).takeUnretainedValue()
    bridge.handleContactFrame(
        device: device,
        touches: touches,
        count: count,
        timestamp: timestamp,
        frameNumber: frame
    )
}
