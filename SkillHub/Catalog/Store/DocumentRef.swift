import Foundation

/// The file currently shown in the detail column, whichever list it came from.
nonisolated enum DocumentRef: Hashable, Sendable {
    case skill(SkillItem)
    case prompt(PromptItem)

    var id: String {
        switch self {
        case .skill(let skill): skill.id
        case .prompt(let prompt): prompt.id
        }
    }

    var title: String {
        switch self {
        case .skill(let skill): skill.name
        case .prompt(let prompt): prompt.title
        }
    }

    var subtitle: String {
        switch self {
        case .skill(let skill): skill.description
        case .prompt(let prompt): prompt.parentSkillName ?? prompt.source.title
        }
    }

    /// The markdown file to read and write.
    var filePath: String {
        switch self {
        case .skill(let skill): skill.skillFilePath
        case .prompt(let prompt): prompt.canonicalPath
        }
    }

    /// The folder (skill) or file (prompt) to reveal in Finder.
    var revealPath: String {
        switch self {
        case .skill(let skill): skill.canonicalPath
        case .prompt(let prompt): prompt.canonicalPath
        }
    }

    var isReadOnly: Bool {
        switch self {
        case .skill(let skill): skill.isReadOnly
        case .prompt(let prompt): prompt.isReadOnly
        }
    }

    var primarySource: ToolSource {
        switch self {
        case .skill(let skill): skill.toolSources.first ?? .custom
        case .prompt(let prompt): prompt.source
        }
    }
}
