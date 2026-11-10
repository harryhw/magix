import SwiftUI

struct PermissionsOnboardingView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Magix needs permissions")
                .font(.title2.weight(.semibold))

            Text("Gesture capture uses Accessibility (and may need Input Monitoring) so Magix can read Magic Mouse multitouch and suppress conflicting scroll when a gesture is consumed.")
                .foregroundStyle(.secondary)

            GroupBox("Checklist") {
                VStack(alignment: .leading, spacing: 10) {
                    permissionRow(
                        title: "Accessibility",
                        granted: appModel.permissionsStatus.accessibilityGranted,
                        actionTitle: "Open Accessibility",
                        action: PermissionsHelper.openAccessibilitySettings
                    )
                    permissionRow(
                        title: "Input Monitoring",
                        granted: appModel.permissionsStatus.inputMonitoringGranted,
                        actionTitle: "Open Input Monitoring",
                        action: PermissionsHelper.openInputMonitoringSettings
                    )
                }
                .padding(4)
            }

            HStack {
                Button("Refresh") {
                    appModel.refreshPermissions()
                    _ = appModel.permissions.requestAccessibilityPromptIfNeeded()
                }
                Spacer()
                if appModel.permissionsStatus.isReady {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Waiting for permissions", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(24)
        .onAppear {
            appModel.refreshPermissions()
            _ = appModel.permissions.requestAccessibilityPromptIfNeeded()
        }
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            Text(title)
            Spacer()
            Button(actionTitle, action: action)
                .disabled(granted)
        }
    }
}
