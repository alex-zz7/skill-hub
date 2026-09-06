import SwiftUI

struct ToolBadge: View {
    let source: ToolSource

    var body: some View {
        Text(source.title)
            .font(.caption.weight(.medium))
            .foregroundStyle(source.tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(source.tint.opacity(0.14), in: .capsule)
    }
}
