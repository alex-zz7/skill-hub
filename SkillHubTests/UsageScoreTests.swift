import Foundation
import Testing
@testable import SkillHub

struct UsageScoreTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func opensOutrankEverythingElse() {
        let opened = UsageScore.score(openCount: 5, lastOpenedAt: now, starred: false, installs: 1, modifiedAt: now, now: now)
        let starred = UsageScore.score(openCount: 0, lastOpenedAt: nil, starred: true, installs: 3, modifiedAt: now, now: now)
        #expect(opened > starred)
    }

    @Test func recencyDecaysOverTime() {
        let fresh = UsageScore.score(openCount: 1, lastOpenedAt: now, starred: false, installs: 1, modifiedAt: now, now: now)
        let stale = UsageScore.score(openCount: 1, lastOpenedAt: now.addingTimeInterval(-60 * 86_400), starred: false, installs: 1, modifiedAt: now.addingTimeInterval(-60 * 86_400), now: now)
        #expect(fresh > stale)
        #expect(stale >= 1)
    }

    @Test func captionSummarisesUsage() {
        #expect(UsageScore.caption(openCount: 0, starred: false, installs: 1) == "还没打开过")
        #expect(UsageScore.caption(openCount: 2, starred: true, installs: 3) == "打开 2 次 · 已收藏 · 装在 3 处")
    }
}
