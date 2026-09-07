import Foundation

extension CatalogStore {
    func itemMeta(for document: DocumentRef) -> ItemMeta {
        switch document {
        case .skill(let skill): meta.item(skillID: skill.id)
        case .prompt(let prompt): meta.item(promptID: prompt.id)
        }
    }

    func isStarred(skillID: SkillItem.ID) -> Bool {
        meta.item(skillID: skillID).starred
    }

    func isStarred(promptID: PromptItem.ID) -> Bool {
        meta.item(promptID: promptID).starred
    }

    func toggleStar(for document: DocumentRef) {
        update(document) { $0.starred.toggle() }
    }

    func setTags(_ tags: [String], for document: DocumentRef) {
        let cleaned = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var unique: [String] = []
        for tag in cleaned where !unique.contains(tag) { unique.append(tag) }
        update(document) { $0.tags = unique }
    }

    func setNotes(_ notes: String, for document: DocumentRef) {
        guard itemMeta(for: document).notes != notes else { return }
        update(document) { $0.notes = notes }
    }

    func setScanProjectSkills(_ enabled: Bool) {
        guard meta.scanProjectSkills != enabled else { return }
        mutateMeta { $0.scanProjectSkills = enabled }
        refresh()
    }

    private func update(_ document: DocumentRef, _ change: (inout ItemMeta) -> Void) {
        mutateMeta { meta in
            switch document {
            case .skill(let skill):
                var item = meta.item(skillID: skill.id)
                change(&item)
                meta.skills[skill.id] = item
            case .prompt(let prompt):
                var item = meta.item(promptID: prompt.id)
                change(&item)
                meta.prompts[prompt.id] = item
            }
        }
    }
}
