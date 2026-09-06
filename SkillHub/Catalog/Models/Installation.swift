import Foundation

/// One place on disk where a skill appears. The same skill can be installed in several tools,
/// either as a real folder or as a symlink back to a single canonical folder.
nonisolated struct Installation: Codable, Hashable, Sendable {
    var source: ToolSource
    var path: String
    var isSymlink: Bool
    var isBroken: Bool
}
