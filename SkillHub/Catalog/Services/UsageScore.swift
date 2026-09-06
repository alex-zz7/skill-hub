import Foundation

/// A single number that ranks items by how much the user actually reaches for them:
/// opens dominate, then stars, then how many tools it is installed in, then recency.
nonisolated enum UsageScore {
    static func score(
        openCount: Int,
        lastOpenedAt: Date?,
        starred: Bool,
        installs: Int,
        modifiedAt: Date,
        now: Date = .now
    ) -> Double {
        let opens = Double(openCount) * 10
        let star: Double = starred ? 16 : 0
        let places = Double(max(installs, 1)) * 3
        let last = lastOpenedAt ?? modifiedAt
        let daysSinceOpen = now.timeIntervalSince(last) / 86_400
        let recency = max(0, 18 - daysSinceOpen * 0.45)
        let freshness = max(0, 6 - now.timeIntervalSince(modifiedAt) / 86_400 / 10)
        return max(1, 2 + opens + star + places + recency + freshness)
    }

    static func score(skill: SkillItem, meta: ItemMeta, now: Date = .now) -> Double {
        score(
            openCount: meta.openCount,
            lastOpenedAt: meta.lastOpenedAt,
            starred: meta.starred,
            installs: skill.liveInstallCount,
            modifiedAt: skill.modifiedAt,
            now: now
        )
    }

    static func score(prompt: PromptItem, meta: ItemMeta, now: Date = .now) -> Double {
        score(
            openCount: meta.openCount,
            lastOpenedAt: meta.lastOpenedAt,
            starred: meta.starred,
            installs: 1,
            modifiedAt: prompt.modifiedAt,
            now: now
        )
    }

    static func caption(openCount: Int, starred: Bool, installs: Int) -> String {
        var parts: [String] = []
        if openCount > 0 { parts.append("打开 \(openCount) 次") }
        if starred { parts.append("已收藏") }
        if installs > 1 { parts.append("装在 \(installs) 处") }
        return parts.isEmpty ? "还没打开过" : parts.joined(separator: " · ")
    }
}
