import Foundation

nonisolated struct FrontmatterDocument: Sendable, Equatable {
    var name: String
    var description: String
    var version: String
    var body: String
    var raw: String
}
