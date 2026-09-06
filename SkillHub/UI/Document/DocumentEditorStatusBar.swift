import SwiftUI

struct DocumentEditorStatusBar: View {
    let isDirty: Bool
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(isDirty ? "有未保存的修改" : "已保存", systemImage: isDirty ? "circle.fill" : "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(isDirty ? .orange : .secondary)
                .symbolRenderingMode(.hierarchical)
            Spacer()
            if isDirty {
                Button("放弃修改", action: onDiscard)
                    .buttonStyle(.borderless)
                    .font(.footnote)
            }
            Text("⌘S 保存")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
