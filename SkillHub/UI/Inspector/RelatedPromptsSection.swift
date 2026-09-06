import SwiftUI

struct RelatedPromptsSection: View {
    @Environment(CatalogStore.self) private var store
    let prompt: PromptItem

    var body: some View {
        let related = store.relatedPrompts(for: prompt)
        if !related.isEmpty {
            Section("相关") {
                ForEach(related) { item in
                    Button {
                        store.select(.prompt(item))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text(item.parentSkillName ?? item.source.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
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
