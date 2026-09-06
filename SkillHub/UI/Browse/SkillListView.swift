import SwiftUI

struct SkillListView: View {
    @Environment(CatalogStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let skills = store.visibleSkills
        List(skills, selection: $store.selectedSkillID) { skill in
            SkillRowView(skill: skill, starred: store.isStarred(skillID: skill.id))
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ClusterBreadcrumbBar()
        }
        .overlay {
            BrowseEmptyState(isEmpty: skills.isEmpty, noun: "skill")
        }
    }
}
