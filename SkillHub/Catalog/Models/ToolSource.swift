import Foundation

/// Where a skill or prompt lives on disk, expressed as the tool that owns that folder.
nonisolated enum ToolSource: String, Codable, CaseIterable, Sendable, Hashable {
    case cursorUser
    case cursorBuiltin
    case claude
    case codex
    case agents
    case proma
    case promptLibrary
    case codexPrompts
    case custom

    var title: String {
        switch self {
        case .cursorUser: "Cursor"
        case .cursorBuiltin: "Cursor 内置"
        case .claude: "Claude"
        case .codex: "Codex"
        case .agents: "Agents"
        case .proma: "Proma"
        case .promptLibrary: "Skill Hub 库"
        case .codexPrompts: "Codex Prompts"
        case .custom: "自定义"
        }
    }

    var symbolName: String {
        switch self {
        case .cursorUser: "cursorarrow.rays"
        case .cursorBuiltin: "cursorarrow.square"
        case .claude: "sparkles"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .agents: "person.2"
        case .proma: "wand.and.stars"
        case .promptLibrary: "books.vertical"
        case .codexPrompts: "text.quote"
        case .custom: "folder"
        }
    }

    /// Cursor's bundled skills are managed by Cursor itself and must never be edited or deleted.
    var isWritable: Bool { self != .cursorBuiltin }

    var isSkillRoot: Bool {
        switch self {
        case .cursorUser, .cursorBuiltin, .claude, .codex, .agents, .proma: true
        case .promptLibrary, .codexPrompts, .custom: false
        }
    }

    static let skillRoots: [ToolSource] = [.cursorUser, .cursorBuiltin, .claude, .codex, .agents, .proma]
}
