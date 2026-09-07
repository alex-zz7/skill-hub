import Foundation

nonisolated struct OverviewStats: Sendable, Equatable {
    var uniqueSkills = 0
    var uniquePrompts = 0
    var standalonePrompts = 0
    var embeddedPrompts = 0
    var symlinkInstalls = 0
    var realInstalls = 0
    var duplicateSkills = 0
    var byTool: [ToolSource: Int] = [:]
    var healthCount = 0
    var missingDescriptions = 0
    var brokenLinks = 0
    var sameNameSkills = 0

    static let empty = OverviewStats()

    init() {}

    init(snapshot: CatalogSnapshot) {
        uniqueSkills = snapshot.skills.count
        uniquePrompts = snapshot.prompts.count
        standalonePrompts = snapshot.prompts.count { $0.kind == .standalone }
        embeddedPrompts = snapshot.prompts.count { $0.kind == .embedded }
        duplicateSkills = snapshot.skills.count(where: \.isDuplicateInstall)
        brokenLinks = snapshot.brokenOrphans.count

        for skill in snapshot.skills {
            if !skill.health.isEmpty { healthCount += 1 }
            if skill.health.contains(.missingDescription) { missingDescriptions += 1 }
            if skill.health.contains(.brokenSymlink) { brokenLinks += 1 }
            if skill.health.contains(.sameNameElsewhere) { sameNameSkills += 1 }
            for install in skill.installations {
                byTool[install.source, default: 0] += 1
                if install.isSymlink { symlinkInstalls += 1 } else { realInstalls += 1 }
            }
        }
    }
}
