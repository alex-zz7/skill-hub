namespace SkillHub.Core.Tests;

public class ClusterTests
{
    [Fact]
    public void TokensSplitOnDashUnderscoreAndSpace() =>
        Assert.Equal(["blog", "write", "seo", "audit"], ClusterGrouping.Tokens("Blog_Write seo-Audit"));

    [Fact]
    public void NextPrefixDescendsOneLevel()
    {
        Assert.Equal("blog", ClusterGrouping.NextPrefix("blog-seo-audit", null));
        Assert.Equal("blog-seo", ClusterGrouping.NextPrefix("blog-seo-audit", "blog"));
        Assert.Null(ClusterGrouping.NextPrefix("blog-seo-audit", "blog-seo"));
        Assert.Null(ClusterGrouping.NextPrefix("single", null));
    }

    [Fact]
    public void BelongsMatchesWholeTokensOnly()
    {
        Assert.True(ClusterGrouping.Belongs("blog-write", "blog"));
        Assert.True(ClusterGrouping.Belongs("blog", "blog"));
        Assert.False(ClusterGrouping.Belongs("blogger-tool", "blog"));
    }

    [Fact]
    public void BuilderGroupsSiblingsAndLeavesSingletonsLoose()
    {
        var items = new ClusterBuilder.Item[]
        {
            new("1", "blog-write", 10, 3, true),
            new("2", "blog-audit", 5, 1, true),
            new("3", "blog", 2, 0, true),
            new("4", "seo-plan", 7, 2, true),
            new("5", "lonely", 1, 0, false)
        };
        var nodes = ClusterBuilder.Nodes(items, null, null);
        var blog = nodes.First(n => n.Title == "blog");
        Assert.True(blog.IsGroup);
        Assert.Equal(3, blog.Count);
        Assert.Equal(4, blog.OpenCount);
        Assert.Equal(["1", "2", "3"], blog.MemberIds.OrderBy(id => id).ToArray());
        Assert.False(nodes.First(n => n.Title == "seo-plan").IsGroup);
        Assert.Equal(new ClusterKind.Prompt("5"), nodes.First(n => n.Title == "lonely").Kind);
        Assert.Equal(3, nodes.Count);
    }

    [Fact]
    public void LooseCapLimitsSingletons()
    {
        var items = Enumerable.Range(0, 10)
            .Select(i => new ClusterBuilder.Item($"{i}", $"item{i}", i, 0, true))
            .ToArray();
        var nodes = ClusterBuilder.Nodes(items, null, 3);
        Assert.Equal(3, nodes.Count);
        Assert.Equal("item9", nodes[0].Title);
    }

    [Fact]
    public void NarrowCanvasKeepsHeaviestNodesAndSizesThemLargest()
    {
        var nodes = Enumerable.Range(0, 30)
            .Select(i => new ClusterNode($"n{i}", $"node {i}", new ClusterKind.Skill($"n{i}"), 1 + i * 4, 1, 0))
            .ToArray();
        var placements = ClusterLayout.Plan(nodes, new MapSize(320, 360));
        Assert.True(placements.ContainsKey("n29"));
        if (placements.TryGetValue("n0", out var lightest))
        {
            Assert.True(placements["n29"].Diameter >= lightest.Diameter);
        }
    }

    [Fact]
    public void LayoutPlacesEveryNodeWithoutOverlap()
    {
        var nodes = Enumerable.Range(0, 12)
            .Select(i => new ClusterNode($"n{i}", $"node {i}", new ClusterKind.Skill($"n{i}"), 1 + i * 3, 1, 0))
            .ToArray();
        var placements = ClusterLayout.Plan(nodes, new MapSize(900, 700));
        Assert.Equal(nodes.Length, placements.Count);
        var values = placements.Values.ToArray();
        for (var i = 0; i < values.Length; i++)
        {
            for (var j = i + 1; j < values.Length; j++)
            {
                var a = values[i];
                var b = values[j];
                var distance = Math.Sqrt(
                    Math.Pow(a.Center.X - b.Center.X, 2) + Math.Pow(a.Center.Y - b.Center.Y, 2));
                Assert.True(distance + 0.5 >= (a.Diameter + b.Diameter) / 2);
            }
        }
    }
}
