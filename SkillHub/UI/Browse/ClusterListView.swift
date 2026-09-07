import SwiftUI

/// Ranked prefix groups and items — the middle-column “梯形图” for every sidebar filter.
struct ClusterListView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        let rows = rankedRows
        List(rows) { row in
            ClusterRowView(
                row: row,
                caption: store.caption(for: row.node),
                origin: store.origin(for: row.node),
                onOpen: open
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                rankBar
                ClusterBreadcrumbBar()
            }
        }
        .overlay {
            BrowseEmptyState(isEmpty: rows.isEmpty, noun: emptyNoun)
        }
    }

    private var rankBar: some View {
        @Bindable var store = store
        return HStack(spacing: 12) {
            Picker("排序", selection: $store.rankMode) {
                ForEach(RankMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)
            .frame(maxWidth: 220)
            .help("按调用：调用次数多的在前；按最近：最近用过的在前，长期没用的沉底")
            Spacer()
            Text(store.rankMode == .calls ? "条越长调用越多" : "条越长用得越近")
                .font(Theme.hint)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var emptyNoun: String {
        if store.sidebarSelection?.isOverview == true { String(localized: "条目") }
        else if store.sidebarSelection?.isPrompts == true { "prompt" }
        else { "skill" }
    }

    private var rankedRows: [ClusterRankedRow] {
        let nodes = store.clusterNodes(looseCap: nil)
        switch store.rankMode {
        case .calls:
            return rankByCalls(nodes)
        case .recent:
            return rankByRecency(nodes)
        }
    }

    private func rankByCalls(_ nodes: [ClusterNode]) -> [ClusterRankedRow] {
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

    /// Most recent call first; never-called items go last, ordered by name. Bar length is how recent.
    private func rankByRecency(_ nodes: [ClusterNode]) -> [ClusterRankedRow] {
        let now = Date.now
        let ranked = nodes.sorted { lhs, rhs in
            switch (lhs.lastInvokedAt, rhs.lastInvokedAt) {
            case let (l?, r?) where l != r: return l > r
            case (.some, .none): return true
            case (.none, .some): return false
            default: return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
        let horizon = Double(UsageScore.staleAfterDays * 2)
        return ranked.enumerated().map { index, node in
            let fraction: Double
            if let days = UsageScore.daysSinceUse(node.lastInvokedAt, now: now) {
                fraction = 0.15 + max(0, 1 - Double(days) / horizon) * 0.85
            } else {
                fraction = 0.08
            }
            return ClusterRankedRow(node: node, rank: index + 1, fraction: fraction)
        }
    }

    private func open(_ node: ClusterNode) {
        store.open(node)
    }
}
