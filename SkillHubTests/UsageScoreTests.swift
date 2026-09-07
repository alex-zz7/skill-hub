import Foundation
import Testing
@testable import SkillHub

struct UsageScoreTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func invocationsOutrankEverythingElse() {
        let called = UsageScore.score(invocationCount: 5, lastInvokedAt: now, starred: false, installs: 1, modifiedAt: now, now: now)
        let starred = UsageScore.score(invocationCount: 0, lastInvokedAt: nil, starred: true, installs: 3, modifiedAt: now, now: now)
        #expect(called > starred)
    }

    @Test func recencyDecaysOverTime() {
        let fresh = UsageScore.score(invocationCount: 1, lastInvokedAt: now, starred: false, installs: 1, modifiedAt: now, now: now)
        let stale = UsageScore.score(invocationCount: 1, lastInvokedAt: now.addingTimeInterval(-60 * 86_400), starred: false, installs: 1, modifiedAt: now.addingTimeInterval(-60 * 86_400), now: now)
        #expect(fresh > stale)
        #expect(stale >= 1)
    }

    @Test func captionSummarisesUsage() {
        #expect(UsageScore.caption(invocationCount: 0, starred: false, installs: 1) == "还没被调用过")
        #expect(UsageScore.caption(invocationCount: 2, starred: true, installs: 3) == "调用 2 次 · 已收藏 · 装在 3 处")
        let threeDaysAgo = now.addingTimeInterval(-3 * 86_400)
        #expect(UsageScore.caption(invocationCount: 2, lastInvokedAt: threeDaysAgo, starred: false, installs: 1, now: now) == "调用 2 次 · 3 天前")
    }

    @Test func lastUsedTextBuckets() {
        #expect(UsageScore.lastUsedText(nil, now: now) == "从未调用")
        #expect(UsageScore.lastUsedText(now, now: now) == "今天用过")
        #expect(UsageScore.lastUsedText(now.addingTimeInterval(-1 * 86_400), now: now) == "昨天用过")
        #expect(UsageScore.lastUsedText(now.addingTimeInterval(-5 * 86_400), now: now) == "5 天前")
        #expect(UsageScore.lastUsedText(now.addingTimeInterval(-21 * 86_400), now: now) == "3 周前")
        #expect(UsageScore.lastUsedText(now.addingTimeInterval(-100 * 86_400), now: now) == "3 个月前")
    }

    @Test func staleUsesLastCallThenFileDate() {
        let old = now.addingTimeInterval(-200 * 86_400)
        #expect(UsageScore.isStale(lastInvokedAt: nil, modifiedAt: old, now: now))
        #expect(!UsageScore.isStale(lastInvokedAt: nil, modifiedAt: now, now: now))
        #expect(!UsageScore.isStale(lastInvokedAt: now.addingTimeInterval(-10 * 86_400), modifiedAt: old, now: now))
        #expect(UsageScore.staleness(lastInvokedAt: now, modifiedAt: old, now: now) == 0)
        #expect(UsageScore.staleness(lastInvokedAt: old, modifiedAt: old, now: now) == 1)
    }
}

struct UsageLogTests {
    private let stamp = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func countsClaudeSkillTool() {
        var index = UsageIndex()
        UsageLog.ingest(
            line: #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"gptimage2"}}]},"timestamp":"2026-09-01T12:00:00Z"}"#,
            fileDate: stamp,
            into: &index
        )
        #expect(index.skills["gptimage2"]?.count == 1)
    }

    @Test func countsCursorReadOfSkillFile() {
        var index = UsageIndex()
        UsageLog.ingest(
            line: #"{"message":{"content":[{"type":"tool_use","name":"Read","input":{"path":"/Users/alex/.claude/skills/geo-content/SKILL.md"}}]}}"#,
            fileDate: stamp,
            into: &index
        )
        #expect(index.skills["geo-content"]?.count == 1)
    }

    @Test func ignoresGrepMentionsOfSkillFiles() {
        var index = UsageIndex()
        UsageLog.ingest(
            line: #"{"message":{"content":[{"type":"tool_use","name":"Grep","input":{"pattern":"SKILL.md","path":"/Users/alex/.claude/skills/geo-content/SKILL.md"}}]}}"#,
            fileDate: stamp,
            into: &index
        )
        #expect(index.skills.isEmpty)
    }

    @Test func countsPromptFileReads() {
        var index = UsageIndex()
        UsageLog.ingest(
            line: #"{"message":{"content":[{"type":"tool_use","name":"Read","input":{"path":"/Users/alex/.codex/prompts/standup.md"}}]}}"#,
            fileDate: stamp,
            into: &index
        )
        #expect(index.prompts["standup"]?.count == 1)
    }

    @Test func pluginSkillNameAlsoKeysTail() {
        var index = UsageIndex()
        UsageLog.ingest(
            line: #"{"message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"shopify-plugin:shopify-admin"}}]}}"#,
            fileDate: stamp,
            into: &index
        )
        #expect(index.skills["shopify-plugin:shopify-admin"]?.count == 1)
        #expect(index.skills["shopify-admin"]?.count == 1)
    }
}
