import Foundation

/// Per-item data that only exists inside Skill Hub: stars, tags, notes, and usage counters.
nonisolated struct ItemMeta: Codable, Hashable, Sendable {
    var starred = false
    var tags: [String] = []
    var notes = ""
    var openCount = 0
    var lastOpenedAt: Date?

    static let empty = ItemMeta()

    init(starred: Bool = false, tags: [String] = [], notes: String = "", openCount: Int = 0, lastOpenedAt: Date? = nil) {
        self.starred = starred
        self.tags = tags
        self.notes = notes
        self.openCount = openCount
        self.lastOpenedAt = lastOpenedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        starred = try container.decodeIfPresent(Bool.self, forKey: .starred) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        openCount = try container.decodeIfPresent(Int.self, forKey: .openCount) ?? 0
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
    }
}
