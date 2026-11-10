import SwiftUI

struct PermissionsOnboardingView: View {
    @ObservedObject var appModel: AppModel
    @State private var didCopyPath = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Magix needs permissions")
                .font(.title2.weight(.semibold))
                .onAppear { MagixWindowSupport.bringToFrontForWindow() }
                .onDisappear { MagixWindowSupport.restoreAccessoryPolicyIfNeeded() }

            Text("Unsigned/debug Magix builds usually do not appear automatically. Use the + button in System Settings and choose this Magix.app, then enable the checkbox.")
                .foregroundStyle(.secondary)

            GroupBox("Add this Magix.app") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(PermissionsHelper.runningAppBundlePath)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    HStack {
                        Button("Reveal Magix.app in Finder") {
                            _ = PermissionsHelper.revealRunningAppInFinder()
                        }
                        Button(didCopyPath ? "Copied" : "Copy path") {
                            PermissionsHelper.copyRunningAppPathToPasteboard()
                            didCopyPath = true
                        }
                    }
                }
                .padding(4)
            }

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

            Text("Steps: Open the pane → click + → select Magix.app from Finder → enable Magix’s checkbox. Repeat for both Accessibility and Input Monitoring. Then quit Magix and reopen once.")
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
        .frame(minWidth: 480)
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
