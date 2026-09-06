import SwiftUI

struct BrowseEmptyState: View {
    @Environment(CatalogStore.self) private var store
    let isEmpty: Bool
    let noun: String

    var body: some View {
        if isEmpty {
            if store.isScanning && !store.hasLoaded {
                ProgressView("正在扫描…")
            } else if store.isSearching {
                ContentUnavailableView.search(text: store.searchText)
            } else if store.clusterPrefix != nil {
                ContentUnavailableView(
                    "这一类是空的",
                    systemImage: "circle.dashed",
                    description: Text("返回上一层，或换一个分类。")
                )
            } else {
                ContentUnavailableView(
                    "还没有 \(noun)",
                    systemImage: "tray",
                    description: Text("用工具栏里的「新建」创建一个，或者换一个筛选条件。")
                )
            }
        }
    }
}
