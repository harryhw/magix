import Combine
import Foundation
import ServiceManagement
import SwiftUI

/// Wires macOS 13+ `SMAppService.mainApp` for Launch at Login.
/// Debug/unsigned builds may fail until the app is installed as a proper .app bundle.
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var helpText: String = ""

    var binding: Binding<Bool> {
        Binding(
            get: { self.isEnabled },
            set: { self.setEnabled($0) }
        )
    }

    init() {
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            helpText = "Magix will open when you log in."
        case .notRegistered:
            isEnabled = false
            helpText = "Not registered for login items yet."
        case .notFound:
            isEnabled = false
            helpText = "Login item service not found. Run Magix from a built .app (not a raw binary)."
        case .requiresApproval:
            isEnabled = false
            helpText = "Pending approval in System Settings → General → Login Items."
        @unknown default:
            isEnabled = false
            helpText = "Unknown login-item status."
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            helpText = "Launch at Login error: \(error.localizedDescription)"
        }
        refresh()
    }
}
