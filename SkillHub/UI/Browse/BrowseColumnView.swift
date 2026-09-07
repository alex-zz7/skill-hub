import SwiftUI

/// Middle column: the list that matches the sidebar selection.
struct BrowseColumnView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ClusterListView()
            .safeAreaInset(edge: .top, spacing: 0) {
                SearchBar(text: $store.searchText)
            }
            .toolbar {
                ToolbarItemGroup {
                    NewItemMenu()
                    Button("刷新", systemImage: "arrow.clockwise", action: store.refresh)
                        .disabled(store.isScanning)
                }
            }
    }
}

/// A full-width search field inside the column, large enough to read, instead of the toolbar's tiny one.
private struct SearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索", text: $text, prompt: Text("搜索名称、描述或路径"))
                .textFieldStyle(.plain)
                .labelsHidden()
                .focused($focused)
            if !text.isEmpty {
                Button("清空搜索", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .font(Theme.body)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: Theme.cornerRadius))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .onKeyPress(.escape) {
            guard !text.isEmpty else { return .ignored }
            text = ""
            return .handled
        }
    }
}
