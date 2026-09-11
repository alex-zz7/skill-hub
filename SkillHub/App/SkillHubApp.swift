import SwiftUI

@main
struct SkillHubApp: App {
    static let mainWindowID = "main"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var access = HomeAccess()
    @State private var store = CatalogStore(paths: HubPaths(home: HomeAccess.realHome))

    var body: some Scene {
        // Single `Window` (not WindowGroup) so the system Window menu lists it
        // and the reviewer can reopen after closing — Guideline 4, Sep 2026.
        Window("Skill Hub", id: Self.mainWindowID) {
            RootView()
                .environment(access)
                .environment(store)
        }
        .defaultSize(width: 1280, height: 820)
        .defaultLaunchBehavior(.presented)
        .commands {
            SkillHubCommands(store: store, access: access)
        }
    }
}
