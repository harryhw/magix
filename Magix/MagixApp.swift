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

        Settings {
            SettingsView(appModel: appModel)
        }

        Window("Magix Permissions", id: "permissions") {
            PermissionsOnboardingView(appModel: appModel)
                .frame(minWidth: 420, minHeight: 320)
        }
        .windowResizability(.contentSize)
    }
}
