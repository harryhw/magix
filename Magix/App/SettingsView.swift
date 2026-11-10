import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        TabView {
            GeneralSettingsTab(appModel: appModel)
                .tabItem { Label("General", systemImage: "gearshape") }

            GesturesSettingsTab(appModel: appModel)
                .tabItem { Label("Gestures", systemImage: "hand.draw") }

            StatusSettingsTab(appModel: appModel)
                .tabItem { Label("Status", systemImage: "waveform.path.ecg") }

            PermissionsSettingsTab(appModel: appModel)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(minWidth: 520, minHeight: 400)
        .onAppear {
            MagixWindowSupport.bringToFrontForWindow()
        }
        .onDisappear {
            MagixWindowSupport.restoreAccessoryPolicyIfNeeded()
        }
    }
}

private struct GeneralSettingsTab: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some View {
        Form {
            Section("Magix") {
                Toggle("Enable Magix", isOn: Binding(
                    get: { appModel.isEnabled },
                    set: { appModel.setEnabled($0) }
                ))

                Toggle("Launch at Login", isOn: launchAtLogin.binding)
                Text(launchAtLogin.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.shortVersionString)
                LabeledContent("Build", value: Bundle.main.buildNumber)
                Text("Local utility for Magic Mouse multitouch gestures. Outside Mac App Store.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct GesturesSettingsTab: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Form {
            Section("MVP bindings") {
                ForEach(appModel.config.bindings) { binding in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(binding.displayTitle)
                            .font(.body.weight(.medium))
                        Text(binding.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Templates (post-MVP editor stub)") {
                Text("Custom gesture↔action editing is not in MVP. Templates below are data-model stubs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(GestureTemplateCatalog.all) { template in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                        Text(template.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Zoom") {
                Picker("Zoom backend", selection: Binding(
                    get: { appModel.config.zoomBackend },
                    set: { backend in
                        var next = appModel.config
                        next.zoomBackend = backend
                        appModel.updateConfig(next)
                    }
                )) {
                    ForEach(ZoomBackend.allCases) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }

                Toggle("Require modifiers for template actions", isOn: Binding(
                    get: { appModel.config.requireModifiersForTemplates },
                    set: { value in
                        var next = appModel.config
                        next.requireModifiersForTemplates = value
                        appModel.updateConfig(next)
                    }
                ))
                Text("Pinch/zoom templates stay modifier-gated (⌥ by default) so normal 2-finger scroll remains usable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct StatusSettingsTab: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Form {
            Section("Engine") {
                LabeledContent("Status", value: appModel.engineStatus.menuLabel)
                LabeledContent("Frames received", value: "\(appModel.frameCount)")
                LabeledContent("Last gesture", value: appModel.lastRecognized)
                LabeledContent("Last action", value: appModel.lastActionResult)
            }

            Section("Multitouch probe") {
                Text(appModel.probeSummary)
                    .font(.caption)
                    .textSelection(.enabled)
                Button("Refresh probe") {
                    appModel.refreshProbe()
                    appModel.refreshPermissions()
                }
            }

            Section("Manual test (no Multitouch required)") {
                Text("These fire action runners / synthetic recognizer frames to verify the stack before permissions unlock live mouse frames.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Test Mission Control") { appModel.debugMissionControl() }
                Button("Test App Exposé") { appModel.debugAppExpose() }
                Button("Inject synthetic swipe up") { appModel.debugInjectSwipeUp() }
                Button("Inject synthetic swipe down") { appModel.debugInjectSwipeDown() }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            appModel.refreshProbe()
            appModel.refreshPermissions()
        }
    }
}

private struct PermissionsSettingsTab: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                LabeledContent("Accessibility") {
                    Text(appModel.permissionsStatus.accessibilityGranted ? "Granted" : "Missing")
                        .foregroundStyle(appModel.permissionsStatus.accessibilityGranted ? .green : .orange)
                }
                LabeledContent("Input Monitoring") {
                    Text(inputMonitoringLabel)
                        .foregroundStyle(appModel.permissionsStatus.inputMonitoringGranted ? .green : .orange)
                }
                Text(appModel.permissionsStatus.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Refresh status") {
                    appModel.refreshPermissions()
                }
                Button("Request prompts…") {
                    appModel.permissions.requestAllPrompts()
                    appModel.refreshPermissions()
                }
                Button("Open permissions guide…") {
                    MagixWindowSupport.bringToFrontForWindow()
                    openWindow(id: "permissions")
                }
                Button("Open System Settings → Accessibility") {
                    PermissionsHelper.openAccessibilitySettings()
                }
                Button("Open System Settings → Input Monitoring") {
                    PermissionsHelper.openInputMonitoringSettings()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { appModel.refreshPermissions() }
    }

    private var inputMonitoringLabel: String {
        if appModel.permissionsStatus.inputMonitoringGranted { return "Granted" }
        if appModel.permissionsStatus.inputMonitoringUnknown { return "Not determined" }
        return "Denied"
    }
}

private extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
