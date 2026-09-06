import SwiftUI

struct RootView: View {
    @Environment(HomeAccess.self) private var access
    @Environment(CatalogStore.self) private var store

    var body: some View {
        Group {
            switch access.status {
            case .restoring:
                ProgressView()
                    .controlSize(.large)
            case .needsGrant:
                AccessGateView()
            case .granted:
                WorkspaceView()
            }
        }
        .frame(minWidth: 960, minHeight: 600)
        .task { access.restore() }
        .onChange(of: access.isGranted) { _, granted in
            if granted { store.bootstrap() }
        }
    }
}
