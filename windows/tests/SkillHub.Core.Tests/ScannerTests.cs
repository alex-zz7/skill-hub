namespace SkillHub.Core.Tests;

sealed class TemporaryHome : IDisposable
{
    public string Url { get; }
    public HubPaths Paths { get; }

    public TemporaryHome()
    {
        Url = Path.Combine(Path.GetTempPath(), $"skillhub-tests-{Guid.NewGuid():N}");
        Directory.CreateDirectory(Url);
        Paths = new HubPaths(Url);
    }

    public string MakeSkill(ToolSource source, string folder, string? name = null, string description = "desc")
    {
        var root = Paths.SkillRoot(source) ?? throw new InvalidOperationException();
        var dir = Path.Combine(root, folder);
        Directory.CreateDirectory(dir);
        PathUtil.WriteAtomic(Path.Combine(dir, "SKILL.md"), Frontmatter.Render(name ?? folder, description, $"# {folder}\n"));
        return dir;
    }

    public void Link(ToolSource source, string folder, string target)
    {
        var root = Paths.SkillRoot(source) ?? throw new InvalidOperationException();
        Directory.CreateDirectory(root);
        Directory.CreateSymbolicLink(Path.Combine(root, folder), target);
    }

    public void Dispose()
    {
        try
        {
            Directory.Delete(Url, true);
        }
        catch (IOException)
        {
        }
    }
}

public class ScannerTests
{
    [Fact]
    public void DedupesSymlinkedInstallsIntoOneSkill()
    {
        using var home = new TemporaryHome();
        var real = home.MakeSkill(ToolSource.Agents, "blog-write");
        home.Link(ToolSource.CursorUser, "blog-write", real);
        home.Link(ToolSource.Claude, "blog-write", real);

        var snapshot = Scanner.Scan(home.Paths, new ScanOptions());
        Assert.Single(snapshot.Skills);
        var skill = snapshot.Skills[0];
        Assert.Equal(3, skill.Installations.Count);
        Assert.Equal(2, skill.SymlinkCount);
        Assert.Equal(1, skill.RealCount);
        Assert.True(skill.IsDuplicateInstall);
        Assert.Empty(skill.Health);
        Assert.Equal(
            new HashSet<ToolSource> { ToolSource.Agents, ToolSource.CursorUser, ToolSource.Claude },
            skill.ToolSources.ToHashSet());
    }

    [Fact]
    public void ReportsBrokenLinksAndMissingDescriptions()
    {
        using var home = new TemporaryHome();
        home.MakeSkill(ToolSource.Claude, "quiet", description: "");
        home.Link(ToolSource.Codex, "gone", Path.Combine(home.Url, "nowhere"));

        var snapshot = Scanner.Scan(home.Paths, new ScanOptions());
        Assert.Single(snapshot.Skills);
        Assert.Equal([HealthIssue.MissingDescription], snapshot.Skills[0].Health);
        Assert.Single(snapshot.BrokenOrphans);
        Assert.Equal(ToolSource.Codex, snapshot.BrokenOrphans[0].Source);

        var stats = OverviewStats.From(snapshot);
        Assert.Equal(1, stats.MissingDescriptions);
        Assert.Equal(1, stats.BrokenLinks);
    }

    [Fact]
    public void BuiltinSkillsAreReadOnly()
    {
        using var home = new TemporaryHome();
        home.MakeSkill(ToolSource.CursorBuiltin, "builtin");
        home.MakeSkill(ToolSource.CursorUser, "mine");

        var snapshot = Scanner.Scan(home.Paths, new ScanOptions());
        Assert.True(snapshot.Skills.First(s => s.Name == "builtin").IsReadOnly);
        Assert.False(snapshot.Skills.First(s => s.Name == "mine").IsReadOnly);
    }

    [Fact]
    public void FindsEmbeddedAndStandalonePrompts()
    {
        using var home = new TemporaryHome();
        var skill = home.MakeSkill(ToolSource.Claude, "writer");
        var promptsDir = Path.Combine(skill, "prompts");
        Directory.CreateDirectory(promptsDir);
        PathUtil.WriteAtomic(Path.Combine(promptsDir, "outline.md"), "# Outline");
        PathUtil.WriteAtomic(Path.Combine(skill, "README.md"), "ignored");
        home.Paths.EnsureContentDirectories();
        PathUtil.WriteAtomic(Path.Combine(home.Paths.PromptLibrary, "weekly-report.md"), "# Standalone");

        var snapshot = Scanner.Scan(home.Paths, new ScanOptions());
        Assert.Equal(2, snapshot.Prompts.Count);
        var embedded = snapshot.Prompts.First(p => p.Kind == PromptKind.Embedded);
        Assert.Equal("outline", embedded.Title);
        Assert.Equal("writer", embedded.ParentSkillName);
        var standalone = snapshot.Prompts.First(p => p.Kind == PromptKind.Standalone);
        Assert.Equal("weekly report", standalone.Title);
        Assert.Equal(ToolSource.PromptLibrary, standalone.Source);
    }

    [Fact]
    public void ProjectSkillsOnlyWhenEnabled()
    {
        using var home = new TemporaryHome();
        var project = Path.Combine(home.Url, "Projects", "demo", ".cursor", "skills", "local-skill");
        Directory.CreateDirectory(project);
        PathUtil.WriteAtomic(Path.Combine(project, "SKILL.md"), Frontmatter.Render("local-skill", "d", ""));

        Assert.Empty(Scanner.Scan(home.Paths, new ScanOptions()).Skills);
        var enabled = Scanner.Scan(home.Paths, new ScanOptions(ScanProjectSkills: true));
        Assert.Single(enabled.Skills);
        Assert.Equal(ToolSource.Custom, enabled.Skills[0].Installations[0].Source);
    }

    [Fact]
    public void WritableRootsExcludeUnrelatedPaths()
    {
        using var home = new TemporaryHome();
        var roots = home.Paths.WritableRoots(new ScanOptions());
        Assert.Contains(PathUtil.Standardize(home.Paths.ContentRoot), roots);
        Assert.Contains(PathUtil.Standardize(home.Paths.SkillRoot(ToolSource.Claude)!), roots);
        Assert.DoesNotContain(PathUtil.Standardize(home.Url), roots);
    }
}
