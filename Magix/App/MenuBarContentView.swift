import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle("Enable Magix", isOn: Binding(
                get: { appModel.isEnabled },
                set: { appModel.setEnabled($0) }
            ))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Group {
                Text("Status: \(appModel.engineStatus.menuLabel)")
                Text(appModel.permissionsStatus.statusSummary)
                Text("Frames: \(appModel.frameCount)")
                Text("Last gesture: \(appModel.lastRecognized)")
                Text("Last action: \(appModel.lastActionResult)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 2)

            Divider()

            if !appModel.permissionsStatus.isReady {
                Button("Fix Permissions…") {
                    openMagixWindow(id: "permissions")
                }
            }

            Button("Refresh probe") {
                appModel.refreshProbe()
                appModel.refreshPermissions()
            }

            Button("Settings…") {
                openMagixWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Magix") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(minWidth: 260)
        .onAppear {
            appModel.refreshPermissions()
        }
    }

    private func openMagixWindow(id: String) {
        MagixWindowSupport.bringToFrontForWindow()
        openWindow(id: id)

        // Ensure the matching NSWindow becomes key after SwiftUI creates/shows it.
        DispatchQueue.main.async {
            MagixWindowSupport.bringToFrontForWindow()
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == id || $0.title.contains(id == "settings" ? "Settings" : "Permissions") }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                NSApp.windows
                    .filter(\.isVisible)
                    .forEach { $0.makeKeyAndOrderFront(nil) }
            }
        }
    }
}
