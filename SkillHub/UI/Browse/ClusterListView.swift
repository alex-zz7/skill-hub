import SwiftUI

/// The overview's middle column: prefix groups and items ranked by how often they are opened.
struct ClusterListView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        let rows = rankedRows
        List(rows) { row in
            ClusterRowView(row: row, caption: store.caption(for: row.node), onOpen: open)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ClusterBreadcrumbBar()
        }
        .overlay {
            BrowseEmptyState(isEmpty: rows.isEmpty, noun: "skill")
        }
    }

    private var rankedRows: [ClusterRankedRow] {
        let nodes = store.clusterNodes(looseCap: nil)
        let ranked = nodes
            .map { node in (node, node.isGroup ? node.count : node.openCount) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
            }
        let top = ranked.map(\.1).max() ?? 0
        return ranked.enumerated().map { index, pair in
            ClusterRankedRow(
                node: pair.0,
                rank: index + 1,
                fraction: top > 0 ? 0.15 + Double(pair.1) / Double(top) * 0.85 : 0.5
            )
        }
    }

    private func open(_ node: ClusterNode) {
        store.open(node)
    }
}
