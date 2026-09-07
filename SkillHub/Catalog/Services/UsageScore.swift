import Foundation

/// Ranks items by how often agents actually invoke them, then stars, installs, and recency.
nonisolated enum UsageScore {
    static func score(
        invocationCount: Int,
        lastInvokedAt: Date?,
        starred: Bool,
        installs: Int,
        modifiedAt: Date,
        now: Date = .now
    ) -> Double {
        let calls = Double(invocationCount) * 10
        let star: Double = starred ? 16 : 0
        let places = Double(max(installs, 1)) * 3
        let last = lastInvokedAt ?? modifiedAt
        let daysSinceCall = now.timeIntervalSince(last) / 86_400
        let recency = max(0, 18 - daysSinceCall * 0.45)
        let freshness = max(0, 6 - now.timeIntervalSince(modifiedAt) / 86_400 / 10)
        return max(1, 2 + calls + star + places + recency + freshness)
    }

    static func score(skill: SkillItem, meta: ItemMeta, usage: UsageStat, now: Date = .now) -> Double {
        score(
            invocationCount: usage.count,
            lastInvokedAt: usage.lastInvokedAt,
            starred: meta.starred,
            installs: skill.liveInstallCount,
            modifiedAt: skill.modifiedAt,
            now: now
        )
    }

    static func score(prompt: PromptItem, meta: ItemMeta, usage: UsageStat, now: Date = .now) -> Double {
        score(
            invocationCount: usage.count,
            lastInvokedAt: usage.lastInvokedAt,
            starred: meta.starred,
            installs: 1,
            modifiedAt: prompt.modifiedAt,
            now: now
        )
    }

    static func caption(
        invocationCount: Int,
        lastInvokedAt: Date? = nil,
        starred: Bool,
        installs: Int,
        now: Date = .now
    ) -> String {
        var parts: [String] = []
        if invocationCount > 0 {
            parts.append(String(localized: "调用 \(invocationCount) 次"))
            if let lastInvokedAt { parts.append(lastUsedText(lastInvokedAt, now: now)) }
        }
        if starred { parts.append(String(localized: "已收藏")) }
        if installs > 1 { parts.append(String(localized: "装在 \(installs) 处")) }
        return parts.isEmpty ? String(localized: "还没被调用过") : parts.joined(separator: " · ")
    }

    // MARK: Last used

    /// Days since the item was last invoked; nil when it never was.
    static func daysSinceUse(_ lastInvokedAt: Date?, now: Date = .now) -> Int? {
        guard let lastInvokedAt else { return nil }
        return max(0, Int(now.timeIntervalSince(lastInvokedAt) / 86_400))
    }

    static func lastUsedText(_ lastInvokedAt: Date?, now: Date = .now) -> String {
        guard let days = daysSinceUse(lastInvokedAt, now: now) else { return String(localized: "从未调用") }
        switch days {
        case 0: return String(localized: "今天用过")
        case 1: return String(localized: "昨天用过")
        case 2..<14: return String(localized: "\(days) 天前")
        case 14..<60: return String(localized: "\(days / 7) 周前")
        case 60..<365: return String(localized: "\(days / 30) 个月前")
        default: return String(localized: "一年多前")
        }
    }

    /// Anything not touched for this long is a candidate for deletion.
    static let staleAfterDays = 90

    /// Never-invoked items count as stale only once the files themselves are old, so a freshly
    /// installed skill is not flagged the day it arrives.
    static func isStale(lastInvokedAt: Date?, modifiedAt: Date, now: Date = .now) -> Bool {
        let reference = lastInvokedAt ?? modifiedAt
        return now.timeIntervalSince(reference) / 86_400 >= Double(staleAfterDays)
    }

    /// 0 = fresh, 1 = fully stale; drives how much a bubble fades.
    static func staleness(lastInvokedAt: Date?, modifiedAt: Date, now: Date = .now) -> Double {
        let reference = lastInvokedAt ?? modifiedAt
        let days = now.timeIntervalSince(reference) / 86_400
        return min(1, max(0, (days - 14) / Double(staleAfterDays - 14)))
    }
}
