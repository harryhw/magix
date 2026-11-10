import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { MagixConfigStore.shared.isEnabled = isEnabled }
    }

    @Published var permissionsStatus: PermissionsStatus
    @Published var engineStatus: GestureEngineStatus = .idle
    @Published var config: MagixConfig
    @Published var probeSummary: String = "Not probed yet"
    @Published var lastRecognized: String = "—"
    @Published var lastActionResult: String = "—"
    @Published var frameCount: UInt64 = 0

    let permissions = PermissionsHelper()
    let engine: GestureEngine

    private var statusTimer: Timer?

    init() {
        let stored = MagixConfigStore.shared.load()
        self.config = stored
        self.isEnabled = MagixConfigStore.shared.isEnabled
        self.permissionsStatus = PermissionsHelper().currentStatus()
        self.engine = GestureEngine(config: stored)
        refreshPermissions()
        if isEnabled {
            startEngineIfPossible()
        }
        startStatusPolling()
    }

    deinit {
        statusTimer?.invalidate()
    }

    var menuBarSymbolName: String {
        if !permissionsStatus.isReady {
            return "hand.raised.fill"
        }
        switch engineStatus {
        case .running:
            return isEnabled ? "computermouse.fill" : "computermouse"
        case .noMagicMouse:
            return "questionmark.circle"
        case .error:
            return "exclamationmark.triangle.fill"
        default:
            return isEnabled ? "computermouse.fill" : "computermouse"
        }
    }

    func refreshPermissions() {
        permissionsStatus = permissions.currentStatus()
        if isEnabled {
            if permissionsStatus.isReady {
                startEngineIfPossible()
            } else {
                engine.stop()
                engineStatus = .needsPermissions
            }
        } else if !permissionsStatus.isReady {
            engineStatus = .needsPermissions
        }
        refreshEngineDiagnostics()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            permissions.requestAllPrompts()
            startEngineIfPossible()
        } else {
            engine.stop()
            engineStatus = .disabled
        }
        refreshEngineDiagnostics()
    }

    func updateConfig(_ newConfig: MagixConfig, restartEngine: Bool = false) {
        config = newConfig
        MagixConfigStore.shared.save(newConfig)
        engine.updateConfig(newConfig)
        if restartEngine, isEnabled, permissionsStatus.isReady {
            engine.stop()
            startEngineIfPossible()
        }
    }

    func saveBinding(_ binding: GestureBinding) {
        var next = config
        next.upsertBinding(binding)
        updateConfig(next)
    }

    func deleteBinding(id: String) {
        var next = config
        next.removeBinding(id: id)
        updateConfig(next)
    }

    func setBindingEnabled(id: String, enabled: Bool) {
        var next = config
        guard let index = next.bindings.firstIndex(where: { $0.id == id }) else { return }
        next.bindings[index].enabled = enabled
        updateConfig(next)
    }

    func resetBindingsToDefaults() {
        var next = config
        next.resetToDefaults()
        // Preserve zoom / threshold preferences when resetting mappings only.
        next.zoomBackend = config.zoomBackend
        next.requireModifiersForTemplates = config.requireModifiersForTemplates
        next.enableSoftwarePinch = config.enableSoftwarePinch
        next.magicMouseOnly = config.magicMouseOnly
        next.swipeThreshold = config.swipeThreshold
        next.pinchThreshold = config.pinchThreshold
        next.bindings = MagixConfig.defaultBindings
        updateConfig(next)
    }

    func refreshProbe() {
        _ = engine.probeDevices()
        refreshEngineDiagnostics()
    }

    func debugMissionControl() {
        _ = engine.debugPerform(.missionControl)
        refreshEngineDiagnostics()
    }

    func debugAppExpose() {
        _ = engine.debugPerform(.appExpose)
        refreshEngineDiagnostics()
    }

    func debugInjectSwipeUp() {
        engine.debugInjectSwipe(up: true)
        refreshEngineDiagnostics()
    }

    func debugInjectSwipeDown() {
        engine.debugInjectSwipe(up: false)
        refreshEngineDiagnostics()
    }

    private func startEngineIfPossible() {
        permissionsStatus = permissions.currentStatus()
        guard permissionsStatus.isReady else {
            engine.stop()
            engineStatus = .needsPermissions
            return
        }

        permissions.requestAllPrompts()
        permissionsStatus = permissions.currentStatus()
        guard permissionsStatus.isReady else {
            engine.stop()
            engineStatus = .needsPermissions
            return
        }

        let status = engine.start()
        engineStatus = status
        refreshEngineDiagnostics()
    }

    private func startStatusPolling() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshEngineDiagnostics()
            }
        }
    }

    private func refreshEngineDiagnostics() {
        probeSummary = engine.probeSummary
        lastRecognized = engine.lastRecognized
        lastActionResult = engine.lastActionResult
        frameCount = engine.frameCount
        if isEnabled, case .running = engineStatus, !engine.multitouchRunning {
            if let err = engine.multitouchError {
                engineStatus = err.localizedCaseInsensitiveContains("magic mouse") ? .noMagicMouse : .error(err)
            }
        }
    }
}
