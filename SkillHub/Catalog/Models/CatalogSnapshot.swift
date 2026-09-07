import Foundation

/// The result of one full scan of the filesystem.
nonisolated struct CatalogSnapshot: Sendable {
    var skills: [SkillItem]
    var prompts: [PromptItem]
    var brokenOrphans: [Installation]
    var usage: UsageIndex = .empty

    static let empty = CatalogSnapshot(skills: [], prompts: [], brokenOrphans: [])
}
