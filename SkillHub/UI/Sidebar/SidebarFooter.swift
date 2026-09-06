import SwiftUI

struct SidebarFooter: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            if store.isScanning {
                ProgressView()
                    .controlSize(.small)
                Text("正在扫描…")
            } else {
                Text("\(store.stats.uniqueSkills) skills · \(store.stats.uniquePrompts) prompts")
            }
            Spacer()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
