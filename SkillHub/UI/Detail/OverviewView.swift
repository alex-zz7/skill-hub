import SwiftUI

struct OverviewView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OverviewStatsGrid(stats: store.stats)
                HStack(alignment: .top, spacing: 20) {
                    OverviewToolBreakdown(stats: store.stats)
                    OverviewHealthBox()
                }
                GroupBox {
                    ClusterMapScreen(showsHint: true)
                        .frame(minHeight: Theme.mapMinHeight)
                } label: {
                    Label("按名称前缀聚类", systemImage: "circle.hexagongrid")
                }
            }
            .padding(20)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.visible)
    }
}
