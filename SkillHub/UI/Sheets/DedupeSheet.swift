import SwiftUI

struct DedupeSheet: View {
    @Environment(CatalogStore.self) private var store
    @State private var policy: DedupePolicy = .keepEntity

    var body: some View {
        SheetFrame(
            title: "一键去重",
            primaryTitle: "去重 \(store.duplicateSkills.count) 个",
            primaryEnabled: !store.duplicateSkills.isEmpty,
            primaryAction: dedupe
        ) {
            Section {
                Text("有 \(store.duplicateSkills.count) 个 skill 同时出现在多个工具目录里。选择保留哪一份，其余会被移除。Cursor 内置目录只读，不会改动。")
                    .foregroundStyle(.secondary)
            }

            Section("保留策略") {
                Picker("策略", selection: $policy) {
                    ForEach(DedupePolicy.all) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section("将处理") {
                ForEach(store.duplicateSkills.prefix(8)) { skill in
                    LabeledContent(skill.name) {
                        Text(skill.toolSources.map(\.title).joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }
                if store.duplicateSkills.count > 8 {
                    Text("…还有 \(store.duplicateSkills.count - 8) 个")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func dedupe() {
        store.dedupeAll(policy: policy)
    }
}
