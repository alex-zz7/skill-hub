import Foundation

nonisolated struct FrontmatterDocument: Sendable, Equatable {
    var name: String
    var description: String
    var version: String
    var body: String
    var raw: String
    /// Optional provenance fields some skill authors include (`author`, `source` / `origin` / `repository` / `homepage`).
    var author: String = ""
    var origin: String = ""
}
