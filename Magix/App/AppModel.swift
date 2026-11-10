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

    let permissions = PermissionsHelper()
    let engine: GestureEngine

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
    }

    var menuBarSymbolName: String {
        if !permissionsStatus.isReady {
            return "hand.raised.fill"
        }
        return isEnabled ? "computermouse.fill" : "computermouse"
    }

    func refreshPermissions() {
        permissionsStatus = permissions.currentStatus()
        if isEnabled, permissionsStatus.isReady {
            startEngineIfPossible()
        } else if !permissionsStatus.isReady {
            engine.stop()
            engineStatus = .needsPermissions
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            startEngineIfPossible()
        } else {
            engine.stop()
            engineStatus = .disabled
        }
    }

    func updateConfig(_ newConfig: MagixConfig) {
        config = newConfig
        MagixConfigStore.shared.save(newConfig)
        engine.updateConfig(newConfig)
    }

    private func startEngineIfPossible() {
        refreshPermissionsQuietly()
        guard permissionsStatus.isReady else {
            engineStatus = .needsPermissions
            return
        }
        engine.start()
        engineStatus = .running
    }

    private func refreshPermissionsQuietly() {
        permissionsStatus = permissions.currentStatus()
    }
}
