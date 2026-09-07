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
        .font(Theme.body.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
