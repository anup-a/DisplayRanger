import SwiftUI

@main
struct DisplayRangerApp: App {
    @StateObject private var manager = DisplayManager()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var loginItem = LoginItemManager()
    @StateObject private var wallpapers = WallpaperStore()

    var body: some Scene {
        WindowGroup("DisplayRanger") {
            ContentView()
                .environmentObject(manager)
                .environmentObject(profileStore)
                .environmentObject(loginItem)
                .environmentObject(wallpapers)
                .frame(minWidth: 760, minHeight: 480)
                .onAppear {
                    AppIcon.install()
                    manager.start()
                    wallpapers.refresh()
                    // Auto-apply engine observes reconfiguration and matches saved profiles.
                    AutoApplyEngine.shared.configure(manager: manager, store: profileStore)
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh Displays") { manager.refresh() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
