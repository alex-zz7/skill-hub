import SwiftUI

struct OverviewHealthBox: View {
    @Environment(CatalogStore.self) private var store
    @State private var scanProjects = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("缺少 description") {
                    Text(store.stats.missingDescriptions, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("损坏的符号链接") {
                    Text(store.stats.brokenLinks, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("重复安装") {
                    Text(store.stats.duplicateSkills, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("同名但不是同一份") {
                    Text(store.stats.sameNameSkills, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("超过 \(UsageScore.staleAfterDays) 天没用") {
                    Text(store.count(for: .skills(.stale)), format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                if !store.duplicateSkills.isEmpty {
                    Button("一键去重 \(store.duplicateSkills.count) 个…", action: dedupe)
                }

                Divider()

                Toggle("同时扫描 ~/Projects 里各项目的 skill", isOn: $scanProjects)
                    .onChange(of: scanProjects) { _, enabled in
                        store.setScanProjectSkills(enabled)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("健康", systemImage: "heart.text.square")
        }
        .onChange(of: store.meta.scanProjectSkills, initial: true) { _, enabled in
            scanProjects = enabled
        }
    }

    private func dedupe() {
        store.activeSheet = .dedupe
    }
}
