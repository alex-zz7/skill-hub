import Foundation

nonisolated enum MarkdownBlock: Hashable, Sendable {
    case heading(Int, String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case code(String)
    case quote(String)
    case rule
    case table([String], [[String]])
}
