import Foundation

nonisolated enum HubSheet: String, Identifiable, Sendable {
    case newSkill
    case newPrompt
    case install
    case dedupe

    var id: String { rawValue }
}
