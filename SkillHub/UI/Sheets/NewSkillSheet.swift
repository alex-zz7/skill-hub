import SwiftUI

struct NewSkillSheet: View {
    @Environment(CatalogStore.self) private var store
    @State private var name = ""
    @State private var description = ""
    @State private var source: ToolSource = .cursorUser

    private var slug: String { Frontmatter.slug(name) }
    private var isValid: Bool { Frontmatter.isValidSkillName(slug) }

    var body: some View {
        SheetFrame(title: "新建 Skill", primaryTitle: "创建", primaryEnabled: isValid, primaryAction: create) {
            Section {
                TextField("名字", text: $name, prompt: Text("例如 blog-outline"))
                if !name.isEmpty {
                    LabeledContent("将创建为", value: slug.isEmpty ? "—" : slug)
                        .foregroundStyle(isValid ? Color.secondary : Color.red)
                }
                TextField("description", text: $description, prompt: Text("一句话说明什么时候用它"), axis: .vertical)
                    .lineLimit(2...5)
            } footer: {
                Text("名字只能包含小写字母、数字和连字符。description 会写进 SKILL.md 的 frontmatter，Agent 靠它决定何时加载。")
            }

            Section("安装到") {
                Picker("工具", selection: $source) {
                    ForEach(ToolSource.skillRoots.filter(\.isWritable), id: \.self) { root in
                        Label(root.title, systemImage: root.symbolName).tag(root)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
    }

    private func create() {
        store.createSkill(name: name, description: description, source: source)
    }
}
