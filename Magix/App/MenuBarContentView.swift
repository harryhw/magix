import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle("Enable Magix", isOn: Binding(
                get: { appModel.isEnabled },
                set: { appModel.setEnabled($0) }
            ))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            statusRow

            if !appModel.permissionsStatus.isReady {
                Button("Fix Permissions…") {
                    openWindow(id: "permissions")
                }
            }

            Button("Settings…") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Magix") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(minWidth: 220)
        .onAppear {
            appModel.refreshPermissions()
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        let text: String = {
            switch appModel.engineStatus {
            case .idle: return "Status: Idle"
            case .running: return "Status: Running"
            case .disabled: return "Status: Disabled"
            case .needsPermissions: return "Status: Needs permissions"
            case .error(let message): return "Status: \(message)"
            }
        }()

        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }
}
