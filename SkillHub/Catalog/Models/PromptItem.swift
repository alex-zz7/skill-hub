import Foundation

nonisolated struct PromptItem: Identifiable, Hashable, Sendable {
    var id: String { canonicalPath }
    var canonicalPath: String
    var title: String
    var kind: PromptKind
    var source: ToolSource
    var parentSkillName: String?
    var parentSkillPath: String?
    var modifiedAt: Date
    var isReadOnly: Bool
}
