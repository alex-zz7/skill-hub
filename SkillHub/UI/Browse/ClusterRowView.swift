import SwiftUI

struct ClusterRowView: View {
    let row: ClusterRankedRow
    let caption: String
    let onOpen: (ClusterNode) -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: row.node.isGroup ? "folder.fill" : "doc.text")
                        .foregroundStyle(Theme.tint(for: row.node.title))
                        .accessibilityHidden(true)
                    Text(row.node.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if row.node.isGroup {
                        Text("\(row.node.count)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                ProgressView(value: row.fraction)
                    .tint(Theme.tint(for: row.node.title))
                    .accessibilityHidden(true)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.node.isGroup ? "\(row.node.title)，\(row.node.count) 个" : row.node.title)
        .accessibilityHint(row.node.isGroup ? "打开这一类" : "打开")
    }

    private func open() {
        onOpen(row.node)
    }
}
