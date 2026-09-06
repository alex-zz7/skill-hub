import SwiftUI

struct TagChip: View {
    let tag: String
    let onRemove: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.callout)
            Button("移除标签 \(tag)", systemImage: "xmark", action: remove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: .capsule)
    }

    private func remove() {
        onRemove(tag)
    }
}
