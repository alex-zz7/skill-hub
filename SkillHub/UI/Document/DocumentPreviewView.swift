import SwiftUI

struct DocumentPreviewView: View {
    let document: DocumentRef
    let text: String

    var body: some View {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView(
                "这个文件是空的",
                systemImage: "doc",
                description: Text("切换到「编辑」开始写。")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DocumentHeaderView(document: document)
                    Divider()
                    MarkdownDocumentView(raw: text, title: document.title)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: Theme.readingWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .scrollContentBackground(.visible)
        }
    }
}
