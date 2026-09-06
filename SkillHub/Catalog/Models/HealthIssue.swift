import Foundation

nonisolated enum HealthIssue: String, Codable, Sendable, Hashable, CaseIterable {
    case missingDescription
    case brokenSymlink
    case missingSkillFile

    var title: String {
        switch self {
        case .missingDescription: "缺少 description"
        case .brokenSymlink: "损坏的符号链接"
        case .missingSkillFile: "没有 SKILL.md"
        }
    }
}
