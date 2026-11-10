import SwiftUI

@main
struct MagixApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(appModel: appModel)
        } label: {
            Label("Magix", systemImage: appModel.menuBarSymbolName)
        }
        .menuBarExtraStyle(.menu)

        // Explicit Window scene — more reliable than SwiftUI `Settings` for LSUIElement apps.
        Window("Magix Settings", id: "settings") {
            SettingsView(appModel: appModel)
                .frame(minWidth: 520, minHeight: 400)
        }
        .defaultSize(width: 520, height: 420)
        .windowResizability(.contentSize)

        Window("Magix Permissions", id: "permissions") {
            PermissionsOnboardingView(appModel: appModel)
                .frame(minWidth: 420, minHeight: 320)
        }
        .windowResizability(.contentSize)
    }
}
