import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Magix")
                    .font(.headline)
                Spacer()
                Text(appModel.isEnabled ? "On" : "Off")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appModel.isEnabled ? .green : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)

            Toggle("Enable gestures", isOn: Binding(
                get: { appModel.isEnabled },
                set: { appModel.setEnabled($0) }
            ))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            Group {
                labeled("Engine", appModel.engineStatus.menuLabel)
                labeled("Permissions", appModel.permissionsStatus.isReady ? "Ready" : "Need attention")
                labeled("Frames", "\(appModel.frameCount)")
                labeled("Last", appModel.lastRecognized)
            }
            .padding(.vertical, 4)

            Divider()

            if !appModel.permissionsStatus.isReady {
                Button("Fix Permissions…") {
                    openMagixWindow(id: "permissions")
                }
            }

            Button("Settings…") {
                openMagixWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Refresh status") {
                appModel.refreshProbe()
                appModel.refreshPermissions()
            }

            Divider()

            Button("Quit Magix") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(minWidth: 240)
        .onAppear {
            appModel.refreshPermissions()
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 1)
    }

    private func openMagixWindow(id: String) {
        MagixWindowSupport.bringToFrontForWindow()
        openWindow(id: id)

        DispatchQueue.main.async {
            MagixWindowSupport.bringToFrontForWindow()
            if let window = NSApp.windows.first(where: {
                $0.title.localizedCaseInsensitiveContains(id == "settings" ? "Settings" : "Permissions")
            }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                NSApp.windows.filter(\.isVisible).forEach { $0.makeKeyAndOrderFront(nil) }
            }
        }
    }
}
