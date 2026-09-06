import SwiftUI

struct PromptListView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let prompts = store.visiblePrompts
        List(prompts, selection: $store.selectedPromptID) { prompt in
            PromptRowView(prompt: prompt, starred: store.isStarred(promptID: prompt.id))
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ClusterBreadcrumbBar()
        }
        .overlay {
            BrowseEmptyState(isEmpty: prompts.isEmpty, noun: "prompt")
        }
    }
}
