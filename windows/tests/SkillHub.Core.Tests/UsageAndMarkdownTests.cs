namespace SkillHub.Core.Tests;

public class UsageAndMarkdownTests
{
    readonly DateTime _now = DateTimeOffset.FromUnixTimeSeconds(1_800_000_000).LocalDateTime;

    [Fact]
    public void OpensOutrankEverythingElse()
    {
        var opened = UsageScore.Score(5, _now, false, 1, _now, _now);
        var starred = UsageScore.Score(0, null, true, 3, _now, _now);
        Assert.True(opened > starred);
    }

    [Fact]
    public void RecencyDecaysOverTime()
    {
        var fresh = UsageScore.Score(1, _now, false, 1, _now, _now);
        var stale = UsageScore.Score(1, _now.AddDays(-60), false, 1, _now.AddDays(-60), _now);
        Assert.True(fresh > stale);
        Assert.True(stale >= 1);
    }

    [Fact]
    public void CaptionSummarisesUsage()
    {
        Assert.Equal("还没被调用过", UsageScore.Caption(0, false, 1));
        Assert.Equal("调用 2 次 · 已收藏 · 装在 3 处", UsageScore.Caption(2, true, 3));
    }

    [Fact]
    public void CountsClaudeSkillTool()
    {
        var index = new UsageIndex();
        UsageLog.IngestLine(
            """{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"gptimage2"}}]},"timestamp":"2026-09-01T12:00:00Z"}""",
            _now,
            index);
        Assert.Equal(1, index.Skills["gptimage2"].Count);
    }

    [Fact]
    public void CountsCursorReadOfSkillFile()
    {
        var index = new UsageIndex();
        UsageLog.IngestLine(
            """{"message":{"content":[{"type":"tool_use","name":"Read","input":{"path":"/Users/alex/.claude/skills/geo-content/SKILL.md"}}]}}""",
            _now,
            index);
        Assert.Equal(1, index.Skills["geo-content"].Count);
    }

    [Fact]
    public void IgnoresGrepMentionsOfSkillFiles()
    {
        var index = new UsageIndex();
        UsageLog.IngestLine(
            """{"message":{"content":[{"type":"tool_use","name":"Grep","input":{"pattern":"SKILL.md","path":"/Users/alex/.claude/skills/geo-content/SKILL.md"}}]}}""",
            _now,
            index);
        Assert.Empty(index.Skills);
    }

    [Fact]
    public void SplitsCommonBlocks()
    {
        var blocks = MarkdownParser.Blocks("""
            ---
            name: demo
            ---
            # Title

            A paragraph that
            wraps lines.

            - one
            - two

            1. first
            2. second

            ```swift
            let x = 1
            ```

            > quoted

            ---

            | a | b |
            |---|---|
            | 1 | 2 |
            """);

        Assert.Equal(8, blocks.Count);
        Assert.Equal(new MarkdownBlock.Heading(1, "Title"), blocks[0]);
        Assert.Equal(new MarkdownBlock.Paragraph("A paragraph that wraps lines."), blocks[1]);
        var bullets = Assert.IsType<MarkdownBlock.Bullets>(blocks[2]);
        Assert.Equal(new[] { "one", "two" }, bullets.Items);
        var numbered = Assert.IsType<MarkdownBlock.Numbered>(blocks[3]);
        Assert.Equal(new[] { "first", "second" }, numbered.Items);
        Assert.Equal(new MarkdownBlock.Code("let x = 1"), blocks[4]);
        Assert.Equal(new MarkdownBlock.Quote("quoted"), blocks[5]);
        Assert.Equal(new MarkdownBlock.Rule(), blocks[6]);
        var table = Assert.IsType<MarkdownBlock.Table>(blocks[7]);
        Assert.Equal(new[] { "a", "b" }, table.Header);
        Assert.Equal(new[] { "1", "2" }, table.Rows[0]);
    }

    [Fact]
    public void DropsHeadingThatRepeatsTitle()
    {
        IReadOnlyList<MarkdownBlock> blocks = [new MarkdownBlock.Heading(1, "Blog Write"), new MarkdownBlock.Paragraph("x")];
        Assert.Equal([new MarkdownBlock.Paragraph("x")], MarkdownParser.SkippingRedundantTitle(blocks, "blog-write"));
        Assert.Equal(blocks, MarkdownParser.SkippingRedundantTitle(blocks, "other"));
    }

    [Fact]
    public void HashWithoutSpaceIsNotHeading() =>
        Assert.Equal([new MarkdownBlock.Paragraph("#hashtag text")], MarkdownParser.Blocks("#hashtag text"));
}
