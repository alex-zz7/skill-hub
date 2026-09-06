import Foundation

nonisolated struct AppMeta: Codable, Sendable, Equatable {
    var skills: [String: ItemMeta] = [:]
    var prompts: [String: ItemMeta] = [:]
    var customPromptRoots: [String] = []
    var scanProjectSkills = false
    var archiveLog: [ArchiveRecord] = []

    static let empty = AppMeta()

    func item(skillID: String) -> ItemMeta { skills[skillID] ?? .empty }
    func item(promptID: String) -> ItemMeta { prompts[promptID] ?? .empty }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skills = try container.decodeIfPresent([String: ItemMeta].self, forKey: .skills) ?? [:]
        prompts = try container.decodeIfPresent([String: ItemMeta].self, forKey: .prompts) ?? [:]
        customPromptRoots = try container.decodeIfPresent([String].self, forKey: .customPromptRoots) ?? []
        scanProjectSkills = try container.decodeIfPresent(Bool.self, forKey: .scanProjectSkills) ?? false
        archiveLog = try container.decodeIfPresent([ArchiveRecord].self, forKey: .archiveLog) ?? []
    }
}
