import SwiftUI

struct InspectorView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        switch store.currentDocument {
        case .skill(let skill):
            SkillInspectorView(skill: skill)
        case .prompt(let prompt):
            PromptInspectorView(prompt: prompt)
        case .none:
            ClusterInspectorView()
        }
    }
}
