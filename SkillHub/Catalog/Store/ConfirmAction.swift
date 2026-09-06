import Foundation

/// A destructive or hard-to-undo change that waits for the user to confirm.
nonisolated enum ConfirmAction: Identifiable, Hashable, Sendable {
    case removeInstall(skillID: String, path: String, isSymlink: Bool)
    case deleteSkill(skillID: String, isLastEntity: Bool)
    case deletePrompt(promptID: String, isLastEntity: Bool)
    case archiveSkill(skillID: String)
    case archivePrompt(promptID: String)

    var id: String {
        switch self {
        case .removeInstall(_, let path, _): "remove:\(path)"
        case .deleteSkill(let id, _): "delete-skill:\(id)"
        case .deletePrompt(let id, _): "delete-prompt:\(id)"
        case .archiveSkill(let id): "archive-skill:\(id)"
        case .archivePrompt(let id): "archive-prompt:\(id)"
        }
    }

    var title: String {
        switch self {
        case .removeInstall(_, _, true): "移除这个符号链接？"
        case .removeInstall: "移除这份安装？"
        case .deleteSkill(_, true): "删除最后一份实体？"
        case .deleteSkill: "删除这个 skill？"
        case .deletePrompt: "删除这个 prompt？"
        case .archiveSkill: "归档这个 skill？"
        case .archivePrompt: "归档这个 prompt？"
        }
    }

    var message: String {
        switch self {
        case .removeInstall(_, let path, true):
            "只会删掉链接 \(path)，真实目录保留。"
        case .removeInstall(_, let path, false):
            "将删除 \(path)。如果这是最后一份实体，其他工具里的链接也会失效。"
        case .deleteSkill(_, true):
            "这是最后一份实体文件，删除后无法从工具目录恢复。指向它的符号链接会一并清掉。"
        case .deleteSkill:
            "会删掉实体目录，并清掉指向它的符号链接。"
        case .deletePrompt:
            "这个文件会从磁盘上删除。"
        case .archiveSkill:
            "实体会移到 ~/.skill-hub/archive，各工具里的符号链接会被移除。"
        case .archivePrompt:
            "文件会移到 ~/.skill-hub/archive。"
        }
    }

    var confirmTitle: String {
        switch self {
        case .removeInstall: "移除"
        case .deleteSkill, .deletePrompt: "删除"
        case .archiveSkill, .archivePrompt: "归档"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .removeInstall, .deleteSkill, .deletePrompt: true
        case .archiveSkill, .archivePrompt: false
        }
    }
}
