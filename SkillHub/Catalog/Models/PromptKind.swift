import Foundation

nonisolated enum PromptKind: String, Codable, Sendable, Hashable {
    /// A markdown file that lives on its own in a prompt library.
    case standalone
    /// A prompt file found inside a skill folder.
    case embedded

    var title: String {
        switch self {
        case .standalone: String(localized: "独立")
        case .embedded: String(localized: "内嵌")
        }
    }
}
