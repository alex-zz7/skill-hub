import Foundation

/// How often agents actually invoked a skill or prompt, mined from tool transcripts.
nonisolated struct UsageStat: Codable, Sendable, Equatable, Hashable {
    var count = 0
    var lastInvokedAt: Date?

    static let empty = UsageStat()

    mutating func add(at date: Date?) {
        count += 1
        if let date, lastInvokedAt.map({ date > $0 }) ?? true {
            lastInvokedAt = date
        }
    }
}

nonisolated struct UsageIndex: Sendable, Equatable {
    var skills: [String: UsageStat] = [:]
    var prompts: [String: UsageStat] = [:]

    static let empty = UsageIndex()

    func skill(_ item: SkillItem) -> UsageStat {
        lookup(skills, item.folderName) ?? lookup(skills, item.name) ?? .empty
    }

    func prompt(_ item: PromptItem) -> UsageStat {
        let stem = URL(fileURLWithPath: item.canonicalPath).deletingPathExtension().lastPathComponent
        return lookup(prompts, stem) ?? lookup(prompts, item.title) ?? .empty
    }

    mutating func addSkill(_ raw: String, at date: Date?) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Self.add(&skills, name, at: date)
        if let tail = name.split(separator: ":").last, tail.count != name.count {
            Self.add(&skills, String(tail), at: date)
        }
    }

    mutating func addPrompt(_ raw: String, at date: Date?) {
        Self.add(&prompts, raw, at: date)
    }

    mutating func merge(_ other: UsageIndex) {
        Self.merge(&skills, other.skills)
        Self.merge(&prompts, other.prompts)
    }

    private func lookup(_ map: [String: UsageStat], _ raw: String) -> UsageStat? {
        map[Self.key(raw)]
    }

    private static func merge(_ dest: inout [String: UsageStat], _ src: [String: UsageStat]) {
        for (key, stat) in src {
            var current = dest[key] ?? UsageStat()
            current.count += stat.count
            if let at = stat.lastInvokedAt, current.lastInvokedAt.map({ at > $0 }) ?? true {
                current.lastInvokedAt = at
            }
            dest[key] = current
        }
    }

    private static func add(_ map: inout [String: UsageStat], _ raw: String, at date: Date?) {
        let key = key(raw)
        guard !key.isEmpty else { return }
        var stat = map[key] ?? UsageStat()
        stat.add(at: date)
        map[key] = stat
    }

    static func key(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
