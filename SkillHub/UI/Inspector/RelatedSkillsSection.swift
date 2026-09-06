import SwiftUI

struct RelatedSkillsSection: View {
    @Environment(CatalogStore.self) private var store
    let skill: SkillItem

    var body: some View {
        let related = store.relatedSkills(for: skill)
        if !related.isEmpty {
            Section("相关") {
                ForEach(related) { item in
                    Button {
                        store.select(.skill(item))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            if !item.description.isEmpty {
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
