import SwiftUI

struct PromptRowView: View {
    let prompt: PromptItem
    let starred: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(prompt.title)
                    .font(.headline)
                    .lineLimit(1)
                if starred {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("已收藏")
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text(prompt.kind.title)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: .capsule)
                Text(prompt.parentSkillName ?? prompt.source.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}
