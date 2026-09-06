import SwiftUI

struct SidebarRow: View {
    @Environment(CatalogStore.self) private var store
    let item: SidebarItem
    let title: String
    let symbolName: String

    var body: some View {
        Label(title, systemImage: symbolName)
            .badge(item.isOverview ? 0 : store.count(for: item))
            .tag(item)
    }
}
