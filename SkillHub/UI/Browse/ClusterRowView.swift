import SwiftUI

struct ClusterRowView: View {
    let row: ClusterRankedRow
    let caption: String
    var origin: String = ""
    let onOpen: (ClusterNode) -> Void

    private var staleness: Double {
        UsageScore.staleness(lastInvokedAt: row.node.lastInvokedAt, modifiedAt: row.node.modifiedAt)
    }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Image(systemName: row.node.isGroup ? "folder.fill" : "doc.text")
                        .font(Theme.body)
                        .foregroundStyle(Theme.tint(for: row.node.title))
                        .accessibilityHidden(true)
                    Text(row.node.title)
                        .font(Theme.rowTitle)
                        .lineLimit(1)
                    Spacer()
                    if row.node.isGroup {
                        Text("\(row.node.count)")
                            .font(Theme.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(Theme.secondary)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    } else if staleness >= 1 {
                        Image(systemName: "zzz")
                            .font(Theme.secondary)
                            .foregroundStyle(.tertiary)
                            .help("超过 \(UsageScore.staleAfterDays) 天没被调用")
                            .accessibilityLabel("长期没用")
                    }
                }
                ProgressView(value: row.fraction)
                    .tint(Theme.tint(for: row.node.title))
                    .accessibilityHidden(true)
                Text(caption)
                    .font(Theme.secondary)
                    .foregroundStyle(.secondary)
                if !origin.isEmpty {
                    Text(origin)
                        .font(Theme.tertiary)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 6)
            .contentShape(.rect)
            .saturation(1 - staleness * 0.75)
            .opacity(1 - staleness * 0.3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.node.isGroup ? Text("\(row.node.title)，\(row.node.count) 个") : Text(row.node.title))
        .accessibilityHint(row.node.isGroup ? "打开这一类" : "打开")
    }

    private func open() {
        onOpen(row.node)
    }
}
