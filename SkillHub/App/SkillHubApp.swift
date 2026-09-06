import SwiftUI

@main
struct SkillHubApp: App {
    @State private var access = HomeAccess()
    @State private var store = CatalogStore(paths: HubPaths(home: HomeAccess.realHome))

    var body: some Scene {
        WindowGroup("Skill Hub") {
            RootView()
                .environment(access)
                .environment(store)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            SkillHubCommands(store: store, access: access)
        }
    }
}
