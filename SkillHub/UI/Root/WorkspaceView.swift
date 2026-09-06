import SwiftUI

struct WorkspaceView: View {
    @Environment(CatalogStore.self) private var store
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("inspectorVisible") private var inspectorVisible = true

    var body: some View {
        @Bindable var store = store
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } content: {
            BrowseColumnView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 330, max: 480)
        } detail: {
            DetailView(inspectorVisible: $inspectorVisible)
        }
        .sheet(item: $store.activeSheet, content: SheetRouterView.init)
        .alert("出错了", isPresented: $store.isShowingError) {
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.selectedSkillID) { store.selectionDidChange() }
        .onChange(of: store.selectedPromptID) { store.selectionDidChange() }
    }
}
