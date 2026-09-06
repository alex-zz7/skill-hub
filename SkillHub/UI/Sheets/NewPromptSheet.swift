import SwiftUI

struct NewPromptSheet: View {
    @Environment(CatalogStore.self) private var store
    @State private var title = ""
    @State private var bodyText = ""

    private var isValid: Bool {
        !Frontmatter.slug(title).isEmpty
    }

    var body: some View {
        SheetFrame(title: "新建 Prompt", primaryTitle: "创建", primaryEnabled: isValid, primaryAction: create) {
            Section {
                TextField("标题", text: $title, prompt: Text("例如 周报总结"))
                TextField("内容", text: $bodyText, prompt: Text("可以留空，稍后再编辑"), axis: .vertical)
                    .lineLimit(6...14)
                    .font(.system(.body, design: .monospaced))
            } footer: {
                Text("会保存为 ~/.skill-hub/library/prompts/\(Frontmatter.slug(title).isEmpty ? "…" : Frontmatter.slug(title)).md")
            }
        }
    }

    private func create() {
        store.createPrompt(title: title, body: bodyText)
    }
}
