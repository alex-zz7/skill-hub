import SwiftUI

struct SidebarView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        List(selection: Binding(
            get: { store.sidebarSelection },
            set: { store.chooseSidebar($0) }
        )) {
            SidebarRow(item: .overview, title: SidebarItem.overview.title, symbolName: "chart.pie")

            Section("Skills") {
                ForEach(BrowseFilter.skillFilters) { filter in
                    SidebarRow(item: .skills(filter), title: filter.title, symbolName: filter.symbolName)
                }
            }

            Section("Prompts") {
                ForEach(BrowseFilter.promptFilters) { filter in
                    SidebarRow(item: .prompts(filter), title: filter.title, symbolName: filter.symbolName)
                }
            }

            Section("按工具") {
                ForEach(ToolSource.skillRoots, id: \.self) { source in
                    SidebarRow(item: .skills(.tool(source)), title: source.title, symbolName: source.symbolName)
                }
                ForEach(BrowseFilter.promptSources) { filter in
                    SidebarRow(item: .prompts(filter), title: filter.title, symbolName: filter.symbolName)
                }
            }
        }
        .listStyle(.sidebar)
        .font(Theme.sidebar)
        .safeAreaInset(edge: .bottom) {
            SidebarFooter()
        }
    }
}
