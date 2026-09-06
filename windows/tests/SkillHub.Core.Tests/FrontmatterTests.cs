namespace SkillHub.Core.Tests;

public class FrontmatterTests
{
    [Fact]
    public void ParsesFlatFields()
    {
        var doc = Frontmatter.Parse("""
            ---
            name: blog-write
            description: "Write a blog post"
            version: '1.2'
            ---

            # Blog Write

            Body here.
            """);
        Assert.Equal("blog-write", doc.Name);
        Assert.Equal("Write a blog post", doc.Description);
        Assert.Equal("1.2", doc.Version);
        Assert.StartsWith("# Blog Write", doc.Body);
        Assert.EndsWith("Body here.", doc.Body);
    }

    [Fact]
    public void ParsesFoldedAndLiteralBlocks()
    {
        var doc = Frontmatter.Parse("""
            ---
            name: x
            description: >
              First line
              second line
            notes: |
              keep
              lines
            ---
            body
            """);
        Assert.Equal("First line second line", doc.Description);
        Assert.Equal("body", doc.Body);
    }

    [Fact]
    public void MissingFrontmatterKeepsWholeBody()
    {
        var doc = Frontmatter.Parse("# Just markdown\n\ntext");
        Assert.Equal("", doc.Name);
        Assert.Equal("# Just markdown\n\ntext", doc.Body);
    }

    [Theory]
    [InlineData("Blog Write!", "blog-write")]
    [InlineData("  --hello--world-- ", "hello-world")]
    [InlineData("中文 名字", "中文-名字")]
    [InlineData("UPPER_case", "upper-case")]
    public void Slugifies(string input, string expected) =>
        Assert.Equal(expected, Frontmatter.Slug(input));

    [Theory]
    [InlineData("blog-write")]
    [InlineData("a1")]
    [InlineData("x")]
    public void AcceptsValidNames(string name) =>
        Assert.True(Frontmatter.IsValidSkillName(name));

    [Theory]
    [InlineData("")]
    [InlineData("-lead")]
    [InlineData("trail-")]
    [InlineData("Has Space")]
    [InlineData("UPPER")]
    public void RejectsInvalidNames(string name) =>
        Assert.False(Frontmatter.IsValidSkillName(name));

    [Fact]
    public void RejectsTooLongName() =>
        Assert.False(Frontmatter.IsValidSkillName(new string('a', 65)));

    [Fact]
    public void RenderRoundTrips()
    {
        var text = Frontmatter.Render("demo-skill", "Does demo things", "");
        var parsed = Frontmatter.Parse(text);
        Assert.Equal("demo-skill", parsed.Name);
        Assert.Equal("Does demo things", parsed.Description);
        Assert.Contains("# Demo Skill", parsed.Body);
    }
}
