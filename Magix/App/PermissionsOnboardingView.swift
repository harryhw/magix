import SwiftUI

struct PermissionsOnboardingView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Magix needs permissions")
                .font(.title2.weight(.semibold))

            Text("Accessibility is required for the scroll event tap and synthetic actions. Input Monitoring is required on modern macOS for Magic Mouse MultitouchSupport contact frames.")
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

            Text("After enabling Magix in both lists, quit and reopen the app once if frames stay at 0.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Request prompts") {
                    appModel.permissions.requestAllPrompts()
                    appModel.refreshPermissions()
                }
                Button("Refresh") {
                    appModel.refreshPermissions()
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
            appModel.permissions.requestAllPrompts()
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
