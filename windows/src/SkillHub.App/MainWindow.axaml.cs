using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using SkillHub.Core;

namespace SkillHub.App;

public partial class MainWindow : Window
{
    readonly CatalogStore _store;
    readonly List<SidebarItem> _sidebarItems = [];
    bool _suppressBrowse;
    bool _inspectorVisible = true;

    public MainWindow()
        : this(new CatalogStore(new HubPaths(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile))))
    {
    }

    public MainWindow(CatalogStore store)
    {
        _store = store;
        InitializeComponent();
        KeyDown += OnKeyDown;
        NewSkillButton.Click += (_, _) => OpenSheet(HubSheet.NewSkill);
        NewPromptButton.Click += (_, _) => OpenSheet(HubSheet.NewPrompt);
        RefreshButton.Click += (_, _) => _store.Refresh();
        InspectorToggle.IsCheckedChanged += (_, _) =>
        {
            _inspectorVisible = InspectorToggle.IsChecked == true;
            InspectorHost.IsVisible = _inspectorVisible;
            InspectorSplitter.IsVisible = _inspectorVisible;
        };
        SearchBox.TextChanged += (_, _) => _store.SearchText = SearchBox.Text ?? "";
        SidebarList.SelectionChanged += OnSidebarChanged;
        BrowseList.SelectionChanged += OnBrowseChanged;
        DocumentModeBox.SelectionChanged += OnDocumentModeChanged;
        SaveButton.Click += (_, _) => _store.SaveDraft();
        DiscardButton.Click += (_, _) => _store.DiscardDraft();
        EditorBox.TextChanged += (_, _) =>
        {
            if (EditorHost.IsVisible)
            {
                _store.DraftText = EditorBox.Text ?? "";
                EditorStatus.Text = _store.IsDirty ? "未保存的更改" : "已与磁盘同步";
            }
        };
        OverviewMap.NodeActivated += _store.Open;
        OverviewMap.NucleusActivated += _store.PopCluster;
        DetailMap.NodeActivated += _store.Open;
        DetailMap.NucleusActivated += _store.PopCluster;

        BuildSidebar();
        _store.PropertyChanged += (_, e) => Dispatcher.UIThread.Post(() => OnStoreChanged(e.PropertyName));
        _store.CopyToClipboard = text =>
        {
            if (Clipboard != null)
            {
                _ = Clipboard.SetTextAsync(text);
            }
        };
        _store.Bootstrap();
        RefreshAll();
    }

    void OnKeyDown(object? sender, KeyEventArgs e)
    {
        var ctrl = e.KeyModifiers.HasFlag(KeyModifiers.Control);
        if (ctrl && e.Key == Key.N && e.KeyModifiers.HasFlag(KeyModifiers.Shift))
        {
            OpenSheet(HubSheet.NewPrompt);
            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.N)
        {
            OpenSheet(HubSheet.NewSkill);
            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.S)
        {
            _store.SaveDraft();
            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.R)
        {
            _store.Refresh();
            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.D1)
        {
            _store.SidebarSelection = SidebarItem.OverviewItem;
            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.D2)
        {
            _store.SidebarSelection = SidebarItem.AllSkills;
            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.D3)
        {
            _store.SidebarSelection = SidebarItem.AllPrompts;
            e.Handled = true;
        }
    }

    void OnStoreChanged(string? name)
    {
        if (name is nameof(CatalogStore.IsShowingError) && _store.IsShowingError)
        {
            _ = ShowErrorAsync();
            return;
        }

        if (name is nameof(CatalogStore.IsShowingConfirm) && _store.IsShowingConfirm && _store.PendingConfirm != null)
        {
            _ = ShowConfirmAsync(_store.PendingConfirm);
            return;
        }

        RefreshAll();
    }

    void RefreshAll()
    {
        StatusLabel.Text = _store.IsScanning
            ? "正在扫描…"
            : _store.StatusMessage ?? $"{_store.Skills.Count} 个 skill · {_store.Prompts.Count} 个 prompt";
        RefreshButton.IsEnabled = !_store.IsScanning;
        RefreshSidebarCounts();
        RefreshBrowse();
        RefreshDetail();
        RefreshInspector();
    }

    void BuildSidebar()
    {
        _sidebarItems.Clear();
        SidebarList.Items.Clear();
            AddSidebar(SidebarItem.OverviewItem, "总览");
        AddHeader("Skills");
        foreach (var filter in BrowseFilter.SkillFilters)
        {
            AddSidebar(new SidebarItem.Skills(filter), filter.Title);
        }

        AddHeader("按工具");
        foreach (var source in ToolSourceInfo.SkillRoots)
        {
            AddSidebar(new SidebarItem.Skills(new BrowseFilter.Tool(source)), source.Title());
        }

        AddHeader("Prompts");
        foreach (var filter in BrowseFilter.PromptFilters.Concat(BrowseFilter.PromptSources))
        {
            AddSidebar(new SidebarItem.Prompts(filter), filter.Title);
        }

        for (var i = 0; i < SidebarList.ItemCount; i++)
        {
            if (SidebarList.Items[i] is ListBoxItem { Tag: SidebarItem item } && Equals(item, SidebarItem.AllSkills))
            {
                SidebarList.SelectedIndex = i;
                break;
            }
        }
    }

    void AddHeader(string title)
    {
        SidebarList.Items.Add(new ListBoxItem
        {
            IsEnabled = false,
            Content = new TextBlock
            {
                Text = title,
                FontSize = 11,
                FontWeight = FontWeight.SemiBold,
                Opacity = 0.6,
                Margin = new Thickness(8, 12, 8, 4)
            }
        });
        _sidebarItems.Add(SidebarItem.OverviewItem);
    }

    void AddSidebar(SidebarItem item, string title)
    {
        _sidebarItems.Add(item);
        var row = new DockPanel { Margin = new Thickness(4, 2) };
        var count = new TextBlock
        {
            Name = "Count",
            Classes = { "caption" },
            VerticalAlignment = VerticalAlignment.Center
        };
        DockPanel.SetDock(count, Dock.Right);
        row.Children.Add(count);
        row.Children.Add(new TextBlock { Text = title, VerticalAlignment = VerticalAlignment.Center });
        row.Tag = item;
        SidebarList.Items.Add(new ListBoxItem { Content = row, Tag = item });
    }

    void RefreshSidebarCounts()
    {
        for (var i = 0; i < SidebarList.ItemCount && i < _sidebarItems.Count; i++)
        {
            if (SidebarList.Items[i] is not ListBoxItem { Content: DockPanel panel, IsEnabled: true } ||
                panel.Tag is not SidebarItem item)
            {
                continue;
            }

            var count = panel.Children.OfType<TextBlock>().FirstOrDefault(t => t.Name == "Count");
            if (count != null)
            {
                count.Text = _store.CountFor(item).ToString();
            }
        }
    }

    void OnSidebarChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (SidebarList.SelectedItem is not ListBoxItem { Tag: SidebarItem item })
        {
            return;
        }

        if (!Equals(_store.SidebarSelection, item))
        {
            _store.SidebarSelection = item;
        }
    }

    void RefreshBrowse()
    {
        _suppressBrowse = true;
        BrowseList.Items.Clear();
        RefreshBreadcrumb();

        if (_store.SidebarSelection is SidebarItem.Overview)
        {
            foreach (var row in _store.RankedClusterRows)
            {
                BrowseList.Items.Add(MakeClusterRow(row));
            }

            BrowseEmpty.IsVisible = _store.RankedClusterRows.Count == 0;
        }
        else if (_store.SidebarSelection?.IsPrompts == true)
        {
            foreach (var prompt in _store.VisiblePrompts)
            {
                BrowseList.Items.Add(MakePromptRow(prompt));
            }

            BrowseEmpty.IsVisible = _store.VisiblePrompts.Count == 0;
        }
        else
        {
            foreach (var skill in _store.VisibleSkills)
            {
                BrowseList.Items.Add(MakeSkillRow(skill));
            }

            BrowseEmpty.IsVisible = _store.VisibleSkills.Count == 0;
        }

        _suppressBrowse = false;
    }

    void RefreshBreadcrumb()
    {
        BreadcrumbBar.Items.Clear();
        if (_store.ClusterPath.Count == 0)
        {
            BreadcrumbBar.IsVisible = false;
            return;
        }

        BreadcrumbBar.IsVisible = true;
        var root = new Button { Content = _store.SidebarSelection?.Title ?? "全部" };
        root.Click += (_, _) => _store.ResetClusters();
        BreadcrumbBar.Items.Add(root);
        for (var i = 0; i < _store.ClusterPath.Count; i++)
        {
            BreadcrumbBar.Items.Add(new TextBlock { Text = "›", VerticalAlignment = VerticalAlignment.Center, Opacity = 0.5 });
            var prefix = string.Join('-', _store.ClusterPath.Take(i + 1));
            var button = new Button { Content = _store.ClusterPath[i] };
            button.Click += (_, _) => _store.OpenCluster(prefix);
            BreadcrumbBar.Items.Add(button);
        }
    }

    ListBoxItem MakeSkillRow(SkillItem skill)
    {
        var block = new StackPanel { Spacing = 4, Margin = new Thickness(8, 6) };
        var title = new DockPanel();
        var flags = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        DockPanel.SetDock(flags, Dock.Right);
        if (_store.IsStarredSkill(skill.Id))
        {
            flags.Children.Add(new TextBlock { Text = "★", Foreground = Brushes.Goldenrod });
        }

        if (skill.Health.Count > 0)
        {
            flags.Children.Add(new TextBlock { Text = "⚠", Foreground = Brushes.Orange });
        }

        title.Children.Add(flags);
        title.Children.Add(new TextBlock { Text = skill.Name, FontWeight = FontWeight.SemiBold });
        block.Children.Add(title);
        block.Children.Add(new TextBlock
        {
            Text = string.IsNullOrEmpty(skill.Description) ? "还没有 description" : skill.Description,
            Classes = { "caption" },
            TextWrapping = TextWrapping.Wrap
        });
        var badges = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        foreach (var source in skill.ToolSources)
        {
            badges.Children.Add(Badge(source.Title(), ColorUtil.Tool(source), ColorUtil.Soft(source)));
        }

        if (skill.IsDuplicateInstall)
        {
            badges.Children.Add(new TextBlock { Text = $"{skill.Installations.Count} 处", Classes = { "caption" } });
        }

        block.Children.Add(badges);
        return new ListBoxItem { Content = block, Tag = skill };
    }

    ListBoxItem MakePromptRow(PromptItem prompt)
    {
        var block = new StackPanel { Spacing = 4, Margin = new Thickness(8, 6) };
        var title = new DockPanel();
        if (_store.IsStarredPrompt(prompt.Id))
        {
            var star = new TextBlock { Text = "★", Foreground = Brushes.Goldenrod };
            DockPanel.SetDock(star, Dock.Right);
            title.Children.Add(star);
        }

        title.Children.Add(new TextBlock { Text = prompt.Title, FontWeight = FontWeight.SemiBold });
        block.Children.Add(title);
        var meta = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        meta.Children.Add(Badge(prompt.Kind.Title(), ColorUtil.Tool(prompt.Source), ColorUtil.Soft(prompt.Source)));
        if (prompt.ParentSkillName != null)
        {
            meta.Children.Add(new TextBlock { Text = prompt.ParentSkillName, Classes = { "caption" } });
        }
        else
        {
            meta.Children.Add(new TextBlock { Text = prompt.Source.Title(), Classes = { "caption" } });
        }

        block.Children.Add(meta);
        return new ListBoxItem { Content = block, Tag = prompt };
    }

    ListBoxItem MakeClusterRow(ClusterRankedRow row)
    {
        var bar = new Border
        {
            Height = 4,
            CornerRadius = new CornerRadius(2),
            Background = ColorUtil.ClusterSoft(row.Node.Title),
            Width = 40 + row.Fraction * 180,
            HorizontalAlignment = HorizontalAlignment.Left,
            Margin = new Thickness(0, 4, 0, 0)
        };
        var block = new StackPanel { Margin = new Thickness(8, 6), Spacing = 2 };
        block.Children.Add(new TextBlock
        {
            Text = $"{row.Rank}. {row.Node.Title}",
            FontWeight = row.Node.IsGroup ? FontWeight.SemiBold : FontWeight.Medium
        });
        block.Children.Add(new TextBlock { Text = _store.Caption(row.Node), Classes = { "caption" } });
        block.Children.Add(bar);
        return new ListBoxItem { Content = block, Tag = row.Node };
    }

    void OnBrowseChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_suppressBrowse || BrowseList.SelectedItem is not ListBoxItem item)
        {
            return;
        }

        switch (item.Tag)
        {
            case SkillItem skill:
                _store.SelectedSkillId = skill.Id;
                break;
            case PromptItem prompt:
                _store.SelectedPromptId = prompt.Id;
                break;
            case ClusterNode node:
                _store.Open(node);
                break;
        }
    }

    void RefreshDetail()
    {
        var document = _store.CurrentDocument;
        var overview = _store.SidebarSelection is SidebarItem.Overview;
        OverviewHost.IsVisible = overview;
        var showDocument = document != null && !overview;
        DocumentModeBox.IsVisible = showDocument;
        SaveButton.IsVisible = showDocument && _store.DocumentMode == DocumentMode.Edit;
        DiscardButton.IsVisible = showDocument && _store.IsDirty;
        PreviewHost.IsVisible = showDocument && _store.DocumentMode == DocumentMode.Preview;
        EditorHost.IsVisible = showDocument && _store.DocumentMode == DocumentMode.Edit;
        DetailMap.IsVisible = !overview && document == null;

        DetailTitle.Text = document?.Title ?? _store.SidebarSelection?.Title ?? "Skill Hub";
        DetailSubtitle.Text = document?.Subtitle ?? _store.StatusMessage ?? "";

        if (overview)
        {
            RebuildOverview();
        }
        else if (document != null && _store.DocumentMode == DocumentMode.Preview)
        {
            RebuildPreview(document);
        }
        else if (document != null && _store.DocumentMode == DocumentMode.Edit)
        {
            if (EditorBox.Text != _store.DraftText)
            {
                EditorBox.Text = _store.DraftText;
            }

            EditorStatus.Text = _store.IsDirty ? "未保存的更改" : "已与磁盘同步";
        }
        else
        {
            DetailMap.Nodes = _store.ClusterNodesForMap;
            DetailMap.NucleusTitle = _store.ClusterTitle;
            DetailMap.NucleusCount = _store.ClusterItemCount;
        }

        DocumentModeBox.SelectedIndex = _store.DocumentMode == DocumentMode.Edit ? 1 : 0;
    }

    void RebuildOverview()
    {
        StatsGrid.Children.Clear();
        AddStat("Skills", _store.Stats.UniqueSkills);
        AddStat("Prompts", _store.Stats.UniquePrompts);
        AddStat("重复安装", _store.Stats.DuplicateSkills);
        AddStat("符号链接", _store.Stats.SymlinkInstalls);

        OverviewSplit.Children.Clear();
        var tools = new Border { Classes = { "card" } };
        var toolStack = new StackPanel { Spacing = 8 };
        toolStack.Children.Add(new TextBlock { Text = "按工具", FontWeight = FontWeight.SemiBold });
        foreach (var source in ToolSourceInfo.SkillRoots)
        {
            var row = new DockPanel();
            var count = new TextBlock { Text = _store.Stats.ByTool.GetValueOrDefault(source).ToString(), Classes = { "caption" } };
            DockPanel.SetDock(count, Dock.Right);
            row.Children.Add(count);
            row.Children.Add(new TextBlock { Text = source.Title(), Foreground = ColorUtil.Tool(source) });
            toolStack.Children.Add(row);
        }

        tools.Child = toolStack;
        Grid.SetColumn(tools, 0);
        OverviewSplit.Children.Add(tools);

        var health = new Border { Classes = { "card" } };
        var healthStack = new StackPanel { Spacing = 8 };
        healthStack.Children.Add(new TextBlock { Text = "健康", FontWeight = FontWeight.SemiBold });
        healthStack.Children.Add(Labeled("缺少 description", _store.Stats.MissingDescriptions.ToString()));
        healthStack.Children.Add(Labeled("损坏的符号链接", _store.Stats.BrokenLinks.ToString()));
        healthStack.Children.Add(Labeled("重复安装", _store.Stats.DuplicateSkills.ToString()));
        if (_store.DuplicateSkills.Count > 0)
        {
            var dedupe = new Button { Content = $"一键去重 {_store.DuplicateSkills.Count} 个…" };
            dedupe.Click += (_, _) => OpenSheet(HubSheet.Dedupe);
            healthStack.Children.Add(dedupe);
        }

        var scanProjects = new CheckBox
        {
            Content = "同时扫描 ~/Projects 里各项目的 skill",
            IsChecked = _store.Meta.ScanProjectSkills
        };
        scanProjects.IsCheckedChanged += (_, _) => _store.SetScanProjectSkills(scanProjects.IsChecked == true);
        healthStack.Children.Add(scanProjects);
        health.Child = healthStack;
        Grid.SetColumn(health, 2);
        OverviewSplit.Children.Add(health);

        OverviewMap.Nodes = _store.ClusterNodesForMap;
        OverviewMap.NucleusTitle = _store.ClusterTitle;
        OverviewMap.NucleusCount = _store.ClusterItemCount;
    }

    void AddStat(string title, int value)
    {
        var card = new Border { Classes = { "card" }, Margin = new Thickness(0, 0, 8, 0) };
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock { Text = title, Classes = { "caption" } });
        stack.Children.Add(new TextBlock { Text = value.ToString(), FontSize = 26, FontWeight = FontWeight.SemiBold });
        card.Child = stack;
        StatsGrid.Children.Add(card);
    }

    void RebuildPreview(DocumentRef document)
    {
        PreviewPanel.Children.Clear();
        var blocks = MarkdownParser.SkippingRedundantTitle(MarkdownParser.Blocks(_store.DraftText), document.Title);
        foreach (var block in blocks)
        {
            PreviewPanel.Children.Add(RenderBlock(block));
        }

        if (PreviewPanel.Children.Count == 0)
        {
            PreviewPanel.Children.Add(new TextBlock { Text = "这份文件还是空的。", Classes = { "muted" } });
        }
    }

    static Control RenderBlock(MarkdownBlock block) => block switch
    {
        MarkdownBlock.Heading h => new TextBlock
        {
            Text = h.Text,
            FontSize = h.Level == 1 ? 26 : h.Level == 2 ? 20 : 16,
            FontWeight = FontWeight.SemiBold,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, h.Level == 1 ? 8 : 4, 0, 2)
        },
        MarkdownBlock.Paragraph p => new TextBlock { Text = p.Text, TextWrapping = TextWrapping.Wrap },
        MarkdownBlock.Bullets b => BulletList(b.Items, false),
        MarkdownBlock.Numbered n => BulletList(n.Items, true),
        MarkdownBlock.Code c => new Border
        {
            Classes = { "card" },
            Child = new TextBlock
            {
                Text = c.Text,
                FontFamily = new FontFamily("Cascadia Mono, Consolas, Menlo, monospace"),
                TextWrapping = TextWrapping.Wrap
            }
        },
        MarkdownBlock.Quote q => new Border
        {
            BorderBrush = Brushes.Gray,
            BorderThickness = new Thickness(3, 0, 0, 0),
            Padding = new Thickness(10, 0, 0, 0),
            Child = new TextBlock { Text = q.Text, FontStyle = FontStyle.Italic, TextWrapping = TextWrapping.Wrap }
        },
        MarkdownBlock.Rule => new Separator(),
        MarkdownBlock.Table t => RenderTable(t),
        _ => new TextBlock()
    };

    static Control BulletList(IReadOnlyList<string> items, bool numbered)
    {
        var stack = new StackPanel { Spacing = 3 };
        for (var i = 0; i < items.Count; i++)
        {
            stack.Children.Add(new TextBlock
            {
                Text = numbered ? $"{i + 1}. {items[i]}" : $"• {items[i]}",
                TextWrapping = TextWrapping.Wrap
            });
        }

        return stack;
    }

    static Control RenderTable(MarkdownBlock.Table table)
    {
        var grid = new Grid();
        for (var c = 0; c < table.Header.Count; c++)
        {
            grid.ColumnDefinitions.Add(new ColumnDefinition(GridLength.Star));
        }

        grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        for (var r = 0; r < table.Rows.Count; r++)
        {
            grid.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        }

        for (var c = 0; c < table.Header.Count; c++)
        {
            var cell = new TextBlock { Text = table.Header[c], FontWeight = FontWeight.SemiBold, Margin = new Thickness(6) };
            Grid.SetColumn(cell, c);
            grid.Children.Add(cell);
        }

        for (var r = 0; r < table.Rows.Count; r++)
        {
            for (var c = 0; c < table.Rows[r].Count && c < table.Header.Count; c++)
            {
                var cell = new TextBlock { Text = table.Rows[r][c], Margin = new Thickness(6) };
                Grid.SetRow(cell, r + 1);
                Grid.SetColumn(cell, c);
                grid.Children.Add(cell);
            }
        }

        return new Border { Classes = { "card" }, Child = grid, Padding = new Thickness(4) };
    }

    void OnDocumentModeChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (DocumentModeBox.SelectedIndex == 1)
        {
            _store.DocumentMode = DocumentMode.Edit;
        }
        else if (DocumentModeBox.SelectedIndex == 0)
        {
            _store.DocumentMode = DocumentMode.Preview;
        }
    }

    void RefreshInspector()
    {
        InspectorPanel.Children.Clear();
        if (_store.CurrentDocument is DocumentRef.Skill skillRef)
        {
            BuildSkillInspector(skillRef.Item);
        }
        else if (_store.CurrentDocument is DocumentRef.Prompt promptRef)
        {
            BuildPromptInspector(promptRef.Item);
        }
        else if (_store.SidebarSelection is SidebarItem.Overview)
        {
            InspectorPanel.Children.Add(new TextBlock { Text = "总览", FontSize = 18, FontWeight = FontWeight.SemiBold });
            InspectorPanel.Children.Add(new TextBlock
            {
                Text = "点中间列表或气泡图里的一项，这里会显示路径、安装位置和操作。",
                Classes = { "muted" },
                TextWrapping = TextWrapping.Wrap
            });
        }
        else
        {
            InspectorPanel.Children.Add(new TextBlock { Text = "未选择", FontSize = 18, FontWeight = FontWeight.SemiBold });
            InspectorPanel.Children.Add(new TextBlock
            {
                Text = "从中间列表选一个 skill 或 prompt。",
                Classes = { "muted" }
            });
        }
    }

    void BuildSkillInspector(SkillItem skill)
    {
        var document = new DocumentRef.Skill(skill);
        InspectorPanel.Children.Add(InspectorHeader(skill.Name, string.IsNullOrEmpty(skill.Description) ? "还没有 description" : skill.Description, skill.ToolSources, _store.IsStarredSkill(skill.Id), () => _store.ToggleStar(document)));
        InspectorPanel.Children.Add(Section("位置",
            PathRow("SKILL.md", skill.SkillFilePath),
            Labeled("文件", $"{skill.FileCount} 个"),
            Labeled("修改时间", skill.ModifiedAt.ToString("yyyy-MM-dd HH:mm"))));

        var installs = new StackPanel { Spacing = 8 };
        foreach (var entry in skill.Installations)
        {
            var row = new DockPanel();
            if (entry.Source.IsWritable())
            {
                var remove = new Button { Content = "移除", Margin = new Thickness(8, 0, 0, 0) };
                var captured = entry;
                remove.Click += (_, _) => _store.Request(new ConfirmAction.RemoveInstall(skill.Id, captured.Path, captured.IsSymlink));
                DockPanel.SetDock(remove, Dock.Right);
                row.Children.Add(remove);
            }

            var label = new StackPanel();
            label.Children.Add(new TextBlock { Text = $"{entry.Source.Title()}{(entry.IsSymlink ? " · 链接" : "")}{(entry.IsBroken ? " · 损坏" : "")}" });
            label.Children.Add(new TextBlock { Text = entry.Path, Classes = { "caption" }, TextWrapping = TextWrapping.Wrap });
            row.Children.Add(label);
            installs.Children.Add(row);
        }

        InspectorPanel.Children.Add(Section("安装位置", installs));
        if (skill.Health.Count > 0)
        {
            InspectorPanel.Children.Add(Section("健康", skill.Health.Select(issue =>
                new TextBlock { Text = "⚠ " + issue.Title(), Foreground = Brushes.Orange }).Cast<Control>().ToArray()));
        }

        AddMetaSections(document);
        var actions = new StackPanel { Spacing = 6 };
        var installButton = new Button { Content = "安装到其他工具…" };
        installButton.IsEnabled = !skill.IsReadOnly && _store.AvailableInstallTargets(skill).Count > 0;
        installButton.Click += (_, _) => OpenSheet(HubSheet.Install);
        actions.Children.Add(installButton);
        if (_store.DuplicateSkills.Count > 0)
        {
            var dedupe = new Button { Content = $"一键去重 {_store.DuplicateSkills.Count} 个…" };
            dedupe.Click += (_, _) => OpenSheet(HubSheet.Dedupe);
            actions.Children.Add(dedupe);
        }

        var reveal = new Button { Content = "在资源管理器中显示" };
        reveal.Click += (_, _) => _store.Reveal(document);
        actions.Children.Add(reveal);
        var archive = new Button { Content = "归档…" };
        archive.IsEnabled = !skill.IsReadOnly;
        archive.Click += (_, _) => _store.RequestArchive(document);
        actions.Children.Add(archive);
        var delete = new Button { Content = "删除实体…" };
        delete.IsEnabled = !skill.IsReadOnly;
        delete.Click += (_, _) => _store.RequestDelete(document);
        actions.Children.Add(delete);
        InspectorPanel.Children.Add(Section("操作", actions));

        var related = _store.RelatedSkills(skill);
        if (related.Count > 0)
        {
            var stack = new StackPanel { Spacing = 4 };
            foreach (var other in related)
            {
                var button = new Button { Content = other.Name };
                button.Click += (_, _) => _store.Select(new DocumentRef.Skill(other));
                stack.Children.Add(button);
            }

            InspectorPanel.Children.Add(Section("相关", stack));
        }
    }

    void BuildPromptInspector(PromptItem prompt)
    {
        var document = new DocumentRef.Prompt(prompt);
        InspectorPanel.Children.Add(InspectorHeader(prompt.Title, prompt.ParentSkillName ?? prompt.Source.Title(), [prompt.Source], _store.IsStarredPrompt(prompt.Id), () => _store.ToggleStar(document)));
        InspectorPanel.Children.Add(Section("位置", PathRow("文件", prompt.CanonicalPath)));
        AddMetaSections(document);
        var actions = new StackPanel { Spacing = 6 };
        if (prompt.Kind == PromptKind.Embedded)
        {
            var save = new Button { Content = "另存到独立库" };
            save.Click += (_, _) => _store.SavePromptAsStandalone(prompt);
            actions.Children.Add(save);
        }

        var reveal = new Button { Content = "在资源管理器中显示" };
        reveal.Click += (_, _) => _store.Reveal(document);
        actions.Children.Add(reveal);
        var archive = new Button { Content = "归档…" };
        archive.IsEnabled = !prompt.IsReadOnly;
        archive.Click += (_, _) => _store.RequestArchive(document);
        actions.Children.Add(archive);
        var delete = new Button { Content = "删除…" };
        delete.IsEnabled = !prompt.IsReadOnly;
        delete.Click += (_, _) => _store.RequestDelete(document);
        actions.Children.Add(delete);
        InspectorPanel.Children.Add(Section("操作", actions));
    }

    void AddMetaSections(DocumentRef document)
    {
        var meta = _store.ItemMetaFor(document);
        var tagBox = new TextBox { Text = string.Join(", ", meta.Tags), Watermark = "标签，逗号分隔" };
        tagBox.LostFocus += (_, _) =>
            _store.SetTags((tagBox.Text ?? "").Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries), document);
        var notes = new TextBox { Text = meta.Notes, AcceptsReturn = true, Height = 80, Watermark = "备注只存在 Skill Hub 里" };
        notes.LostFocus += (_, _) => _store.SetNotes(notes.Text ?? "", document);
        InspectorPanel.Children.Add(Section("标签与备注", tagBox, notes, new TextBlock
        {
            Text = meta.OpenCount > 0 ? $"打开 {meta.OpenCount} 次" : "还没打开过",
            Classes = { "caption" }
        }));
    }

    Control InspectorHeader(string title, string subtitle, IReadOnlyList<ToolSource> sources, bool starred, Action toggle)
    {
        var star = new Button { Content = starred ? "★ 已收藏" : "☆ 收藏" };
        star.Click += (_, _) => toggle();
        var badges = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6, Margin = new Thickness(0, 6, 0, 0) };
        foreach (var source in sources)
        {
            badges.Children.Add(Badge(source.Title(), ColorUtil.Tool(source), ColorUtil.Soft(source)));
        }

        var stack = new StackPanel { Spacing = 4 };
        stack.Children.Add(new TextBlock { Text = title, FontSize = 18, FontWeight = FontWeight.SemiBold, TextWrapping = TextWrapping.Wrap });
        stack.Children.Add(new TextBlock { Text = subtitle, Classes = { "muted" }, TextWrapping = TextWrapping.Wrap });
        stack.Children.Add(badges);
        stack.Children.Add(star);
        return stack;
    }

    static Control Section(string title, params Control[] children)
    {
        var stack = new StackPanel { Spacing = 8 };
        stack.Children.Add(new TextBlock { Text = title, FontWeight = FontWeight.SemiBold });
        foreach (var child in children)
        {
            stack.Children.Add(child);
        }

        return new Border { Classes = { "card" }, Child = stack };
    }

    static Control PathRow(string label, string path)
    {
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock { Text = label, Classes = { "caption" } });
        stack.Children.Add(new TextBlock { Text = path, TextWrapping = TextWrapping.Wrap });
        return stack;
    }

    static Control Labeled(string label, string value)
    {
        var row = new DockPanel();
        var right = new TextBlock { Text = value, Classes = { "caption" } };
        DockPanel.SetDock(right, Dock.Right);
        row.Children.Add(right);
        row.Children.Add(new TextBlock { Text = label });
        return row;
    }

    static Border Badge(string text, IBrush foreground, IBrush background) =>
        new()
        {
            Classes = { "badge" },
            Background = background,
            Child = new TextBlock { Text = text, Foreground = foreground, FontSize = 11, FontWeight = FontWeight.Medium }
        };

    async void OpenSheet(HubSheet sheet)
    {
        Window dialog = sheet switch
        {
            HubSheet.NewSkill => new NewSkillWindow(_store),
            HubSheet.NewPrompt => new NewPromptWindow(_store),
            HubSheet.Install => new InstallWindow(_store),
            HubSheet.Dedupe => new DedupeWindow(_store),
            _ => throw new ArgumentOutOfRangeException(nameof(sheet))
        };
        await dialog.ShowDialog(this);
        RefreshAll();
    }

    async Task ShowErrorAsync()
    {
        var window = new Window
        {
            Title = "出错了",
            Width = 420,
            Height = 180,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = new DockPanel
            {
                Margin = new Thickness(20),
                Children =
                {
                    ButtonBar("好", () => { }),
                    new TextBlock { Text = _store.ErrorMessage ?? "", TextWrapping = TextWrapping.Wrap }
                }
            }
        };
        ((Button)((DockPanel)window.Content!).Children[0]).Click += (_, _) => window.Close();
        await window.ShowDialog(this);
        _store.DismissError();
    }

    async Task ShowConfirmAsync(ConfirmAction action)
    {
        var confirm = new Button { Content = action.ConfirmTitle };
        var cancel = new Button { Content = "取消", Margin = new Thickness(8, 0, 0, 0) };
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8 };
        DockPanel.SetDock(buttons, Dock.Bottom);
        buttons.Children.Add(cancel);
        buttons.Children.Add(confirm);
        var window = new Window
        {
            Title = action.Title,
            Width = 460,
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = new DockPanel
            {
                Margin = new Thickness(20),
                Children =
                {
                    buttons,
                    new TextBlock { Text = action.Message, TextWrapping = TextWrapping.Wrap }
                }
            }
        };
        confirm.Click += (_, _) =>
        {
            _store.Perform(action);
            window.Close();
        };
        cancel.Click += (_, _) =>
        {
            _store.CancelConfirm();
            window.Close();
        };
        await window.ShowDialog(this);
    }

    static Button ButtonBar(string title, Action action)
    {
        var button = new Button { Content = title, HorizontalAlignment = HorizontalAlignment.Right };
        DockPanel.SetDock(button, Dock.Bottom);
        button.Click += (_, _) => action();
        return button;
    }
}
