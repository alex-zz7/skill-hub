import SwiftUI

struct DetailView: View {
    @Environment(CatalogStore.self) private var store
    @Binding var inspectorVisible: Bool

    var body: some View {
        @Bindable var store = store
        Group {
            if store.sidebarSelection == .overview {
                OverviewView()
            } else if let document = store.currentDocument {
                DocumentView(document: document)
            } else {
                ClusterMapScreen(showsHint: true)
            }
        }
        .navigationTitle(store.currentDocument?.title ?? store.sidebarSelection?.title ?? "Skill Hub")
        .navigationSubtitle(store.statusMessage ?? "")
        .toolbar {
            DetailToolbar(store: store, inspectorVisible: $inspectorVisible)
        }
        .inspector(isPresented: $inspectorVisible) {
            InspectorView()
                .inspectorColumnWidth(min: 260, ideal: 310, max: 400)
        }
        .confirmationDialog(
            store.pendingConfirm?.title ?? "",
            isPresented: $store.isShowingConfirm,
            titleVisibility: .visible,
            presenting: store.pendingConfirm
        ) { action in
            Button(action.confirmTitle, role: action.isDestructive ? .destructive : nil) {
                store.perform(action)
            }
            Button("取消", role: .cancel) {}
        } message: { action in
            Text(action.message)
        }
    }
}
