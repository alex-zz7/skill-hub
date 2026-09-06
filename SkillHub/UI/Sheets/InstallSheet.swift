import SwiftUI

struct InstallSheet: View {
    @Environment(CatalogStore.self) private var store
    @State private var source: ToolSource?
    @State private var asCopy = false

    private var skill: SkillItem? { store.selectedSkill }

    private var targets: [ToolSource] {
        skill.map(store.availableInstallTargets) ?? []
    }

    var body: some View {
        SheetFrame(
            title: "安装到其他工具",
            primaryTitle: asCopy ? "复制" : "链接",
            primaryEnabled: source != nil && skill != nil,
            primaryAction: install
        ) {
            if let skill {
                Section {
                    LabeledContent("Skill", value: skill.name)
                    if targets.isEmpty {
                        Text("已经装到所有可写的工具里了。")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("目标", selection: $source) {
                            ForEach(targets, id: \.self) { target in
                                Label(target.title, systemImage: target.symbolName).tag(Optional(target))
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                }

                Section {
                    Toggle("复制成独立实体，而不是符号链接", isOn: $asCopy)
                } footer: {
                    Text(asCopy
                         ? "复制后两边各自独立，修改不会同步。"
                         : "符号链接指回同一个目录，在任何工具里修改都是同一份文件。推荐。")
                }
            }
        }
        .onAppear {
            source = targets.first
        }
    }

    private func install() {
        guard let skill, let source else { return }
        store.install(skill, to: source, asCopy: asCopy)
    }
}
