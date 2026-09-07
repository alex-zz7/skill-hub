import SwiftUI

struct OverviewView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OverviewStatsGrid(stats: store.stats)
                    HStack(alignment: .top, spacing: 20) {
                        OverviewToolBreakdown(stats: store.stats)
                        OverviewHealthBox()
                    }
                }
                .padding(20)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: 280)

            GroupBox {
                ClusterMapScreen(showsHint: true)
                    .frame(minHeight: Theme.mapMinHeight)
                    .frame(maxHeight: .infinity)
            } label: {
                Label("按名称前缀聚类 · Skills 和 Prompts", systemImage: "circle.hexagongrid")
            }
            .padding([.horizontal, .bottom], 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.background)
        .font(Theme.body)
    }
}
