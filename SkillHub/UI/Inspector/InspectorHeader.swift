import SwiftUI

struct InspectorHeader: View {
    let title: String
    let subtitle: String
    let sources: [ToolSource]
    let starred: Bool
    let onToggleStar: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.title2.bold())
                        .textSelection(.enabled)
                    Spacer()
                    Button(starred ? "取消收藏" : "收藏", systemImage: starred ? "star.fill" : "star", action: onToggleStar)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(starred ? .yellow : .secondary)
                        .help(starred ? "取消收藏" : "收藏")
                }
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack(spacing: 4) {
                    ForEach(sources, id: \.self) { source in
                        ToolBadge(source: source)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
