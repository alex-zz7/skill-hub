import SwiftUI

struct TagEditorView: View {
    let tags: [String]
    let onChange: ([String]) -> Void

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(tag: tag, onRemove: remove)
                    }
                }
            }
            TextField("添加标签", text: $draft, prompt: Text("输入标签，按回车添加"))
                .labelsHidden()
                .onSubmit(add)
        }
        .padding(.vertical, 2)
    }

    private func add() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.isEmpty else { return }
        if !tags.contains(next) {
            onChange(tags + [next])
        }
        draft = ""
    }

    private func remove(_ tag: String) {
        onChange(tags.filter { $0 != tag })
    }
}
