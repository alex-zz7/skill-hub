import SwiftUI

struct SidebarView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: $store.sidebarSelection) {
            SidebarRow(item: .overview, title: "总览", symbolName: "chart.pie")

            Section("Skills") {
                ForEach(BrowseFilter.skillFilters) { filter in
                    SidebarRow(item: .skills(filter), title: filter.title, symbolName: filter.symbolName)
                }
            }

            Section("按工具") {
                ForEach(ToolSource.skillRoots, id: \.self) { source in
                    SidebarRow(item: .skills(.tool(source)), title: source.title, symbolName: source.symbolName)
                }
            }

            Section("Prompts") {
                ForEach(BrowseFilter.promptFilters + BrowseFilter.promptSources) { filter in
                    SidebarRow(item: .prompts(filter), title: filter.title, symbolName: filter.symbolName)
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: store.sidebarSelection) { store.sidebarDidChange() }
        .safeAreaInset(edge: .bottom) {
            SidebarFooter()
        }
    }
}
