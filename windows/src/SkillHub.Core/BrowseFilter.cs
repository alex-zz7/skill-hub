namespace SkillHub.Core;

public abstract record BrowseFilter
{
    public sealed record All : BrowseFilter;
    public sealed record Tool(ToolSource Source) : BrowseFilter;
    public sealed record Duplicates : BrowseFilter;
    public sealed record Starred : BrowseFilter;
    public sealed record Health : BrowseFilter;
    public sealed record Standalone : BrowseFilter;
    public sealed record Embedded : BrowseFilter;

    public static readonly BrowseFilter AllFilter = new All();
    public static readonly BrowseFilter DuplicatesFilter = new Duplicates();
    public static readonly BrowseFilter StarredFilter = new Starred();
    public static readonly BrowseFilter HealthFilter = new Health();
    public static readonly BrowseFilter StandaloneFilter = new Standalone();
    public static readonly BrowseFilter EmbeddedFilter = new Embedded();

    public static readonly BrowseFilter[] SkillFilters = [AllFilter, StarredFilter, DuplicatesFilter, HealthFilter];
    public static readonly BrowseFilter[] PromptFilters = [AllFilter, StarredFilter, StandaloneFilter, EmbeddedFilter];
    public static readonly BrowseFilter[] PromptSources = [new Tool(ToolSource.PromptLibrary), new Tool(ToolSource.CodexPrompts)];

    public string Id => this switch
    {
        All => "all",
        Tool t => $"tool.{t.Source}",
        Duplicates => "duplicates",
        Starred => "starred",
        Health => "health",
        Standalone => "standalone",
        Embedded => "embedded",
        _ => ToString()
    };

    public string Title => this switch
    {
        All => "全部",
        Tool t => t.Source.Title(),
        Duplicates => "重复安装",
        Starred => "收藏",
        Health => "健康问题",
        Standalone => "独立文件",
        Embedded => "Skill 内嵌",
        _ => ToString()
    };
}

public abstract record SidebarItem
{
    public sealed record Overview : SidebarItem;
    public sealed record Skills(BrowseFilter Browse) : SidebarItem;
    public sealed record Prompts(BrowseFilter Browse) : SidebarItem;

    public static readonly SidebarItem OverviewItem = new Overview();
    public static readonly SidebarItem AllSkills = new Skills(BrowseFilter.AllFilter);
    public static readonly SidebarItem AllPrompts = new Prompts(BrowseFilter.AllFilter);

    public bool IsPrompts => this is Prompts;
    public bool IsOverview => this is Overview;

    public BrowseFilter? Filter => this switch
    {
        Skills s => s.Browse,
        Prompts p => p.Browse,
        _ => null
    };

    public string Title => this switch
    {
        Overview => "总览",
        Skills s => s.Browse is BrowseFilter.All ? "Skills" : s.Browse.Title,
        Prompts p => p.Browse is BrowseFilter.All ? "Prompts" : p.Browse.Title,
        _ => ToString()
    };

    public string Id => this switch
    {
        Overview => "overview",
        Skills s => $"skills.{s.Browse.Id}",
        Prompts p => $"prompts.{p.Browse.Id}",
        _ => ToString()
    };
}

public abstract record DocumentRef
{
    public sealed record Skill(SkillItem Item) : DocumentRef;
    public sealed record Prompt(PromptItem Item) : DocumentRef;

    public string Id => this switch
    {
        Skill s => s.Item.Id,
        Prompt p => p.Item.Id,
        _ => ""
    };

    public string Title => this switch
    {
        Skill s => s.Item.Name,
        Prompt p => p.Item.Title,
        _ => ""
    };

    public string Subtitle => this switch
    {
        Skill s => s.Item.Description,
        Prompt p => p.Item.ParentSkillName ?? p.Item.Source.Title(),
        _ => ""
    };

    public string FilePath => this switch
    {
        Skill s => s.Item.SkillFilePath,
        Prompt p => p.Item.CanonicalPath,
        _ => ""
    };

    public string RevealPath => this switch
    {
        Skill s => s.Item.CanonicalPath,
        Prompt p => p.Item.CanonicalPath,
        _ => ""
    };

    public bool IsReadOnly => this switch
    {
        Skill s => s.Item.IsReadOnly,
        Prompt p => p.Item.IsReadOnly,
        _ => true
    };

    public ToolSource PrimarySource => this switch
    {
        Skill s => s.Item.ToolSources.FirstOrDefault(),
        Prompt p => p.Item.Source,
        _ => ToolSource.Custom
    };
}

public abstract record DedupePolicy
{
    public sealed record KeepEntity : DedupePolicy;
    public sealed record Prefer(ToolSource Source) : DedupePolicy;

    public static readonly DedupePolicy KeepEntityPolicy = new KeepEntity();

    public static IReadOnlyList<DedupePolicy> All { get; } =
        new DedupePolicy[] { KeepEntityPolicy }
            .Concat(ToolSourceInfo.SkillRoots.Where(s => s.IsWritable()).Select(s => (DedupePolicy)new Prefer(s)))
            .ToArray();

    public string Id => this switch
    {
        KeepEntity => "entity",
        Prefer p => $"prefer.{p.Source}",
        _ => ToString()
    };

    public string Title => this switch
    {
        KeepEntity => "只留实体目录，删掉其余符号链接",
        Prefer p => $"优先保留 {p.Source.Title()} 里的那一份",
        _ => ToString()
    };
}

public abstract record ConfirmAction
{
    public sealed record RemoveInstall(string SkillId, string Path, bool IsSymlink) : ConfirmAction;
    public sealed record DeleteSkill(string SkillId, bool IsLastEntity) : ConfirmAction;
    public sealed record DeletePrompt(string PromptId, bool IsLastEntity) : ConfirmAction;
    public sealed record ArchiveSkill(string SkillId) : ConfirmAction;
    public sealed record ArchivePrompt(string PromptId) : ConfirmAction;

    public string Id => this switch
    {
        RemoveInstall r => $"remove:{r.Path}",
        DeleteSkill d => $"delete-skill:{d.SkillId}",
        DeletePrompt d => $"delete-prompt:{d.PromptId}",
        ArchiveSkill a => $"archive-skill:{a.SkillId}",
        ArchivePrompt a => $"archive-prompt:{a.PromptId}",
        _ => ToString()
    };

    public string Title => this switch
    {
        RemoveInstall { IsSymlink: true } => "移除这个符号链接？",
        RemoveInstall => "移除这份安装？",
        DeleteSkill { IsLastEntity: true } => "删除最后一份实体？",
        DeleteSkill => "删除这个 skill？",
        DeletePrompt => "删除这个 prompt？",
        ArchiveSkill => "归档这个 skill？",
        ArchivePrompt => "归档这个 prompt？",
        _ => ""
    };

    public string Message => this switch
    {
        RemoveInstall { IsSymlink: true, Path: var path } => $"只会删掉链接 {path}，真实目录保留。",
        RemoveInstall { Path: var path } => $"将删除 {path}。如果这是最后一份实体，其他工具里的链接也会失效。",
        DeleteSkill { IsLastEntity: true } => "这是最后一份实体文件，删除后无法从工具目录恢复。指向它的符号链接会一并清掉。",
        DeleteSkill => "会删掉实体目录，并清掉指向它的符号链接。",
        DeletePrompt => "这个文件会从磁盘上删除。",
        ArchiveSkill => "实体会移到 ~/.skill-hub/archive，各工具里的符号链接会被移除。",
        ArchivePrompt => "文件会移到 ~/.skill-hub/archive。",
        _ => ""
    };

    public string ConfirmTitle => this switch
    {
        RemoveInstall => "移除",
        DeleteSkill or DeletePrompt => "删除",
        ArchiveSkill or ArchivePrompt => "归档",
        _ => "确定"
    };

    public bool IsDestructive => this is RemoveInstall or DeleteSkill or DeletePrompt;
}
