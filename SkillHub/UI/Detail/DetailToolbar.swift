import SwiftUI

struct DetailToolbar: ToolbarContent {
    let store: CatalogStore
    @Binding var inspectorVisible: Bool

    var body: some ToolbarContent {
        @Bindable var store = store
        ToolbarItemGroup {
            if let document = store.currentDocument {
                Picker("显示方式", selection: $store.documentMode) {
                    ForEach(DocumentMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(document.isReadOnly)
                .help(document.isReadOnly ? "Cursor 内置 skill 只读" : "切换预览和编辑")

                Button("保存", systemImage: "square.and.arrow.down", action: store.saveDraft)
                    .disabled(!store.isDirty)
                    .help("保存修改 (⌘S)")

                Button("气泡图", systemImage: "circle.hexagongrid", action: store.showClusterMap)
                    .help("回到当前分类的气泡图")
            } else if store.sidebarSelection != .overview || store.clusterPrefix != nil {
                Button("返回上一层", systemImage: "chevron.left", action: store.popCluster)
                    .disabled(store.clusterPrefix == nil)
                    .help("返回上一层 (⌘[)")
            }
        }

        ToolbarItem {
            Button("详情", systemImage: "sidebar.trailing", action: toggleInspector)
                .help("显示或隐藏详情")
        }
    }

    private func toggleInspector() {
        inspectorVisible.toggle()
    }
}
