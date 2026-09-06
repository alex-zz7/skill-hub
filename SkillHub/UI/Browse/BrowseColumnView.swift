import SwiftUI

/// Middle column: the list that matches the sidebar selection.
struct BrowseColumnView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Group {
            switch store.sidebarSelection {
            case .overview:
                ClusterListView()
            case .prompts:
                PromptListView()
            case .skills, .none:
                SkillListView()
            }
        }
        .searchable(text: $store.searchText, prompt: "搜索名称、描述或路径")
        .toolbar {
            ToolbarItemGroup {
                NewItemMenu()
                Button("刷新", systemImage: "arrow.clockwise", action: store.refresh)
                    .disabled(store.isScanning)
            }
        }
    }
}
