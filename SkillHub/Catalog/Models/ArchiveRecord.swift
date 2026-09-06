import Foundation

nonisolated struct ArchiveRecord: Codable, Hashable, Sendable {
    var originalPath: String
    var archivePath: String
    var name: String
    var date: Date
}
