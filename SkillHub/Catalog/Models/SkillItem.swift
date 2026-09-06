import Foundation

nonisolated struct SkillItem: Identifiable, Hashable, Sendable {
    var id: String { canonicalPath }
    var canonicalPath: String
    var name: String
    var folderName: String
    var description: String
    var version: String
    var skillFilePath: String
    var installations: [Installation]
    var fileCount: Int
    var modifiedAt: Date
    var health: [HealthIssue]
    var isReadOnly: Bool

    var toolSources: [ToolSource] {
        Array(Set(installations.map(\.source))).sorted { $0.title < $1.title }
    }

    var isDuplicateInstall: Bool { installations.count > 1 }
    var symlinkCount: Int { installations.count(where: \.isSymlink) }
    var realCount: Int { installations.count { !$0.isSymlink && !$0.isBroken } }
    var liveInstallCount: Int { installations.count { !$0.isBroken } }
}
