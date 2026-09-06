import SwiftUI

/// Shows where the user is inside a prefix drill-down, with a way back up.
struct ClusterBreadcrumbBar: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        if !store.clusterPath.isEmpty {
            HStack(spacing: 8) {
                Button("返回上一层", systemImage: "chevron.left", action: store.popCluster)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("返回上一层")
                Text(store.clusterPath.joined(separator: " › "))
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Button("清除", action: store.resetClusters)
                    .buttonStyle(.borderless)
                    .font(.callout)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}
