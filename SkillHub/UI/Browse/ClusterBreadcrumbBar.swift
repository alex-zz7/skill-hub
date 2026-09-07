import SwiftUI

/// Shows where the user is inside a prefix drill-down, with a way back up.
/// The whole chevron + path label is one button so the text itself goes back, not just the tiny arrow.
struct ClusterBreadcrumbBar: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        if !store.clusterPath.isEmpty {
            HStack(spacing: 8) {
                Button(action: store.popCluster) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(Theme.body.weight(.semibold))
                        Text(store.clusterPath.joined(separator: " › "))
                            .font(Theme.body.weight(.medium))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 6)
                    .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .help("返回上一层")
                .accessibilityLabel("返回上一层")
                Spacer()
                Button("清除", action: store.resetClusters)
                    .buttonStyle(.borderless)
                    .font(Theme.body)
                    .help("回到顶层")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}
