import SwiftUI

struct DocumentView: View {
    @Environment(CatalogStore.self) private var store
    let document: DocumentRef

    var body: some View {
        @Bindable var store = store
        switch store.documentMode {
        case .preview:
            DocumentPreviewView(document: document, text: store.draftText)
        case .edit:
            DocumentEditorView(text: $store.draftText, isDirty: store.isDirty, onDiscard: store.discardDraft)
        }
    }
}
