import SwiftUI

struct SkillRowView: View {
    let skill: SkillItem
    let starred: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(skill.name)
                    .font(.headline)
                    .lineLimit(1)
                if starred {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("已收藏")
                }
                if !skill.health.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("有健康问题")
                }
                Spacer(minLength: 0)
            }
            Text(skill.description.isEmpty ? "还没有 description" : skill.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 4) {
                ForEach(skill.toolSources, id: \.self) { source in
                    ToolBadge(source: source)
                }
                if skill.isDuplicateInstall {
                    Text("\(skill.installations.count) 处")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
