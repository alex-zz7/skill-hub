import Foundation

nonisolated enum PromptKind: String, Codable, Sendable, Hashable {
    /// A markdown file that lives on its own in a prompt library.
    case standalone
    /// A prompt file found inside a skill folder.
    case embedded

    var title: String {
        switch self {
        case .standalone: "独立"
        case .embedded: "内嵌"
        }
    }
}
