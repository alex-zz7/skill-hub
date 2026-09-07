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
        case .removeInstall(_, _, true): String(localized: "移除这个符号链接？")
        case .removeInstall: String(localized: "移除这份安装？")
        case .deleteSkill(_, true): String(localized: "删除最后一份实体？")
        case .deleteSkill: String(localized: "删除这个 skill？")
        case .deletePrompt: String(localized: "删除这个 prompt？")
        case .archiveSkill: String(localized: "归档这个 skill？")
        case .archivePrompt: String(localized: "归档这个 prompt？")
        }
    }

    var message: String {
        switch self {
        case .removeInstall(_, let path, true):
            String(localized: "只会删掉链接 \(path)，真实目录保留。")
        case .removeInstall(_, let path, false):
            String(localized: "将删除 \(path)。如果这是最后一份实体，其他工具里的链接也会失效。")
        case .deleteSkill(_, true):
            String(localized: "这是最后一份实体文件，删除后无法从工具目录恢复。指向它的符号链接会一并清掉。")
        case .deleteSkill:
            String(localized: "会删掉实体目录，并清掉指向它的符号链接。")
        case .deletePrompt:
            String(localized: "这个文件会从磁盘上删除。")
        case .archiveSkill:
            String(localized: "实体会移到 ~/.skill-hub/archive，各工具里的符号链接会被移除。")
        case .archivePrompt:
            String(localized: "文件会移到 ~/.skill-hub/archive。")
        }
    }

    var confirmTitle: String {
        switch self {
        case .removeInstall: String(localized: "移除")
        case .deleteSkill, .deletePrompt: String(localized: "删除")
        case .archiveSkill, .archivePrompt: String(localized: "归档")
        }
    }

    var isDestructive: Bool {
        switch self {
        case .removeInstall, .deleteSkill, .deletePrompt: true
        case .archiveSkill, .archivePrompt: false
        }
    }
}
