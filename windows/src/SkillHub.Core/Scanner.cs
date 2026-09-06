namespace SkillHub.Core;

public static class Scanner
{
    public static CatalogSnapshot Scan(HubPaths paths, ScanOptions options)
    {
        var buckets = new Dictionary<string, SkillDraft>(OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal);
        var orphans = new List<Installation>();

        foreach (var source in ToolSourceInfo.SkillRoots)
        {
            var root = paths.SkillRoot(source);
            if (root == null || !Directory.Exists(root))
            {
                continue;
            }

            CollectSkills(root, source, buckets, orphans);
        }

        if (options.ScanProjectSkills)
        {
            foreach (var root in paths.ProjectSkillRoots())
            {
                CollectSkills(root, ToolSource.Custom, buckets, orphans);
            }
        }

        var skills = buckets.Values
            .Select(draft => draft.Finish(paths))
            .OrderBy(s => s.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToList();

        var prompts = new List<PromptItem>();
        var seenPrompt = new HashSet<string>(OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal);

        foreach (var skill in skills)
        {
            foreach (var prompt in EmbeddedPrompts(skill))
            {
                if (seenPrompt.Add(prompt.CanonicalPath))
                {
                    prompts.Add(prompt);
                }
            }
        }

        var standaloneRoots = new List<(ToolSource Source, string Root)>
        {
            (ToolSource.PromptLibrary, paths.PromptLibrary)
        };
        var codex = paths.PromptRoot(ToolSource.CodexPrompts);
        if (codex != null)
        {
            standaloneRoots.Add((ToolSource.CodexPrompts, codex));
        }

        standaloneRoots.AddRange(options.PromptRoots.Select(root => (ToolSource.Custom, root)));

        foreach (var (source, root) in standaloneRoots)
        {
            foreach (var prompt in StandalonePrompts(root, source))
            {
                if (seenPrompt.Add(prompt.CanonicalPath))
                {
                    prompts.Add(prompt);
                }
            }
        }

        prompts.Sort((a, b) => string.Compare(a.Title, b.Title, StringComparison.CurrentCultureIgnoreCase));
        return new CatalogSnapshot(skills, prompts, orphans);
    }

    sealed class SkillDraft
    {
        public required string CanonicalPath { get; init; }
        public required string FolderName { get; init; }
        public required FrontmatterDocument Document { get; init; }
        public required string SkillFilePath { get; init; }
        public required List<Installation> Installations { get; init; }
        public required int FileCount { get; init; }
        public required DateTime ModifiedAt { get; init; }
        public HashSet<HealthIssue> Health { get; } = [];

        public SkillItem Finish(HubPaths paths)
        {
            var issues = new HashSet<HealthIssue>(Health);
            if (string.IsNullOrWhiteSpace(Document.Description))
            {
                issues.Add(HealthIssue.MissingDescription);
            }

            if (Installations.Any(i => i.IsBroken))
            {
                issues.Add(HealthIssue.BrokenSymlink);
            }

            var readOnly = Installations.All(i => !i.Source.IsWritable()) || paths.IsBuiltinPath(CanonicalPath);
            return new SkillItem(
                CanonicalPath,
                string.IsNullOrEmpty(Document.Name) ? FolderName : Document.Name,
                FolderName,
                Document.Description,
                Document.Version,
                SkillFilePath,
                Installations.OrderBy(i => i.Source.Title(), StringComparer.CurrentCulture).ToArray(),
                FileCount,
                ModifiedAt,
                issues.OrderBy(i => i).ToArray(),
                readOnly);
        }
    }

    static void CollectSkills(
        string root,
        ToolSource source,
        Dictionary<string, SkillDraft> buckets,
        List<Installation> orphans)
    {
        foreach (var child in PathUtil.ImmediateChildren(root))
        {
            var name = Path.GetFileName(child);
            if (HubPaths.IgnoreNames.Contains(name))
            {
                continue;
            }

            var isSymlink = PathUtil.IsSymbolicLink(child);
            // File.Exists is true for some dangling Unix symlinks; a skill listing must be a live directory.
            if (isSymlink && !Directory.Exists(child))
            {
                orphans.Add(new Installation(source, PathUtil.Standardize(child), true, true));
                continue;
            }

            if (!Directory.Exists(child))
            {
                continue;
            }

            var real = PathUtil.RealPath(child);
            var skillFile = Path.Combine(real, "SKILL.md");
            var listingPath = PathUtil.Standardize(child);
            var canonical = PathUtil.Standardize(real);
            var hasSkillFile = File.Exists(skillFile);
            var install = new Installation(source, listingPath, isSymlink, !hasSkillFile);

            if (!hasSkillFile)
            {
                if (isSymlink)
                {
                    orphans.Add(install);
                }

                continue;
            }

            if (buckets.TryGetValue(canonical, out var draft))
            {
                if (draft.Installations.All(i => i.Path != listingPath))
                {
                    draft.Installations.Add(install);
                }

                continue;
            }

            string raw;
            try
            {
                raw = File.ReadAllText(skillFile);
            }
            catch (IOException)
            {
                raw = "";
            }

            buckets[canonical] = new SkillDraft
            {
                CanonicalPath = canonical,
                FolderName = Path.GetFileName(real),
                Document = Frontmatter.Parse(raw),
                SkillFilePath = PathUtil.Standardize(skillFile),
                Installations = [install],
                FileCount = CountFiles(real),
                ModifiedAt = PathUtil.ModificationDate(skillFile)
            };
        }
    }

    static int CountFiles(string root)
    {
        var count = 0;
        Enumerate(root, (_, isDirectory) =>
        {
            if (!isDirectory)
            {
                count++;
            }
        });
        return count;
    }

    static IEnumerable<PromptItem> EmbeddedPrompts(SkillItem skill)
    {
        var items = new List<PromptItem>();
        Enumerate(skill.CanonicalPath, (path, isDirectory) =>
        {
            if (isDirectory)
            {
                return;
            }

            var filename = Path.GetFileName(path);
            if (filename == "SKILL.md" || filename.EndsWith(".stderr.txt", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            var ext = Path.GetExtension(path).TrimStart('.').ToLowerInvariant();
            if (ext is not ("md" or "txt"))
            {
                return;
            }

            var parentNames = DirectoryPathParts(path);
            var inPromptsDir = parentNames.Any(part => part.Equals("prompts", StringComparison.OrdinalIgnoreCase));
            var nameHit = filename.Contains("prompt", StringComparison.OrdinalIgnoreCase) && ext == "md";
            if (!inPromptsDir && !nameHit)
            {
                return;
            }

            items.Add(new PromptItem(
                PathUtil.RealPath(path),
                DisplayTitle(path),
                PromptKind.Embedded,
                skill.Installations.FirstOrDefault()?.Source ?? ToolSource.Custom,
                skill.Name,
                skill.CanonicalPath,
                PathUtil.ModificationDate(path) is var modified && modified != DateTime.MinValue ? modified : skill.ModifiedAt,
                skill.IsReadOnly));
        });
        return items;
    }

    static IEnumerable<PromptItem> StandalonePrompts(string root, ToolSource source)
    {
        if (!Directory.Exists(root))
        {
            return [];
        }

        var items = new List<PromptItem>();
        Enumerate(root, (path, isDirectory) =>
        {
            if (isDirectory || Path.GetFileName(path) == "SKILL.md")
            {
                return;
            }

            var ext = Path.GetExtension(path).TrimStart('.').ToLowerInvariant();
            if (ext is not ("md" or "txt"))
            {
                return;
            }

            items.Add(new PromptItem(
                PathUtil.RealPath(path),
                DisplayTitle(path),
                PromptKind.Standalone,
                source,
                null,
                null,
                PathUtil.ModificationDate(path),
                !source.IsWritable()));
        });
        return items;
    }

    static string DisplayTitle(string path) =>
        Path.GetFileNameWithoutExtension(path).Replace('-', ' ');

    static IReadOnlyList<string> DirectoryPathParts(string filePath)
    {
        var directory = Path.GetDirectoryName(filePath);
        if (string.IsNullOrEmpty(directory))
        {
            return [];
        }

        return directory.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    }

    static void Enumerate(string root, Action<string, bool> visit)
    {
        if (!Directory.Exists(root))
        {
            return;
        }

        var stack = new Stack<string>();
        stack.Push(root);
        while (stack.Count > 0)
        {
            var current = stack.Pop();
            IEnumerable<string> entries;
            try
            {
                entries = Directory.EnumerateFileSystemEntries(current).ToArray();
            }
            catch (IOException)
            {
                continue;
            }
            catch (UnauthorizedAccessException)
            {
                continue;
            }

            foreach (var entry in entries)
            {
                var name = Path.GetFileName(entry);
                if (name.StartsWith('.') || HubPaths.IgnoreNames.Contains(name))
                {
                    continue;
                }

                bool isDirectory;
                try
                {
                    isDirectory = File.GetAttributes(entry).HasFlag(FileAttributes.Directory);
                }
                catch (IOException)
                {
                    continue;
                }

                visit(entry, isDirectory);
                if (isDirectory)
                {
                    stack.Push(entry);
                }
            }
        }
    }
}
