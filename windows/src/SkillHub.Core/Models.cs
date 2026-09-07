namespace SkillHub.Core;

public enum PromptKind
{
    Standalone,
    Embedded
}

public static class PromptKindInfo
{
    public static string Title(this PromptKind kind) => kind switch
    {
        PromptKind.Standalone => "独立",
        PromptKind.Embedded => "内嵌",
        _ => kind.ToString()
    };
}

public enum HealthIssue
{
    MissingDescription,
    BrokenSymlink,
    MissingSkillFile
}

public static class HealthIssueInfo
{
    public static string Title(this HealthIssue issue) => issue switch
    {
        HealthIssue.MissingDescription => "缺少 description",
        HealthIssue.BrokenSymlink => "损坏的符号链接",
        HealthIssue.MissingSkillFile => "没有 SKILL.md",
        _ => issue.ToString()
    };
}

public enum DocumentMode
{
    Preview,
    Edit
}

public static class DocumentModeInfo
{
    public static string Title(this DocumentMode mode) => mode switch
    {
        DocumentMode.Preview => "预览",
        DocumentMode.Edit => "编辑",
        _ => mode.ToString()
    };
}

public enum HubSheet
{
    NewSkill,
    NewPrompt,
    Install,
    Dedupe
}

public sealed record Installation(ToolSource Source, string Path, bool IsSymlink, bool IsBroken);

public sealed record SkillItem(
    string CanonicalPath,
    string Name,
    string FolderName,
    string Description,
    string Version,
    string SkillFilePath,
    IReadOnlyList<Installation> Installations,
    int FileCount,
    DateTime ModifiedAt,
    IReadOnlyList<HealthIssue> Health,
    bool IsReadOnly)
{
    public string Id => CanonicalPath;

    public IReadOnlyList<ToolSource> ToolSources =>
        Installations.Select(i => i.Source).Distinct().OrderBy(s => s.Title(), StringComparer.CurrentCulture).ToArray();

    public bool IsDuplicateInstall => Installations.Count > 1;
    public int SymlinkCount => Installations.Count(i => i.IsSymlink);
    public int RealCount => Installations.Count(i => !i.IsSymlink && !i.IsBroken);
    public int LiveInstallCount => Installations.Count(i => !i.IsBroken);
}

public sealed record PromptItem(
    string CanonicalPath,
    string Title,
    PromptKind Kind,
    ToolSource Source,
    string? ParentSkillName,
    string? ParentSkillPath,
    DateTime ModifiedAt,
    bool IsReadOnly)
{
    public string Id => CanonicalPath;
}

public sealed class ItemMeta
{
    public bool Starred { get; set; }
    public List<string> Tags { get; set; } = [];
    public string Notes { get; set; } = "";
    public int OpenCount { get; set; }
    public DateTime? LastOpenedAt { get; set; }

    public static ItemMeta Empty() => new();

    public ItemMeta Clone() => new()
    {
        Starred = Starred,
        Tags = [..Tags],
        Notes = Notes,
        OpenCount = OpenCount,
        LastOpenedAt = LastOpenedAt
    };
}

public sealed class ArchiveRecord
{
    public string OriginalPath { get; set; } = "";
    public string ArchivePath { get; set; } = "";
    public string Name { get; set; } = "";
    public DateTime Date { get; set; }
}

public sealed class AppMeta
{
    public Dictionary<string, ItemMeta> Skills { get; set; } = [];
    public Dictionary<string, ItemMeta> Prompts { get; set; } = [];
    public List<string> CustomPromptRoots { get; set; } = [];
    public bool ScanProjectSkills { get; set; }
    public List<ArchiveRecord> ArchiveLog { get; set; } = [];

    public static AppMeta Empty() => new();

    public ItemMeta ItemForSkill(string id) => Skills.TryGetValue(id, out var item) ? item : ItemMeta.Empty();
    public ItemMeta ItemForPrompt(string id) => Prompts.TryGetValue(id, out var item) ? item : ItemMeta.Empty();
}

public sealed record ScanOptions(bool ScanProjectSkills = false, IReadOnlyList<string>? CustomPromptRoots = null)
{
    public IReadOnlyList<string> PromptRoots => CustomPromptRoots ?? [];

    public static ScanOptions From(AppMeta meta) => new(meta.ScanProjectSkills, meta.CustomPromptRoots);
}

public sealed record CatalogSnapshot(
    IReadOnlyList<SkillItem> Skills,
    IReadOnlyList<PromptItem> Prompts,
    IReadOnlyList<Installation> BrokenOrphans,
    UsageIndex? Usage = null)
{
    public UsageIndex UsageIndex => Usage ?? UsageIndex.Empty;
    public static CatalogSnapshot Empty { get; } = new([], [], []);
}

public sealed class OverviewStats
{
    public int UniqueSkills { get; init; }
    public int UniquePrompts { get; init; }
    public int StandalonePrompts { get; init; }
    public int EmbeddedPrompts { get; init; }
    public int SymlinkInstalls { get; init; }
    public int RealInstalls { get; init; }
    public int DuplicateSkills { get; init; }
    public Dictionary<ToolSource, int> ByTool { get; init; } = [];
    public int HealthCount { get; init; }
    public int MissingDescriptions { get; init; }
    public int BrokenLinks { get; init; }

    public static OverviewStats Empty { get; } = new();

    public static OverviewStats From(CatalogSnapshot snapshot)
    {
        var byTool = new Dictionary<ToolSource, int>();
        var symlink = 0;
        var real = 0;
        var health = 0;
        var missing = 0;
        var broken = snapshot.BrokenOrphans.Count;

        foreach (var skill in snapshot.Skills)
        {
            if (skill.Health.Count > 0)
            {
                health++;
            }

            if (skill.Health.Contains(HealthIssue.MissingDescription))
            {
                missing++;
            }

            if (skill.Health.Contains(HealthIssue.BrokenSymlink))
            {
                broken++;
            }

            foreach (var install in skill.Installations)
            {
                byTool[install.Source] = byTool.GetValueOrDefault(install.Source) + 1;
                if (install.IsSymlink)
                {
                    symlink++;
                }
                else
                {
                    real++;
                }
            }
        }

        return new OverviewStats
        {
            UniqueSkills = snapshot.Skills.Count,
            UniquePrompts = snapshot.Prompts.Count,
            StandalonePrompts = snapshot.Prompts.Count(p => p.Kind == PromptKind.Standalone),
            EmbeddedPrompts = snapshot.Prompts.Count(p => p.Kind == PromptKind.Embedded),
            DuplicateSkills = snapshot.Skills.Count(s => s.IsDuplicateInstall),
            BrokenLinks = broken,
            HealthCount = health,
            MissingDescriptions = missing,
            SymlinkInstalls = symlink,
            RealInstalls = real,
            ByTool = byTool
        };
    }
}

public sealed record FrontmatterDocument(string Name, string Description, string Version, string Body, string Raw);
