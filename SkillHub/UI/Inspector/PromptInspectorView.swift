import SwiftUI

struct PromptInspectorView: View {
    @Environment(CatalogStore.self) private var store
    let prompt: PromptItem

    private var document: DocumentRef { .prompt(prompt) }

    var body: some View {
        Form {
            InspectorHeader(
                title: prompt.title,
                subtitle: prompt.kind == .embedded ? "来自 skill「\(prompt.parentSkillName ?? "")」" : prompt.source.title,
                sources: [prompt.source],
                starred: store.isStarred(promptID: prompt.id),
                onToggleStar: toggleStar
            )

            Section("位置") {
                PathRow(label: "文件", path: prompt.canonicalPath)
                LabeledContent("类型", value: prompt.kind.title)
                LabeledContent("修改时间") {
                    Text(prompt.modifiedAt, format: .dateTime.year().month().day().hour().minute())
                }
            }

            ItemMetaSections(document: document)

            Section("操作") {
                if prompt.kind == .embedded {
                    Button("另存到独立库", systemImage: "square.and.arrow.down.on.square", action: saveStandalone)
                }
                Button("在 Finder 中显示", systemImage: "folder", action: reveal)
                Button("归档…", systemImage: "archivebox", action: archive)
                    .disabled(prompt.isReadOnly)
                Button("删除…", systemImage: "trash", role: .destructive, action: delete)
                    .disabled(prompt.isReadOnly)
            }

            RelatedPromptsSection(prompt: prompt)
        }
        .formStyle(.grouped)
    }

    private func toggleStar() {
        store.toggleStar(for: document)
    }

    private func saveStandalone() {
        store.savePromptAsStandalone(prompt)
    }

    private func reveal() {
        store.reveal(document)
    }

    private func archive() {
        store.requestArchive(document)
    }

    private func delete() {
        store.requestDelete(document)
    }
}
