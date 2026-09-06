import Foundation

/// The result of one full scan of the filesystem.
nonisolated struct CatalogSnapshot: Sendable {
    var skills: [SkillItem]
    var prompts: [PromptItem]
    var brokenOrphans: [Installation]

    static let empty = CatalogSnapshot(skills: [], prompts: [], brokenOrphans: [])
}
