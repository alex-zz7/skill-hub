import Foundation

extension CatalogStore {
    var currentFilter: BrowseFilter {
        sidebarSelection?.filter ?? .all
    }

    var visibleSkills: [SkillItem] {
        skills.filter { skill in
            matches(currentFilter, skill: skill)
                && matchesSearch(skill.name, skill.description, skill.canonicalPath)
                && matchesCluster(skill.name)
        }
    }

    var visiblePrompts: [PromptItem] {
        prompts.filter { prompt in
            matches(currentFilter, prompt: prompt)
                && matchesSearch(prompt.title, prompt.parentSkillName ?? "", prompt.canonicalPath)
                && matchesCluster(prompt.title)
        }
    }

    var duplicateSkills: [SkillItem] {
        skills.filter(\.isDuplicateInstall)
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func count(for item: SidebarItem) -> Int {
        if let cached = countCache[item] { return cached }
        let count: Int = switch item {
        case .overview: skills.count
        case .skills(let filter): skills.count { matches(filter, skill: $0) }
        case .prompts(let filter): prompts.count { matches(filter, prompt: $0) }
        }
        countCache[item] = count
        return count
    }

    /// Bubbles or ranked rows for the current filter, one level below the current drill-down.
    func clusterNodes(looseCap: Int?) -> [ClusterNode] {
        let items: [ClusterBuilder.Item] = if sidebarSelection?.isPrompts == true {
            visiblePrompts.map { prompt in
                let item = meta.item(promptID: prompt.id)
                return ClusterBuilder.Item(
                    id: prompt.id,
                    title: prompt.title,
                    weight: UsageScore.score(prompt: prompt, meta: item),
                    openCount: item.openCount,
                    isSkill: false
                )
            }
        } else {
            visibleSkills.map { skill in
                let item = meta.item(skillID: skill.id)
                return ClusterBuilder.Item(
                    id: skill.id,
                    title: skill.name,
                    weight: UsageScore.score(skill: skill, meta: item),
                    openCount: item.openCount,
                    isSkill: true
                )
            }
        }
        return ClusterBuilder.nodes(from: items, parent: clusterPrefix, looseCap: looseCap)
    }

    var clusterTitle: String {
        clusterPrefix ?? sidebarSelection?.title ?? "Skills"
    }

    var clusterItemCount: Int {
        sidebarSelection?.isPrompts == true ? visiblePrompts.count : visibleSkills.count
    }

    func open(_ node: ClusterNode) {
        switch node.kind {
        case .group(let prefix, _):
            openCluster(prefix: prefix)
        case .skill(let id):
            if let skill = skills.first(where: { $0.id == id }) { select(.skill(skill)) }
        case .prompt(let id):
            if let prompt = prompts.first(where: { $0.id == id }) { select(.prompt(prompt)) }
        }
    }

    func caption(for node: ClusterNode) -> String {
        switch node.kind {
        case .group:
            return "\(node.count) 个 · 点开这一类"
        case .skill(let id):
            guard let skill = skills.first(where: { $0.id == id }) else { return "" }
            let item = meta.item(skillID: id)
            return UsageScore.caption(openCount: item.openCount, starred: item.starred, installs: skill.liveInstallCount)
        case .prompt(let id):
            let item = meta.item(promptID: id)
            return UsageScore.caption(openCount: item.openCount, starred: item.starred, installs: 1)
        }
    }

    // MARK: Related items

    func relatedSkills(for skill: SkillItem) -> [SkillItem] {
        let tags = Set(meta.item(skillID: skill.id).tags)
        let related = skills.filter { other in
            other.id != skill.id && (
                (!tags.isEmpty && !Set(meta.item(skillID: other.id).tags).isDisjoint(with: tags))
                    || other.name == skill.name
            )
        }
        if !related.isEmpty { return Array(related.prefix(6)) }
        return Array(skills.filter { $0.id != skill.id }.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(5))
    }

    func relatedPrompts(for prompt: PromptItem) -> [PromptItem] {
        Array(prompts.filter { other in
            other.id != prompt.id && (
                (other.parentSkillPath == prompt.parentSkillPath && prompt.parentSkillPath != nil)
                    || other.title == prompt.title
            )
        }.prefix(6))
    }

    func prompts(inSkill path: String) -> [PromptItem] {
        prompts.filter { $0.parentSkillPath == path }
    }

    // MARK: Matching

    private func matches(_ filter: BrowseFilter, skill: SkillItem) -> Bool {
        switch filter {
        case .all, .standalone, .embedded: true
        case .tool(let source): skill.installations.contains { $0.source == source }
        case .duplicates: skill.isDuplicateInstall
        case .starred: meta.item(skillID: skill.id).starred
        case .health: !skill.health.isEmpty
        }
    }

    private func matches(_ filter: BrowseFilter, prompt: PromptItem) -> Bool {
        switch filter {
        case .all: true
        case .tool(let source): prompt.source == source
        case .duplicates, .health: false
        case .starred: meta.item(promptID: prompt.id).starred
        case .standalone: prompt.kind == .standalone
        case .embedded: prompt.kind == .embedded
        }
    }

    private func matchesSearch(_ fields: String...) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func matchesCluster(_ name: String) -> Bool {
        guard let prefix = clusterPrefix else { return true }
        return ClusterGrouping.belongs(name: name, prefix: prefix)
    }
}
