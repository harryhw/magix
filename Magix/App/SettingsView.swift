import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        TabView {
            ControlSettingsTab(appModel: appModel)
                .tabItem { Label("Control", systemImage: "switch.2") }

            GesturesEditorView(appModel: appModel)
                .tabItem { Label("Gestures", systemImage: "hand.draw") }

            StatusSettingsTab(appModel: appModel)
                .tabItem { Label("Status", systemImage: "waveform.path.ecg") }

            PermissionsSettingsTab(appModel: appModel)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(minWidth: 560, minHeight: 440)
        .onAppear {
            MagixWindowSupport.bringToFrontForWindow()
        }
        .onDisappear {
            MagixWindowSupport.restoreAccessoryPolicyIfNeeded()
        }
    }
}

private struct ControlSettingsTab: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Magix")
                            .font(.title2.weight(.semibold))
                        Text(engineCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(appModel.isEnabled ? "On" : "Off", isOn: Binding(
                        get: { appModel.isEnabled },
                        set: { appModel.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Enable Magix")
                }

                LabeledContent("Engine") {
                    Text(appModel.engineStatus.menuLabel)
                        .foregroundStyle(engineColor)
                }
                LabeledContent("Permissions") {
                    Text(appModel.permissionsStatus.isReady ? "Ready" : appModel.permissionsStatus.statusSummary)
                        .foregroundStyle(appModel.permissionsStatus.isReady ? .green : .orange)
                }

                if !appModel.permissionsStatus.isReady {
                    Button("Fix Permissions…") {
                        MagixWindowSupport.bringToFrontForWindow()
                        openWindow(id: "permissions")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: launchAtLogin.binding)
                Text(launchAtLogin.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Zoom defaults") {
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
                Text("Figma Desktop ignores ⌘+scroll — use Keyboard (⌘= / ⌘-). Hold ⌥ while pinching for the default zoom mappings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Enable software pinch recognition", isOn: Binding(
                    get: { appModel.config.enableSoftwarePinch },
                    set: { value in
                        var next = appModel.config
                        next.enableSoftwarePinch = value
                        appModel.updateConfig(next)
                    }
                ))

                Toggle("Magic Mouse only", isOn: Binding(
                    get: { appModel.config.magicMouseOnly },
                    set: { value in
                        var next = appModel.config
                        next.magicMouseOnly = value
                        appModel.updateConfig(next, restartEngine: true)
                    }
                ))
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.shortVersionString)
                LabeledContent("Build", value: Bundle.main.buildNumber)
                Text("Local Magic Mouse gesture utility. Outside Mac App Store.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var engineCaption: String {
        if !appModel.permissionsStatus.isReady {
            return "Waiting for Accessibility / Input Monitoring before gestures can run."
        }
        if appModel.isEnabled {
            return "Gesture engine is active. Map custom gestures in the Gestures tab."
        }
        return "Gesture engine is paused. Turn Magix on to listen for Magic Mouse gestures."
    }

    private var engineColor: Color {
        switch appModel.engineStatus {
        case .running: return .green
        case .needsPermissions, .error, .noMagicMouse: return .orange
        case .disabled: return .secondary
        case .idle: return .secondary
        }
    }
}

private struct StatusSettingsTab: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Form {
            Section("Live status") {
                LabeledContent("Engine", value: appModel.engineStatus.menuLabel)
                LabeledContent("Frames received", value: "\(appModel.frameCount)")
                LabeledContent("Last gesture", value: appModel.lastRecognized)
                LabeledContent("Last action", value: appModel.lastActionResult)
                LabeledContent("Delivery path", value: appModel.lastDeliveryPath)
                LabeledContent("Last error") {
                    Text(appModel.lastActionError)
                        .foregroundStyle(appModel.lastActionError == "—" ? Color.secondary : Color.orange)
                }
                LabeledContent("Accessibility") {
                    Text(appModel.accessibilityTrusted ? "Trusted" : "NOT trusted — actions may be ignored")
                        .foregroundStyle(appModel.accessibilityTrusted ? Color.green : Color.orange)
                }
                LabeledContent("CoreDock SPI", value: appModel.dockSPIAvailable ? "Resolved" : "Missing (keyboard fallback)")
                Text("Live gestures and Test buttons share the same delivery path. Pinch zoom still requires holding ⌥.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            Section("Manual tests") {
                Text("Fire the same events Magix would send — no gesture needed. For zoom, focus Figma first, then click Test Zoom.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Test Mission Control") { appModel.debugMissionControl() }
                Button("Test App Exposé") { appModel.debugAppExpose() }
                Button("Test Zoom In") { appModel.debugZoomIn() }
                Button("Test Zoom Out") { appModel.debugZoomOut() }
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
    @State private var didCopyPath = false

    var body: some View {
        Form {
            Section("Add Magix.app via +") {
                Text("Debug/unsigned builds often do not show up until you click + and pick Magix.app. Grant the same binary you are running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(PermissionsHelper.runningAppBundlePath)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                HStack {
                    Button("Reveal Magix.app in Finder") {
                        _ = PermissionsHelper.revealRunningAppInFinder()
                    }
                    Button(didCopyPath ? "Copied path" : "Copy path") {
                        PermissionsHelper.copyRunningAppPathToPasteboard()
                        didCopyPath = true
                    }
                }
            }

            Section("Required for gestures") {
                permissionRow(
                    title: "Accessibility",
                    detail: "Event tap + synthetic keys/scroll",
                    granted: appModel.permissionsStatus.accessibilityGranted,
                    actionTitle: "Open Accessibility"
                ) {
                    PermissionsHelper.openAccessibilitySettings()
                }

                permissionRow(
                    title: "Input Monitoring",
                    detail: "MultitouchSupport contact frames",
                    granted: appModel.permissionsStatus.inputMonitoringGranted,
                    unknown: appModel.permissionsStatus.inputMonitoringUnknown,
                    actionTitle: "Open Input Monitoring"
                ) {
                    PermissionsHelper.openInputMonitoringSettings()
                }
            }

            Section {
                Button("Refresh status") { appModel.refreshPermissions() }
                Button("Request prompts…") {
                    appModel.permissions.requestAllPrompts()
                    appModel.refreshPermissions()
                }
                Button("Open permissions guide…") {
                    MagixWindowSupport.bringToFrontForWindow()
                    openWindow(id: "permissions")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { appModel.refreshPermissions() }
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        unknown: Bool = false,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(granted ? "Granted" : (unknown ? "Not determined" : "Missing"))
                .foregroundStyle(granted ? .green : .orange)
            Button(actionTitle, action: action)
                .disabled(granted)
        }
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
