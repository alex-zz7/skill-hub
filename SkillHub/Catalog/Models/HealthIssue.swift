import Foundation

nonisolated enum HealthIssue: String, Codable, Sendable, Hashable, CaseIterable {
    case missingDescription
    case brokenSymlink
    case missingSkillFile
    /// Another skill with the same name exists as a different folder, so they may have drifted apart.
    case sameNameElsewhere

    var title: String {
        switch self {
        case .missingDescription: String(localized: "缺少 description")
        case .brokenSymlink: String(localized: "损坏的符号链接")
        case .missingSkillFile: String(localized: "没有 SKILL.md")
        case .sameNameElsewhere: String(localized: "同名但不是同一份")
        }
    }
}
