namespace SkillHub.Core;

public sealed class HubPaths : IEquatable<HubPaths>
{
    public static readonly HashSet<string> IgnoreNames =
    [
        "node_modules", ".git", ".raw", "vendor_imports", ".tmp",
        "plugins.bak", "dist", ".DS_Store", "DerivedData", "build",
        "test-results", "comparison-results"
    ];

    public string Home { get; }

    public HubPaths(string home)
    {
        Home = PathUtil.Standardize(home);
    }

    public string ContentRoot => Path.Combine(Home, ".skill-hub");
    public string ArchiveRoot => Path.Combine(ContentRoot, "archive");
    public string PromptLibrary => Path.Combine(ContentRoot, "library", "prompts");
    public string LegacyMetaFile => Path.Combine(ContentRoot, "meta.json");

    public string? SkillRoot(ToolSource source)
    {
        var relative = source switch
        {
            ToolSource.CursorUser => Path.Combine(".cursor", "skills"),
            ToolSource.CursorBuiltin => Path.Combine(".cursor", "skills-cursor"),
            ToolSource.Claude => Path.Combine(".claude", "skills"),
            ToolSource.Codex => Path.Combine(".codex", "skills"),
            ToolSource.Agents => Path.Combine(".agents", "skills"),
            ToolSource.Proma => Path.Combine(".proma", "default-skills"),
            _ => null
        };
        return relative == null ? null : Path.Combine(Home, relative);
    }

    public string? PromptRoot(ToolSource source) => source switch
    {
        ToolSource.PromptLibrary => PromptLibrary,
        ToolSource.CodexPrompts => Path.Combine(Home, ".codex", "prompts"),
        _ => null
    };

    public bool IsBuiltinPath(string path)
    {
        var builtin = SkillRoot(ToolSource.CursorBuiltin);
        if (builtin == null)
        {
            return false;
        }

        return PathUtil.IsUnder(builtin, path);
    }

    public void EnsureContentDirectories()
    {
        Directory.CreateDirectory(PromptLibrary);
        Directory.CreateDirectory(ArchiveRoot);
    }

    public IReadOnlyList<string> ProjectSkillRoots()
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var seenProjectFolders = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var roots = new List<string>();
        foreach (var folderName in new[] { "Projects", "projects" })
        {
            var projects = Path.Combine(Home, folderName);
            if (!Directory.Exists(projects))
            {
                continue;
            }

            if (!seenProjectFolders.Add(RealOrStandard(projects)))
            {
                continue;
            }

            foreach (var child in PathUtil.ImmediateChildren(projects))
            {
                if (!Directory.Exists(child))
                {
                    continue;
                }

                foreach (var relative in new[] { Path.Combine(".cursor", "skills"), Path.Combine(".claude", "skills") })
                {
                    var candidate = Path.Combine(child, relative);
                    if (!Directory.Exists(candidate))
                    {
                        continue;
                    }

                    var real = PathUtil.RealPath(candidate);
                    if (seen.Add(real))
                    {
                        roots.Add(candidate);
                    }
                }
            }
        }

        return roots;
    }

    public IReadOnlyList<string> WritableRoots(ScanOptions options)
    {
        var roots = ToolSourceInfo.SkillRoots
            .Select(SkillRoot)
            .Where(p => p != null)
            .Select(p => PathUtil.Standardize(p!))
            .ToList();
        roots.Add(PathUtil.Standardize(ContentRoot));
        roots.AddRange(options.PromptRoots.Select(PathUtil.Standardize));
        var codex = PromptRoot(ToolSource.CodexPrompts);
        if (codex != null)
        {
            roots.Add(PathUtil.Standardize(codex));
        }

        if (options.ScanProjectSkills)
        {
            roots.AddRange(ProjectSkillRoots().Select(PathUtil.Standardize));
        }

        return roots;
    }

    static string RealOrStandard(string path)
    {
        try
        {
            return PathUtil.RealPath(path);
        }
        catch (IOException)
        {
            return PathUtil.Standardize(path);
        }
    }

    public bool Equals(HubPaths? other) => other != null && Home == other.Home;
    public override bool Equals(object? obj) => obj is HubPaths other && Equals(other);
    public override int GetHashCode() => Home.GetHashCode();
}
