import SwiftUI

struct SkillHubCommands: Commands {
    let store: CatalogStore
    let access: HomeAccess

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建 Skill…", action: newSkill)
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!access.isGranted)
            Button("新建 Prompt…", action: newPrompt)
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!access.isGranted)
        }

        CommandGroup(after: .saveItem) {
            Button("保存", action: store.saveDraft)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!store.isDirty)
            Button("刷新", action: store.refresh)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!access.isGranted)
            Divider()
            Button("归档…", action: archive)
                .disabled(store.currentDocument == nil)
            Divider()
            Button("重新授权主目录…", action: reauthorize)
        }

        CommandMenu("浏览") {
            Button("总览", action: { show(.overview) })
                .keyboardShortcut("1", modifiers: .command)
            Button("Skills", action: { show(.skills(.all)) })
                .keyboardShortcut("2", modifiers: .command)
            Button("Prompts", action: { show(.prompts(.all)) })
                .keyboardShortcut("3", modifiers: .command)
            Divider()
            Button("返回上一层", action: store.popCluster)
                .keyboardShortcut("[", modifiers: .command)
                .disabled(store.clusterPrefix == nil)
            Button("重新排列气泡", action: store.replayMap)
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button("气泡图", action: store.showClusterMap)
                .keyboardShortcut("m", modifiers: .command)
                .disabled(store.currentDocument == nil)
        }

        CommandMenu("语言") {
            Picker("语言", selection: Binding(get: { AppLanguage.current }, set: { AppLanguage.apply($0) })) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Text("切换后会重新打开 Skill Hub")
        }
    }

    private func newSkill() {
        store.activeSheet = .newSkill
    }

    private func newPrompt() {
        store.activeSheet = .newPrompt
    }

    private func archive() {
        guard let document = store.currentDocument else { return }
        store.requestArchive(document)
    }

    private func reauthorize() {
        access.revoke()
        access.requestGrant()
    }

    private func show(_ item: SidebarItem) {
        store.chooseSidebar(item)
    }
}
