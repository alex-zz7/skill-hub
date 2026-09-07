import SwiftUI

/// Inspector content when nothing is selected: describes the current filter and offers bulk actions.
struct ClusterInspectorView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        Form {
            Section {
                LabeledContent("当前范围", value: store.sidebarSelection?.title ?? "Skills")
                if let prefix = store.clusterPrefix {
                    LabeledContent("聚类前缀", value: prefix)
                }
                LabeledContent("条目") {
                    Text(store.clusterItemCount, format: .number)
                }
            } header: {
                Text("浏览")
            } footer: {
                Text("气泡大小按使用频率：agent 调用次数、收藏、装到几个工具。同名前缀会合并成一类，点开可以继续往下。")
            }

            if !store.duplicateSkills.isEmpty {
                Section("整理") {
                    Button("一键去重 \(store.duplicateSkills.count) 个…", action: dedupe)
                }
            }

            if store.clusterPrefix != nil {
                Section {
                    Button("返回上一层", systemImage: "chevron.left", action: store.popCluster)
                    Button("回到顶层", systemImage: "arrow.up.to.line", action: store.resetClusters)
                }
            }
        }
        .formStyle(.grouped)
        .font(Theme.body)
    }

    private func dedupe() {
        store.activeSheet = .dedupe
    }
}
