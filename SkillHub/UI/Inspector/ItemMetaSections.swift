import SwiftUI

/// Tags and notes, stored only inside Skill Hub, for whichever document is selected.
struct ItemMetaSections: View {
    @Environment(CatalogStore.self) private var store
    let document: DocumentRef

    @State private var notes = ""

    var body: some View {
        Section("标签") {
            TagEditorView(tags: store.itemMeta(for: document).tags, onChange: setTags)
        }

        Section {
            TextField("备注", text: $notes, prompt: Text("只保存在本机"), axis: .vertical)
                .lineLimit(2...6)
                .labelsHidden()
                .onChange(of: notes) { _, value in
                    store.setNotes(value, for: document)
                }
        } header: {
            Text("备注")
        }
        .onChange(of: document.id, initial: true) {
            notes = store.itemMeta(for: document).notes
        }
    }

    private func setTags(_ tags: [String]) {
        store.setTags(tags, for: document)
    }
}
