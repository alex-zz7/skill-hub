import SwiftUI

/// Binds the pure `ClusterMapView` to the store: which nodes to show and what a click does.
struct ClusterMapScreen: View {
    @Environment(CatalogStore.self) private var store
    let showsHint: Bool

    var body: some View {
        ClusterMapView(
            nodes: store.clusterNodes(looseCap: 28),
            title: store.clusterTitle,
            itemCount: store.clusterItemCount,
            canGoUp: store.clusterPrefix != nil,
            replayToken: store.mapReplayToken,
            onOpen: store.open,
            onNucleusTap: store.popCluster
        )
        .overlay(alignment: .bottom) {
            if showsHint {
                Text(store.clusterPrefix == nil ? "点气泡打开一类或一项 · 点中心重新排列" : "继续点气泡往下，或点中心返回上一层")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
        }
        .overlay {
            if store.hasLoaded && store.clusterItemCount == 0 {
                ContentUnavailableView("这里还没有内容", systemImage: "circle.dashed")
            }
        }
    }
}
