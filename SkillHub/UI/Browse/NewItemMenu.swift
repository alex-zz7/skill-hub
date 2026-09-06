import SwiftUI

struct NewItemMenu: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        Menu("新建", systemImage: "plus") {
            Button("新建 Skill…", systemImage: "square.stack.3d.up", action: newSkill)
            Button("新建 Prompt…", systemImage: "text.quote", action: newPrompt)
        }
    }

    private func newSkill() {
        store.activeSheet = .newSkill
    }

    private func newPrompt() {
        store.activeSheet = .newPrompt
    }
}
