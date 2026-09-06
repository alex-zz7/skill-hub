import SwiftUI

struct DocumentEditorView: View {
    @Binding var text: String
    let isDirty: Bool
    let onDiscard: () -> Void

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .lineSpacing(3)
            .padding(12)
            .scrollContentBackground(.hidden)
            .background(.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                DocumentEditorStatusBar(isDirty: isDirty, onDiscard: onDiscard)
            }
    }
}
