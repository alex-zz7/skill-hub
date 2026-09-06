import Foundation

/// One bubble on the map or one row in the ranked list: either a single item or a prefix group.
nonisolated struct ClusterNode: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case skill(SkillItem.ID)
        case prompt(PromptItem.ID)
        case group(prefix: String, memberIDs: [String])
    }

    let id: String
    let title: String
    let kind: Kind
    let weight: Double
    let count: Int
    let openCount: Int

    var isGroup: Bool {
        if case .group = kind { return true }
        return false
    }

    var memberIDs: [String] {
        switch kind {
        case .skill(let id), .prompt(let id): [id]
        case .group(_, let members): members
        }
    }
}
