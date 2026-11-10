import AppKit
import SwiftUI

/// MenuBarExtra `.menu` style flattens layout views: each `Text` in an `HStack`
/// becomes its own disabled menu row. Keep status as single-string Text items.
struct MenuBarContentView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Enable gestures", isOn: Binding(
            get: { appModel.isEnabled },
            set: { appModel.setEnabled($0) }
        ))

        Divider()

        Text(primaryStatusLine)
        Text(secondaryStatusLine)

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

        Divider()

        Button("Quit Magix") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
        .onAppear {
            appModel.refreshPermissions()
        }
    }

    private var primaryStatusLine: String {
        let engine = appModel.engineStatus.menuLabel
        let permissions = appModel.permissionsStatus.isReady ? "ready" : "needs attention"
        return "Engine: \(engine) · Permissions: \(permissions)"
    }

    private var secondaryStatusLine: String {
        let last = appModel.lastRecognized.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastPart = (last.isEmpty || last == "—") ? "none" : last
        return "Frames: \(appModel.frameCount) · Last: \(lastPart)"
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
