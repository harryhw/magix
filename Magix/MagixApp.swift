import SwiftUI

@main
struct MagixApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(appModel: appModel)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.menu)

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

    @ViewBuilder
    private var menuBarLabel: some View {
        // Prefer branded template icon; fall back to SF Symbol when permissions need attention.
        if !appModel.permissionsStatus.isReady {
            Label("Magix", systemImage: "hand.raised.fill")
        } else {
            Label {
                Text("Magix")
            } icon: {
                Image("MagixMenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            }
        }
    }
}
