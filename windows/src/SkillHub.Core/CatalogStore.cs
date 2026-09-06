using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace SkillHub.Core;

public sealed class CatalogStore : INotifyPropertyChanged
{
    readonly MetaStore _metaStore;
    readonly SynchronizationContext? _sync = SynchronizationContext.Current;
    int _scanGeneration;
    string? _loadedDocumentPath;
    Action? _afterNextScan;
    readonly Dictionary<string, int> _countCache = [];

    public CatalogStore(HubPaths paths, MetaStore? metaStore = null)
    {
        Paths = paths;
        _metaStore = metaStore ?? MetaStore.InApplicationSupport();
        Skills = [];
        Prompts = [];
        Stats = OverviewStats.Empty;
        Meta = AppMeta.Empty();
        SidebarSelection = SidebarItem.AllSkills;
    }

    public HubPaths Paths { get; }
    public Action<string>? CopyToClipboard { get; set; }

    public event PropertyChangedEventHandler? PropertyChanged;

    public IReadOnlyList<SkillItem> Skills { get; private set; }
    public IReadOnlyList<PromptItem> Prompts { get; private set; }
    public OverviewStats Stats { get; private set; }
    public AppMeta Meta { get; private set; }
    public bool IsScanning { get; private set; }
    public bool HasLoaded { get; private set; }

    SidebarItem? _sidebarSelection;
    public SidebarItem? SidebarSelection
    {
        get => _sidebarSelection;
        set
        {
            if (Equals(_sidebarSelection, value))
            {
                return;
            }

            _sidebarSelection = value;
            Raise();
            SidebarDidChange();
        }
    }

    string? _selectedSkillId;
    public string? SelectedSkillId
    {
        get => _selectedSkillId;
        set
        {
            if (_selectedSkillId == value)
            {
                return;
            }

            _selectedSkillId = value;
            Raise();
            SelectionDidChange();
        }
    }

    string? _selectedPromptId;
    public string? SelectedPromptId
    {
        get => _selectedPromptId;
        set
        {
            if (_selectedPromptId == value)
            {
                return;
            }

            _selectedPromptId = value;
            Raise();
            SelectionDidChange();
        }
    }

    string _searchText = "";
    public string SearchText
    {
        get => _searchText;
        set
        {
            if (_searchText == value)
            {
                return;
            }

            _searchText = value;
            Raise();
            Raise(nameof(VisibleSkills));
            Raise(nameof(VisiblePrompts));
            Raise(nameof(ClusterNodesUnlimited));
            Raise(nameof(RankedClusterRows));
            Raise(nameof(IsSearching));
        }
    }

    public IReadOnlyList<string> ClusterPath { get; private set; } = [];
    public int MapReplayToken { get; private set; }

    DocumentMode _documentMode = DocumentMode.Preview;
    public DocumentMode DocumentMode
    {
        get => _documentMode;
        set
        {
            if (_documentMode == value)
            {
                return;
            }

            _documentMode = value;
            Raise();
        }
    }

    string _draftText = "";
    public string DraftText
    {
        get => _draftText;
        set
        {
            if (_draftText == value)
            {
                return;
            }

            _draftText = value;
            Raise();
            Raise(nameof(IsDirty));
        }
    }

    public string LoadedText { get; private set; } = "";
    public bool IsDirty => DraftText != LoadedText;

    public HubSheet? ActiveSheet { get; private set; }
    public ConfirmAction? PendingConfirm { get; private set; }
    public bool IsShowingConfirm { get; private set; }
    public string? StatusMessage { get; private set; }
    public bool IsShowingError { get; private set; }
    public string? ErrorMessage { get; private set; }

    public ScanOptions ScanOptions => ScanOptions.From(Meta);
    public SkillItem? SelectedSkill => Skills.FirstOrDefault(s => s.Id == SelectedSkillId);
    public PromptItem? SelectedPrompt => Prompts.FirstOrDefault(p => p.Id == SelectedPromptId);

    public DocumentRef? CurrentDocument => SidebarSelection switch
    {
        SidebarItem.Overview or null => null,
        SidebarItem.Skills => SelectedSkill == null ? null : new DocumentRef.Skill(SelectedSkill),
        SidebarItem.Prompts => SelectedPrompt == null ? null : new DocumentRef.Prompt(SelectedPrompt),
        _ => null
    };

    public BrowseFilter CurrentFilter => SidebarSelection?.Filter ?? BrowseFilter.AllFilter;

    public IReadOnlyList<SkillItem> VisibleSkills => Skills
        .Where(skill => Matches(CurrentFilter, skill) && MatchesSearch(skill.Name, skill.Description, skill.CanonicalPath) && MatchesCluster(skill.Name))
        .ToArray();

    public IReadOnlyList<PromptItem> VisiblePrompts => Prompts
        .Where(prompt => Matches(CurrentFilter, prompt)
                         && MatchesSearch(prompt.Title, prompt.ParentSkillName ?? "", prompt.CanonicalPath)
                         && MatchesCluster(prompt.Title))
        .ToArray();

    public IReadOnlyList<SkillItem> DuplicateSkills => Skills.Where(s => s.IsDuplicateInstall).ToArray();
    public bool IsSearching => !string.IsNullOrWhiteSpace(SearchText);
    public string? ClusterPrefix => ClusterPath.Count == 0 ? null : string.Join('-', ClusterPath);
    public string ClusterTitle => ClusterPrefix ?? SidebarSelection?.Title ?? "Skills";
    public int ClusterItemCount => SidebarSelection?.IsPrompts == true ? VisiblePrompts.Count : VisibleSkills.Count;
    public IReadOnlyList<ClusterNode> ClusterNodesUnlimited => ClusterNodes(null);
    public IReadOnlyList<ClusterNode> ClusterNodesForMap => ClusterNodes(28);

    public IReadOnlyList<ClusterRankedRow> RankedClusterRows
    {
        get
        {
            var nodes = ClusterNodes(null);
            var ranked = nodes
                .Select(node => (Node: node, Score: node.IsGroup ? node.Count : node.OpenCount))
                .OrderByDescending(p => p.Score)
                .ThenBy(p => p.Node.Title, StringComparer.CurrentCultureIgnoreCase)
                .ToList();
            var top = ranked.Count == 0 ? 0 : ranked.Max(p => p.Score);
            return ranked.Select((pair, index) => new ClusterRankedRow(
                pair.Node,
                index + 1,
                top > 0 ? 0.15 + pair.Score / (double)top * 0.85 : 0.5)).ToArray();
        }
    }

    public void Bootstrap()
    {
        Meta = _metaStore.Load(Paths.LegacyMetaFile);
        Raise(nameof(Meta));
        Refresh();
    }

    public void Refresh(Action? then = null)
    {
        _afterNextScan = then ?? _afterNextScan;
        var generation = Interlocked.Increment(ref _scanGeneration);
        var paths = Paths;
        var options = ScanOptions;
        IsScanning = true;
        Raise(nameof(IsScanning));

        _ = Task.Run(() =>
        {
            var snapshot = Scanner.Scan(paths, options);
            OnUi(() =>
            {
                if (generation != _scanGeneration)
                {
                    return;
                }

                Apply(snapshot);
            });
        });
    }

    public void SidebarDidChange()
    {
        ClusterPath = [];
        SearchText = "";
        DocumentMode = DocumentMode.Preview;
        Raise(nameof(ClusterPath));
        Raise(nameof(ClusterPrefix));
        SelectionDidChange();
        RefreshDerived();
    }

    public void SelectionDidChange()
    {
        var document = CurrentDocument;
        if (document == null)
        {
            _loadedDocumentPath = null;
            LoadedText = "";
            DraftText = "";
            DocumentMode = DocumentMode.Preview;
            Raise(nameof(LoadedText));
            Raise(nameof(CurrentDocument));
            return;
        }

        if (_loadedDocumentPath == document.FilePath)
        {
            Raise(nameof(CurrentDocument));
            return;
        }

        LoadDocument(document);
        RecordOpen(document);
        Raise(nameof(CurrentDocument));
    }

    public void Select(DocumentRef document)
    {
        switch (document)
        {
            case DocumentRef.Skill skill:
                if (SidebarSelection?.IsPrompts != false)
                {
                    _sidebarSelection = SidebarItem.AllSkills;
                    Raise(nameof(SidebarSelection));
                }

                _selectedSkillId = skill.Item.Id;
                Raise(nameof(SelectedSkillId));
                break;
            case DocumentRef.Prompt prompt:
                if (SidebarSelection?.IsPrompts != true)
                {
                    _sidebarSelection = SidebarItem.AllPrompts;
                    Raise(nameof(SidebarSelection));
                }

                _selectedPromptId = prompt.Item.Id;
                Raise(nameof(SelectedPromptId));
                break;
        }

        SelectionDidChange();
        RefreshDerived();
    }

    public void OpenCluster(string prefix)
    {
        ClusterPath = ClusterGrouping.Tokens(prefix).ToArray();
        MapReplayToken++;
        Raise(nameof(ClusterPath));
        Raise(nameof(ClusterPrefix));
        Raise(nameof(MapReplayToken));
        RefreshDerived();
    }

    public void PopCluster()
    {
        if (ClusterPath.Count == 0)
        {
            MapReplayToken++;
            Raise(nameof(MapReplayToken));
            return;
        }

        ClusterPath = ClusterPath.Take(ClusterPath.Count - 1).ToArray();
        MapReplayToken++;
        Raise(nameof(ClusterPath));
        Raise(nameof(ClusterPrefix));
        Raise(nameof(MapReplayToken));
        RefreshDerived();
    }

    public void ResetClusters()
    {
        ClusterPath = [];
        MapReplayToken++;
        Raise(nameof(ClusterPath));
        Raise(nameof(ClusterPrefix));
        Raise(nameof(MapReplayToken));
        RefreshDerived();
    }

    public void ReplayMap()
    {
        MapReplayToken++;
        Raise(nameof(MapReplayToken));
    }

    public void Open(ClusterNode node)
    {
        switch (node.Kind)
        {
            case ClusterKind.Group g:
                OpenCluster(g.Prefix);
                break;
            case ClusterKind.Skill s when Skills.FirstOrDefault(item => item.Id == s.Id) is { } skill:
                Select(new DocumentRef.Skill(skill));
                break;
            case ClusterKind.Prompt p when Prompts.FirstOrDefault(item => item.Id == p.Id) is { } prompt:
                Select(new DocumentRef.Prompt(prompt));
                break;
        }
    }

    public string Caption(ClusterNode node) => node.Kind switch
    {
        ClusterKind.Group => $"{node.Count} 个 · 点开这一类",
        ClusterKind.Skill s when Skills.FirstOrDefault(item => item.Id == s.Id) is { } skill =>
            UsageScore.Caption(Meta.ItemForSkill(s.Id).OpenCount, Meta.ItemForSkill(s.Id).Starred, skill.LiveInstallCount),
        ClusterKind.Prompt p =>
            UsageScore.Caption(Meta.ItemForPrompt(p.Id).OpenCount, Meta.ItemForPrompt(p.Id).Starred, 1),
        _ => ""
    };

    public int CountFor(SidebarItem item)
    {
        if (_countCache.TryGetValue(item.Id, out var cached))
        {
            return cached;
        }

        var count = item switch
        {
            SidebarItem.Overview => Skills.Count,
            SidebarItem.Skills s => Skills.Count(skill => Matches(s.Browse, skill)),
            SidebarItem.Prompts p => Prompts.Count(prompt => Matches(p.Browse, prompt)),
            _ => 0
        };
        _countCache[item.Id] = count;
        return count;
    }

    public IReadOnlyList<SkillItem> RelatedSkills(SkillItem skill)
    {
        var tags = Meta.ItemForSkill(skill.Id).Tags.ToHashSet(StringComparer.CurrentCultureIgnoreCase);
        var related = Skills.Where(other =>
            other.Id != skill.Id && (
                (tags.Count > 0 && Meta.ItemForSkill(other.Id).Tags.Any(tags.Contains))
                || other.Name == skill.Name)).ToList();
        if (related.Count > 0)
        {
            return related.Take(6).ToArray();
        }

        return Skills.Where(s => s.Id != skill.Id).OrderByDescending(s => s.ModifiedAt).Take(5).ToArray();
    }

    public IReadOnlyList<PromptItem> RelatedPrompts(PromptItem prompt) =>
        Prompts.Where(other =>
                other.Id != prompt.Id && (
                    (other.ParentSkillPath == prompt.ParentSkillPath && prompt.ParentSkillPath != null)
                    || other.Title == prompt.Title))
            .Take(6)
            .ToArray();

    public IReadOnlyList<PromptItem> PromptsInSkill(string path) =>
        Prompts.Where(p => p.ParentSkillPath == path).ToArray();

    public ItemMeta ItemMetaFor(DocumentRef document) => document switch
    {
        DocumentRef.Skill s => Meta.ItemForSkill(s.Item.Id),
        DocumentRef.Prompt p => Meta.ItemForPrompt(p.Item.Id),
        _ => ItemMeta.Empty()
    };

    public bool IsStarredSkill(string id) => Meta.ItemForSkill(id).Starred;
    public bool IsStarredPrompt(string id) => Meta.ItemForPrompt(id).Starred;

    public void ToggleStar(DocumentRef document) =>
        Update(document, item => item.Starred = !item.Starred);

    public void SetTags(IEnumerable<string> tags, DocumentRef document)
    {
        var unique = new List<string>();
        foreach (var tag in tags.Select(t => t.Trim()).Where(t => t.Length > 0))
        {
            if (!unique.Contains(tag))
            {
                unique.Add(tag);
            }
        }

        Update(document, item => item.Tags = unique);
    }

    public void SetNotes(string notes, DocumentRef document)
    {
        if (ItemMetaFor(document).Notes == notes)
        {
            return;
        }

        Update(document, item => item.Notes = notes);
    }

    public void RecordOpen(DocumentRef document) =>
        Update(document, item =>
        {
            item.OpenCount++;
            item.LastOpenedAt = DateTime.Now;
        });

    public void SetScanProjectSkills(bool enabled)
    {
        if (Meta.ScanProjectSkills == enabled)
        {
            return;
        }

        MutateMeta(meta => meta.ScanProjectSkills = enabled);
        Refresh();
    }

    public void ShowSheet(HubSheet sheet)
    {
        ActiveSheet = sheet;
        Raise(nameof(ActiveSheet));
    }

    public void HideSheet()
    {
        ActiveSheet = null;
        Raise(nameof(ActiveSheet));
    }

    public void DismissError()
    {
        IsShowingError = false;
        ErrorMessage = null;
        Raise(nameof(IsShowingError));
        Raise(nameof(ErrorMessage));
    }

    public void SaveDraft()
    {
        try
        {
            var document = CurrentDocument ?? throw new HubException(HubError.NotFound());
            if (document.IsReadOnly)
            {
                throw new HubException(HubError.BuiltinReadOnly());
            }

            AssertAllowed(document.FilePath);
            PathUtil.WriteAtomic(document.FilePath, DraftText);
            LoadedText = DraftText;
            Raise(nameof(LoadedText));
            Raise(nameof(IsDirty));
            SetStatus($"已保存 {document.Title}");
            Refresh();
        }
        catch (Exception ex)
        {
            Present(ex);
        }
    }

    public void DiscardDraft()
    {
        DraftText = LoadedText;
        DocumentMode = DocumentMode.Preview;
    }

    public void CreateSkill(string name, string description, ToolSource source)
    {
        try
        {
            var slug = Frontmatter.Slug(name);
            if (!Frontmatter.IsValidSkillName(slug))
            {
                throw new HubException(HubError.InvalidName());
            }

            var root = Paths.SkillRoot(source);
            if (!source.IsWritable() || !source.IsSkillRoot() || root == null)
            {
                throw new HubException(HubError.BuiltinReadOnly());
            }

            Directory.CreateDirectory(root);
            var folder = Path.Combine(root, slug);
            AssertAllowed(folder);
            if (Directory.Exists(folder) || File.Exists(folder))
            {
                throw new HubException(HubError.AlreadyExists(slug));
            }

            Directory.CreateDirectory(folder);
            PathUtil.WriteAtomic(Path.Combine(folder, "SKILL.md"), Frontmatter.Render(slug, description, ""));
            HideSheet();
            SetStatus($"已新建 skill「{slug}」");
            var newId = PathUtil.RealPath(folder);
            Refresh(() =>
            {
                _sidebarSelection = SidebarItem.AllSkills;
                _selectedSkillId = newId;
                Raise(nameof(SidebarSelection));
                Raise(nameof(SelectedSkillId));
                SelectionDidChange();
            });
        }
        catch (Exception ex)
        {
            Present(ex);
        }
    }

    public void CreatePrompt(string title, string body)
    {
        try
        {
            Paths.EnsureContentDirectories();
            var slug = Frontmatter.Slug(title);
            if (slug.Length == 0)
            {
                throw new HubException(HubError.InvalidName());
            }

            var file = Path.Combine(Paths.PromptLibrary, $"{slug}.md");
            AssertAllowed(file);
            if (File.Exists(file))
            {
                throw new HubException(HubError.AlreadyExists(slug));
            }

            PathUtil.WriteAtomic(file, $"# {title.Trim()}\n\n{body}\n");
            HideSheet();
            SetStatus($"已新建 prompt「{title}」");
            var newId = PathUtil.RealPath(file);
            Refresh(() =>
            {
                _sidebarSelection = SidebarItem.AllPrompts;
                _selectedPromptId = newId;
                Raise(nameof(SidebarSelection));
                Raise(nameof(SelectedPromptId));
                SelectionDidChange();
            });
        }
        catch (Exception ex)
        {
            Present(ex);
        }
    }

    public void SavePromptAsStandalone(PromptItem prompt)
    {
        try
        {
            Paths.EnsureContentDirectories();
            var slug = Frontmatter.Slug(prompt.Title);
            var dest = Path.Combine(Paths.PromptLibrary, $"{slug}.md");
            AssertAllowed(dest);
            if (File.Exists(dest))
            {
                throw new HubException(HubError.AlreadyExists(slug));
            }

            File.Copy(prompt.CanonicalPath, dest);
            SetStatus("已另存到独立库");
            var newId = PathUtil.RealPath(dest);
            Refresh(() =>
            {
                _sidebarSelection = SidebarItem.AllPrompts;
                _selectedPromptId = newId;
                Raise(nameof(SidebarSelection));
                Raise(nameof(SelectedPromptId));
                SelectionDidChange();
            });
        }
        catch (Exception ex)
        {
            Present(ex);
        }
    }

    public IReadOnlyList<ToolSource> AvailableInstallTargets(SkillItem skill)
    {
        var installed = skill.Installations.Select(i => i.Source).ToHashSet();
        return ToolSourceInfo.SkillRoots.Where(s => s.IsWritable() && !installed.Contains(s)).ToArray();
    }

    public void Install(SkillItem skill, ToolSource source, bool asCopy)
    {
        try
        {
            var root = Paths.SkillRoot(source);
            if (!source.IsWritable() || !source.IsSkillRoot() || root == null)
            {
                throw new HubException(HubError.BuiltinReadOnly());
            }

            Directory.CreateDirectory(root);
            var dest = Path.Combine(root, skill.FolderName);
            AssertAllowed(dest);
            if (Directory.Exists(dest) || File.Exists(dest))
            {
                throw new HubException(HubError.AlreadyExists(skill.FolderName));
            }

            if (asCopy)
            {
                CopyDirectory(skill.CanonicalPath, dest);
            }
            else
            {
                FileLinks.CreateDirectoryLink(dest, skill.CanonicalPath);
            }

            HideSheet();
            SetStatus(asCopy ? $"已复制到 {source.Title()}" : $"已链接到 {source.Title()}");
            Refresh();
        }
        catch (Exception ex)
        {
            Present(ex);
        }
    }

    public void Dedupe(SkillItem skill, Installation keep)
    {
        try
        {
            ApplyDedupe(skill, keep);
            HideSheet();
            SetStatus($"已只保留 {keep.Source.Title()} 里的「{skill.Name}」");
            Refresh();
        }
        catch (Exception ex)
        {
            Present(ex);
        }
    }

    public void DedupeAll(DedupePolicy policy)
    {
        var targets = DuplicateSkills;
        if (targets.Count == 0)
        {
            HideSheet();
            return;
        }

        var succeeded = 0;
        var failed = 0;
        Exception? lastFailure = null;
        foreach (var skill in targets)
        {
            var keep = InstallationToKeep(skill, policy);
            if (keep == null)
            {
                continue;
            }

            try
            {
                ApplyDedupe(skill, keep);
                succeeded++;
            }
            catch (Exception ex)
            {
                failed++;
                lastFailure = ex;
            }
        }

        HideSheet();
        if (lastFailure != null && failed > 0)
        {
            SetStatus($"去重完成 {succeeded} 个，失败 {failed} 个");
            Present(lastFailure);
        }
        else
        {
            SetStatus($"已去重 {succeeded} 个 skill");
        }

        Refresh();
    }

    public void Request(ConfirmAction action)
    {
        PendingConfirm = action;
        IsShowingConfirm = true;
        Raise(nameof(PendingConfirm));
        Raise(nameof(IsShowingConfirm));
    }

    public void RequestDelete(DocumentRef document)
    {
        switch (document)
        {
            case DocumentRef.Skill s:
                Request(new ConfirmAction.DeleteSkill(s.Item.Id, s.Item.RealCount <= 1));
                break;
            case DocumentRef.Prompt p:
                Request(new ConfirmAction.DeletePrompt(p.Item.Id, p.Item.Kind == PromptKind.Standalone));
                break;
        }
    }

    public void RequestArchive(DocumentRef document)
    {
        switch (document)
        {
            case DocumentRef.Skill s:
                Request(new ConfirmAction.ArchiveSkill(s.Item.Id));
                break;
            case DocumentRef.Prompt p:
                Request(new ConfirmAction.ArchivePrompt(p.Item.Id));
                break;
        }
    }

    public void CancelConfirm()
    {
        PendingConfirm = null;
        IsShowingConfirm = false;
        Raise(nameof(PendingConfirm));
        Raise(nameof(IsShowingConfirm));
    }

    public void Perform(ConfirmAction action)
    {
        try
        {
            switch (action)
            {
                case ConfirmAction.RemoveInstall r:
                    RemoveInstall(r.Path, r.IsSymlink);
                    SetStatus(r.IsSymlink ? "已移除符号链接" : "已移除该安装");
                    break;
                case ConfirmAction.DeleteSkill d:
                    DeleteSkillEntity(d.SkillId);
                    _selectedSkillId = null;
                    Raise(nameof(SelectedSkillId));
                    SetStatus("已删除 skill");
                    break;
                case ConfirmAction.DeletePrompt d:
                    DeletePrompt(d.PromptId);
                    _selectedPromptId = null;
                    Raise(nameof(SelectedPromptId));
                    SetStatus("已删除 prompt");
                    break;
                case ConfirmAction.ArchiveSkill a:
                    ArchiveSkill(a.SkillId);
                    _selectedSkillId = null;
                    Raise(nameof(SelectedSkillId));
                    SetStatus("已归档 skill");
                    break;
                case ConfirmAction.ArchivePrompt a:
                    ArchivePrompt(a.PromptId);
                    _selectedPromptId = null;
                    Raise(nameof(SelectedPromptId));
                    SetStatus("已归档 prompt");
                    break;
            }

            CancelConfirm();
            Refresh();
        }
        catch (Exception ex)
        {
            CancelConfirm();
            Present(ex);
        }
    }

    public void Reveal(DocumentRef document)
    {
        var path = document.RevealPath;
        try
        {
            if (OperatingSystem.IsWindows())
            {
                Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{path}\"") { UseShellExecute = true });
            }
            else if (OperatingSystem.IsMacOS())
            {
                Process.Start("open", ["-R", path]);
            }
            else
            {
                var folder = Directory.Exists(path) ? path : Path.GetDirectoryName(path);
                if (folder != null)
                {
                    Process.Start(new ProcessStartInfo(folder) { UseShellExecute = true });
                }
            }
        }
        catch (Exception ex)
        {
            Present(ex);
        }
    }

    public void CopyPath(string text) => CopyToClipboard?.Invoke(text);

    public IReadOnlyList<ClusterNode> ClusterNodes(int? looseCap)
    {
        IReadOnlyList<ClusterBuilder.Item> items;
        if (SidebarSelection?.IsPrompts == true)
        {
            items = VisiblePrompts.Select(prompt =>
            {
                var item = Meta.ItemForPrompt(prompt.Id);
                return new ClusterBuilder.Item(prompt.Id, prompt.Title, UsageScore.Score(prompt, item, DateTime.Now), item.OpenCount, false);
            }).ToArray();
        }
        else
        {
            items = VisibleSkills.Select(skill =>
            {
                var item = Meta.ItemForSkill(skill.Id);
                return new ClusterBuilder.Item(skill.Id, skill.Name, UsageScore.Score(skill, item, DateTime.Now), item.OpenCount, true);
            }).ToArray();
        }

        return ClusterBuilder.Nodes(items, ClusterPrefix, looseCap);
    }

    void Apply(CatalogSnapshot snapshot)
    {
        _countCache.Clear();
        Skills = snapshot.Skills;
        Prompts = snapshot.Prompts;
        Stats = OverviewStats.From(snapshot);
        IsScanning = false;
        HasLoaded = true;
        var then = _afterNextScan;
        _afterNextScan = null;
        Raise(nameof(Skills));
        Raise(nameof(Prompts));
        Raise(nameof(Stats));
        Raise(nameof(IsScanning));
        Raise(nameof(HasLoaded));
        Raise(nameof(DuplicateSkills));
        ReloadDocumentIfNeeded();
        then?.Invoke();
        RefreshDerived();
    }

    void LoadDocument(DocumentRef document)
    {
        string text;
        try
        {
            text = File.Exists(document.FilePath) ? File.ReadAllText(document.FilePath) : "";
        }
        catch (IOException)
        {
            text = "";
        }

        _loadedDocumentPath = document.FilePath;
        LoadedText = text;
        DraftText = text;
        DocumentMode = DocumentMode.Preview;
        Raise(nameof(LoadedText));
    }

    void ReloadDocumentIfNeeded()
    {
        var document = CurrentDocument;
        if (document == null)
        {
            if (SelectedSkillId != null || SelectedPromptId != null)
            {
                SelectionDidChange();
            }

            return;
        }

        if (IsDirty)
        {
            return;
        }

        try
        {
            var text = File.Exists(document.FilePath) ? File.ReadAllText(document.FilePath) : "";
            _loadedDocumentPath = document.FilePath;
            LoadedText = text;
            DraftText = text;
            Raise(nameof(LoadedText));
        }
        catch (IOException)
        {
        }
    }

    void ApplyDedupe(SkillItem skill, Installation keep)
    {
        if (keep.Source.IsWritable())
        {
            AssertAllowed(keep.Path);
        }

        foreach (var install in skill.Installations.Where(i => i.Path != keep.Path && i.Source.IsWritable()))
        {
            if (install.IsSymlink)
            {
                RemoveInstall(install.Path, true);
                continue;
            }

            var real = PathUtil.RealPath(install.Path);
            if (string.Equals(real, skill.CanonicalPath, OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal))
            {
                continue;
            }

            AssertAllowed(install.Path);
            Directory.Delete(install.Path, recursive: true);
        }

        var keptIsLink = PathUtil.IsSymbolicLink(keep.Path);
        if (keptIsLink && keep.Source.IsWritable())
        {
            RemoveInstall(keep.Path, true);
            if (!PathUtil.Standardize(skill.CanonicalPath).Equals(PathUtil.Standardize(keep.Path), OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal))
            {
                AssertAllowed(skill.CanonicalPath);
                if (Directory.Exists(keep.Path) || File.Exists(keep.Path))
                {
                    if (Directory.Exists(keep.Path))
                    {
                        Directory.Delete(keep.Path, true);
                    }
                    else
                    {
                        File.Delete(keep.Path);
                    }
                }

                Directory.Move(skill.CanonicalPath, keep.Path);
            }
        }
    }

    Installation? InstallationToKeep(SkillItem skill, DedupePolicy policy) => policy switch
    {
        DedupePolicy.KeepEntity =>
            skill.Installations.FirstOrDefault(i => !i.IsSymlink && i.Source.IsWritable())
            ?? skill.Installations.FirstOrDefault(i => !i.IsSymlink)
            ?? skill.Installations.FirstOrDefault(i => i.Source.IsWritable()),
        DedupePolicy.Prefer p =>
            skill.Installations.FirstOrDefault(i => i.Source == p.Source)
            ?? InstallationToKeep(skill, DedupePolicy.KeepEntityPolicy),
        _ => null
    };

    void RemoveInstall(string path, bool expectSymlink)
    {
        AssertAllowed(path);
        var isSymlink = PathUtil.IsSymbolicLink(path);
        if (expectSymlink && !isSymlink)
        {
            throw new HubException(HubError.LastEntity());
        }

        if (Directory.Exists(path) || PathUtil.IsSymbolicLink(path))
        {
            Directory.Delete(path, recursive: !isSymlink);
        }
        else if (File.Exists(path))
        {
            File.Delete(path);
        }
    }

    void DeleteSkillEntity(string id)
    {
        var skill = Skills.FirstOrDefault(s => s.Id == id) ?? throw new HubException(HubError.NotFound());
        foreach (var install in skill.Installations.Where(i => i.IsSymlink))
        {
            try
            {
                RemoveInstall(install.Path, true);
            }
            catch (Exception)
            {
            }
        }

        AssertAllowed(skill.CanonicalPath);
        Directory.Delete(skill.CanonicalPath, true);
    }

    void ArchiveSkill(string id)
    {
        var skill = Skills.FirstOrDefault(s => s.Id == id) ?? throw new HubException(HubError.NotFound());
        Paths.EnsureContentDirectories();
        foreach (var install in skill.Installations.Where(i => i.IsSymlink))
        {
            try
            {
                RemoveInstall(install.Path, true);
            }
            catch (Exception)
            {
            }
        }

        var dest = Path.Combine(Paths.ArchiveRoot, $"{ArchiveStamp()}-{skill.FolderName}");
        AssertAllowed(skill.CanonicalPath);
        Directory.Move(skill.CanonicalPath, dest);
        MutateMeta(meta => meta.ArchiveLog.Insert(0, new ArchiveRecord
        {
            OriginalPath = skill.CanonicalPath,
            ArchivePath = dest,
            Name = skill.Name,
            Date = DateTime.Now
        }));
    }

    void DeletePrompt(string id)
    {
        var prompt = Prompts.FirstOrDefault(p => p.Id == id) ?? throw new HubException(HubError.NotFound());
        AssertAllowed(prompt.CanonicalPath);
        File.Delete(prompt.CanonicalPath);
    }

    void ArchivePrompt(string id)
    {
        var prompt = Prompts.FirstOrDefault(p => p.Id == id) ?? throw new HubException(HubError.NotFound());
        Paths.EnsureContentDirectories();
        var dest = Path.Combine(Paths.ArchiveRoot, $"{ArchiveStamp()}-{Path.GetFileName(prompt.CanonicalPath)}");
        AssertAllowed(prompt.CanonicalPath);
        File.Move(prompt.CanonicalPath, dest);
        MutateMeta(meta => meta.ArchiveLog.Insert(0, new ArchiveRecord
        {
            OriginalPath = prompt.CanonicalPath,
            ArchivePath = dest,
            Name = prompt.Title,
            Date = DateTime.Now
        }));
    }

    static string ArchiveStamp() => DateTime.Now.ToString("yyyyMMdd-HHmmss");

    void AssertAllowed(string path)
    {
        if (Paths.IsBuiltinPath(path))
        {
            throw new HubException(HubError.BuiltinReadOnly());
        }

        if (!Paths.WritableRoots(ScanOptions).Any(root => PathUtil.IsUnder(root, path)))
        {
            throw new HubException(HubError.PathNotAllowed(PathUtil.Standardize(path)));
        }
    }

    static void CopyDirectory(string source, string dest)
    {
        Directory.CreateDirectory(dest);
        foreach (var file in Directory.EnumerateFiles(source))
        {
            File.Copy(file, Path.Combine(dest, Path.GetFileName(file)));
        }

        foreach (var dir in Directory.EnumerateDirectories(source))
        {
            CopyDirectory(dir, Path.Combine(dest, Path.GetFileName(dir)));
        }
    }

    void MutateMeta(Action<AppMeta> change)
    {
        change(Meta);
        _countCache.Clear();
        try
        {
            _metaStore.Save(Meta);
        }
        catch (Exception)
        {
        }

        Raise(nameof(Meta));
        RefreshDerived();
    }

    void Update(DocumentRef document, Action<ItemMeta> change)
    {
        MutateMeta(meta =>
        {
            switch (document)
            {
                case DocumentRef.Skill s:
                {
                    var item = meta.ItemForSkill(s.Item.Id).Clone();
                    change(item);
                    meta.Skills[s.Item.Id] = item;
                    break;
                }
                case DocumentRef.Prompt p:
                {
                    var item = meta.ItemForPrompt(p.Item.Id).Clone();
                    change(item);
                    meta.Prompts[p.Item.Id] = item;
                    break;
                }
            }
        });
    }

    bool Matches(BrowseFilter filter, SkillItem skill) => filter switch
    {
        BrowseFilter.All or BrowseFilter.Standalone or BrowseFilter.Embedded => true,
        BrowseFilter.Tool t => skill.Installations.Any(i => i.Source == t.Source),
        BrowseFilter.Duplicates => skill.IsDuplicateInstall,
        BrowseFilter.Starred => Meta.ItemForSkill(skill.Id).Starred,
        BrowseFilter.Health => skill.Health.Count > 0,
        _ => true
    };

    bool Matches(BrowseFilter filter, PromptItem prompt) => filter switch
    {
        BrowseFilter.All => true,
        BrowseFilter.Tool t => prompt.Source == t.Source,
        BrowseFilter.Duplicates or BrowseFilter.Health => false,
        BrowseFilter.Starred => Meta.ItemForPrompt(prompt.Id).Starred,
        BrowseFilter.Standalone => prompt.Kind == PromptKind.Standalone,
        BrowseFilter.Embedded => prompt.Kind == PromptKind.Embedded,
        _ => true
    };

    bool MatchesSearch(params string[] fields)
    {
        var query = SearchText.Trim();
        return query.Length == 0 || fields.Any(f => f.Contains(query, StringComparison.CurrentCultureIgnoreCase));
    }

    bool MatchesCluster(string name) => ClusterPrefix == null || ClusterGrouping.Belongs(name, ClusterPrefix);

    void Present(Exception error)
    {
        ErrorMessage = error is HubException hub ? hub.Message : error.Message;
        IsShowingError = true;
        Raise(nameof(ErrorMessage));
        Raise(nameof(IsShowingError));
    }

    void SetStatus(string message)
    {
        StatusMessage = message;
        Raise(nameof(StatusMessage));
    }

    void RefreshDerived()
    {
        Raise(nameof(VisibleSkills));
        Raise(nameof(VisiblePrompts));
        Raise(nameof(ClusterNodesUnlimited));
        Raise(nameof(ClusterNodesForMap));
        Raise(nameof(RankedClusterRows));
        Raise(nameof(ClusterTitle));
        Raise(nameof(ClusterItemCount));
        Raise(nameof(SelectedSkill));
        Raise(nameof(SelectedPrompt));
        Raise(nameof(CurrentDocument));
    }

    void OnUi(Action action)
    {
        if (_sync == null || SynchronizationContext.Current == _sync)
        {
            action();
        }
        else
        {
            _sync.Post(_ => action(), null);
        }
    }

    void Raise([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public sealed record ClusterRankedRow(ClusterNode Node, int Rank, double Fraction);
