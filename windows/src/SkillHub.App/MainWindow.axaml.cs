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
    bool _syncingMode;

    public MainWindow()
        : this(new CatalogStore(new HubPaths(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile))))
    {
    }

    public MainWindow(CatalogStore store)
    {
        _store = store;
        InitializeComponent();
        KeyDown += OnKeyDown;
        NewSkillItem.Click += (_, _) => OpenSheet(HubSheet.NewSkill);
        NewPromptItem.Click += (_, _) => OpenSheet(HubSheet.NewPrompt);
        RefreshButton.Click += (_, _) => _store.Refresh();
        InspectorToggle.Click += (_, _) =>
        {
            _inspectorVisible = !_inspectorVisible;
            InspectorHost.IsVisible = _inspectorVisible;
            InspectorSplitter.IsVisible = _inspectorVisible;
        };
        BackButton.Click += (_, _) => _store.PopCluster();
        PreviewButton.IsCheckedChanged += (_, _) =>
        {
            if (_syncingMode || PreviewButton.IsChecked != true)
            {
                return;
            }

            _store.DocumentMode = DocumentMode.Preview;
        };
        EditButton.IsCheckedChanged += (_, _) =>
        {
            if (_syncingMode || EditButton.IsChecked != true)
            {
                return;
            }

            _store.DocumentMode = DocumentMode.Edit;
        };
        SaveButton.Click += (_, _) => _store.SaveDraft();
        MapButton.Click += (_, _) => _store.ShowClusterMap();
        DiscardButton.Click += (_, _) => _store.DiscardDraft();
        SearchBox.TextChanged += (_, _) => _store.SearchText = SearchBox.Text ?? "";
        SidebarList.SelectionChanged += OnSidebarChanged;
        BrowseList.SelectionChanged += OnBrowseChanged;
        EditorBox.TextChanged += (_, _) =>
        {
            if (EditorHost.IsVisible)
            {
                _store.DraftText = EditorBox.Text ?? "";
                RefreshEditorChrome();
            }
        };
        OverviewMap.NodeActivated += _store.Open;
        OverviewMap.NucleusActivated += OnNucleus;
        DetailMap.NodeActivated += _store.Open;
        DetailMap.NucleusActivated += OnNucleus;

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

    void OnNucleus()
    {
        if (_store.ClusterPrefix != null)
        {
            _store.PopCluster();
        }
        else
        {
            _store.ReplayMap();
        }
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

        if (name is nameof(CatalogStore.DraftText) or nameof(CatalogStore.IsDirty) or nameof(CatalogStore.LoadedText))
        {
            RefreshEditorChrome();
            return;
        }

        RefreshAll();
    }

    void RefreshAll()
    {
        FooterLabel.Text = _store.IsScanning
            ? "正在扫描…"
            : $"{_store.Stats.UniqueSkills} skills · {_store.Stats.UniquePrompts} prompts";
        RefreshButton.IsEnabled = !_store.IsScanning;
        RefreshSidebarCounts();
        RefreshBrowse();
        RefreshDetail();
        RefreshInspector();
    }

    void RefreshEditorChrome()
    {
        SaveButton.IsVisible = _store.CurrentDocument != null && _store.DocumentMode == DocumentMode.Edit;
        SaveButton.IsEnabled = _store.IsDirty;
        DiscardButton.IsVisible = _store.IsDirty;
        EditorStatus.Text = _store.IsDirty ? "有未保存的修改" : "已保存";
        EditorStatus.Foreground = _store.IsDirty ? Brushes.Orange : null;
    }

    void BuildSidebar()
    {
        _sidebarItems.Clear();
        SidebarList.Items.Clear();
        AddSidebar(SidebarItem.OverviewItem, "总览", "pie");
        AddHeader("Skills");
        AddSidebar(new SidebarItem.Skills(BrowseFilter.AllFilter), "全部", "grid");
        AddSidebar(new SidebarItem.Skills(BrowseFilter.StarredFilter), "收藏", "star");
        AddSidebar(new SidebarItem.Skills(BrowseFilter.DuplicatesFilter), "重复安装", "dup");
        AddSidebar(new SidebarItem.Skills(BrowseFilter.HealthFilter), "健康问题", "health");
        AddHeader("Prompts");
        AddSidebar(new SidebarItem.Prompts(BrowseFilter.AllFilter), "全部", "grid");
        AddSidebar(new SidebarItem.Prompts(BrowseFilter.StarredFilter), "收藏", "star");
        AddSidebar(new SidebarItem.Prompts(BrowseFilter.StandaloneFilter), "独立文件", "doc");
        AddSidebar(new SidebarItem.Prompts(BrowseFilter.EmbeddedFilter), "Skill 内嵌", "docs");
        AddHeader("按工具");
        AddSidebar(new SidebarItem.Skills(new BrowseFilter.Tool(ToolSource.CursorUser)), "Cursor", "cursor");
        AddSidebar(new SidebarItem.Skills(new BrowseFilter.Tool(ToolSource.CursorBuiltin)), "Cursor 内置", "cursor");
        AddSidebar(new SidebarItem.Skills(new BrowseFilter.Tool(ToolSource.Claude)), "Claude", "spark");
        AddSidebar(new SidebarItem.Skills(new BrowseFilter.Tool(ToolSource.Codex)), "Codex", "code");
        AddSidebar(new SidebarItem.Skills(new BrowseFilter.Tool(ToolSource.Agents)), "Agents", "people");
        AddSidebar(new SidebarItem.Skills(new BrowseFilter.Tool(ToolSource.Proma)), "Proma", "wand");
        AddSidebar(new SidebarItem.Prompts(new BrowseFilter.Tool(ToolSource.PromptLibrary)), "Skill Hub 库", "books");
        AddSidebar(new SidebarItem.Prompts(new BrowseFilter.Tool(ToolSource.CodexPrompts)), "Codex Prompts", "quote");

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
            Padding = new Thickness(0),
            Content = new TextBlock
            {
                Text = title,
                Classes = { "section" },
                Margin = new Thickness(10, 14, 8, 4)
            }
        });
        _sidebarItems.Add(SidebarItem.OverviewItem);
    }

    void AddSidebar(SidebarItem item, string title, string icon)
    {
        _sidebarItems.Add(item);
        var row = new DockPanel { Margin = new Thickness(8, 5) };
        var count = new TextBlock
        {
            Name = "Count",
            Classes = { "caption" },
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(8, 0, 0, 0)
        };
        DockPanel.SetDock(count, Dock.Right);
        row.Children.Add(count);
        var label = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        label.Children.Add(Glyph.Make(icon, 13));
        label.Children.Add(new TextBlock { Text = title, VerticalAlignment = VerticalAlignment.Center });
        row.Children.Add(label);
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
            if (count == null)
            {
                continue;
            }

            count.Text = item.IsOverview ? "" : _store.CountFor(item).ToString();
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

        var rows = _store.RankedClusterRows;
        var noun = _store.SidebarSelection?.IsOverview == true
            ? "条目"
            : _store.SidebarSelection?.IsPrompts == true
                ? "prompt"
                : "skill";
        foreach (var row in rows)
        {
            BrowseList.Items.Add(MakeClusterRow(row));
        }

        var empty = rows.Count == 0;
        BrowseEmpty.IsVisible = empty;
        BrowseList.IsVisible = !empty;
        if (_store.IsSearching)
        {
            BrowseEmptyTitle.Text = "没有匹配的结果";
            BrowseEmptyBody.Text = $"找不到「{_store.SearchText}」。";
        }
        else if (_store.ClusterPrefix != null)
        {
            BrowseEmptyTitle.Text = "这一类是空的";
            BrowseEmptyBody.Text = "返回上一层，或换一个分类。";
        }
        else
        {
            BrowseEmptyTitle.Text = $"还没有 {noun}";
            BrowseEmptyBody.Text = "用工具栏里的「新建」创建一个，或者换一个筛选条件。";
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
        var root = ToolbarText(_store.SidebarSelection?.Title ?? "全部");
        root.Click += (_, _) => _store.ResetClusters();
        BreadcrumbBar.Items.Add(root);
        for (var i = 0; i < _store.ClusterPath.Count; i++)
        {
            BreadcrumbBar.Items.Add(new TextBlock
            {
                Text = "›",
                Classes = { "tertiary" },
                VerticalAlignment = VerticalAlignment.Center
            });
            var prefix = string.Join('-', _store.ClusterPath.Take(i + 1));
            var button = ToolbarText(_store.ClusterPath[i]);
            button.Click += (_, _) => _store.OpenCluster(prefix);
            BreadcrumbBar.Items.Add(button);
        }
    }

    static Button ToolbarText(string text)
    {
        var button = new Button { Content = text, Classes = { "toolbar" } };
        return button;
    }

    ListBoxItem MakeSkillRow(SkillItem skill)
    {
        var block = new StackPanel { Spacing = 4, Margin = new Thickness(10, 7) };
        var title = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        title.Children.Add(new TextBlock { Text = skill.Name, FontWeight = FontWeight.SemiBold, FontSize = 13 });
        if (_store.IsStarredSkill(skill.Id))
        {
            title.Children.Add(Glyph.Make("star", 11, Brushes.Gold));
        }

        if (skill.Health.Count > 0)
        {
            title.Children.Add(Glyph.Make("warning", 11, Brushes.Orange));
        }

        block.Children.Add(title);
        block.Children.Add(new TextBlock
        {
            Text = string.IsNullOrEmpty(skill.Description) ? "还没有 description" : skill.Description,
            Classes = { "caption" },
            TextWrapping = TextWrapping.Wrap,
            MaxLines = 2
        });
        var badges = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4 };
        foreach (var source in skill.ToolSources)
        {
            badges.Children.Add(Badge(source.Title(), ColorUtil.Tool(source), ColorUtil.Soft(source)));
        }

        if (skill.IsDuplicateInstall)
        {
            badges.Children.Add(new TextBlock { Text = $"{skill.Installations.Count} 处", Classes = { "tertiary" }, VerticalAlignment = VerticalAlignment.Center });
        }

        block.Children.Add(badges);
        return new ListBoxItem { Content = block, Tag = skill };
    }

    ListBoxItem MakePromptRow(PromptItem prompt)
    {
        var block = new StackPanel { Spacing = 4, Margin = new Thickness(10, 7) };
        var title = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        title.Children.Add(new TextBlock { Text = prompt.Title, FontWeight = FontWeight.SemiBold, FontSize = 13 });
        if (_store.IsStarredPrompt(prompt.Id))
        {
            title.Children.Add(Glyph.Make("star", 11, Brushes.Gold));
        }

        block.Children.Add(title);
        var meta = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        meta.Children.Add(Badge(prompt.Kind.Title(), ColorUtil.Tool(prompt.Source), ColorUtil.Soft(prompt.Source)));
        meta.Children.Add(new TextBlock
        {
            Text = prompt.ParentSkillName ?? prompt.Source.Title(),
            Classes = { "caption" },
            VerticalAlignment = VerticalAlignment.Center
        });
        block.Children.Add(meta);
        return new ListBoxItem { Content = block, Tag = prompt };
    }

    ListBoxItem MakeClusterRow(ClusterRankedRow row)
    {
        var tint = ColorUtil.Cluster(row.Node.Title);
        var head = new DockPanel();
        if (row.Node.IsGroup)
        {
            var trail = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
            trail.Children.Add(new TextBlock { Text = row.Node.Count.ToString(), Classes = { "caption" }, VerticalAlignment = VerticalAlignment.Center });
            trail.Children.Add(Glyph.Make("chevronRight", 10));
            DockPanel.SetDock(trail, Dock.Right);
            head.Children.Add(trail);
        }

        var label = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        label.Children.Add(Glyph.Make(row.Node.IsGroup ? "folder" : "doc", 13, tint));
        label.Children.Add(new TextBlock { Text = row.Node.Title, FontWeight = FontWeight.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        head.Children.Add(label);

        var bar = new Border
        {
            Height = 3,
            CornerRadius = new CornerRadius(1.5),
            Background = ColorUtil.ClusterSoft(row.Node.Title),
            Width = 48 + row.Fraction * 160,
            HorizontalAlignment = HorizontalAlignment.Left
        };

        var block = new StackPanel { Margin = new Thickness(10, 7), Spacing = 6 };
        block.Children.Add(head);
        block.Children.Add(bar);
        block.Children.Add(new TextBlock { Text = _store.Caption(row.Node), Classes = { "caption" } });
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
        var showDocument = document != null;
        OverviewHost.IsVisible = overview && !showDocument;
        SegmentHost.IsVisible = showDocument;
        SegmentHost.IsEnabled = document is not { IsReadOnly: true };
        SaveButton.IsVisible = showDocument && _store.DocumentMode == DocumentMode.Edit;
        SaveButton.IsEnabled = _store.IsDirty;
        PreviewHost.IsVisible = showDocument && _store.DocumentMode == DocumentMode.Preview;
        EditorHost.IsVisible = showDocument && _store.DocumentMode == DocumentMode.Edit;
        DetailMap.IsVisible = !showDocument && !overview;
        MapButton.IsVisible = showDocument;
        BackButton.IsVisible = !showDocument && _store.ClusterPrefix != null;
        DetailTitle.Text = document?.Title ?? _store.SidebarSelection?.Title ?? "Skill Hub";

        _syncingMode = true;
        PreviewButton.IsChecked = _store.DocumentMode == DocumentMode.Preview;
        EditButton.IsChecked = _store.DocumentMode == DocumentMode.Edit;
        _syncingMode = false;

        if (showDocument && _store.DocumentMode == DocumentMode.Preview)
        {
            RebuildPreview(document!);
        }
        else if (showDocument && _store.DocumentMode == DocumentMode.Edit)
        {
            if (EditorBox.Text != _store.DraftText)
            {
                EditorBox.Text = _store.DraftText;
            }

            RefreshEditorChrome();
        }
        else if (overview)
        {
            RebuildOverview();
        }
        else
        {
            DetailMap.Nodes = _store.ClusterNodesForMap;
            DetailMap.NucleusTitle = _store.ClusterTitle;
            DetailMap.NucleusCount = _store.ClusterItemCount;
            DetailMap.CanGoUp = _store.ClusterPrefix != null;
        }
    }

    void RebuildOverview()
    {
        StatsGrid.Children.Clear();
        AddStat("Skills", _store.Stats.UniqueSkills, "docs");
        AddStat("Prompts", _store.Stats.UniquePrompts, "quote");
        AddStat("重复安装", _store.Stats.DuplicateSkills, "dup");
        AddStat("符号链接", _store.Stats.SymlinkInstalls, "link");

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
            var label = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            label.Children.Add(Glyph.Make(source switch
            {
                ToolSource.CursorUser or ToolSource.CursorBuiltin => "cursor",
                ToolSource.Claude => "spark",
                ToolSource.Codex => "code",
                ToolSource.Agents => "people",
                ToolSource.Proma => "wand",
                _ => "folder"
            }, 12, ColorUtil.Tool(source)));
            label.Children.Add(new TextBlock { Text = source.Title() });
            row.Children.Add(label);
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
            var dedupe = new Button { Content = $"一键去重 {_store.DuplicateSkills.Count} 个…", Classes = { "action" } };
            dedupe.Click += (_, _) => OpenSheet(HubSheet.Dedupe);
            healthStack.Children.Add(dedupe);
        }

        var scanProjects = new CheckBox
        {
            Content = OperatingSystem.IsWindows()
                ? @"同时扫描 %USERPROFILE%\Projects 里各项目的 skill"
                : "同时扫描 ~/Projects 里各项目的 skill",
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
        OverviewMap.CanGoUp = _store.ClusterPrefix != null;
    }

    void AddStat(string title, int value, string icon)
    {
        var card = new Border { Classes = { "card" }, Margin = new Thickness(0, 0, 10, 0) };
        var stack = new StackPanel { Spacing = 6 };
        var label = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        label.Children.Add(Glyph.Make(icon, 12));
        label.Children.Add(new TextBlock { Text = title, Classes = { "caption" } });
        stack.Children.Add(label);
        stack.Children.Add(new TextBlock { Text = value.ToString(), FontSize = 28, FontWeight = FontWeight.SemiBold });
        card.Child = stack;
        StatsGrid.Children.Add(card);
    }

    void RebuildPreview(DocumentRef document)
    {
        PreviewPanel.Children.Clear();
        var header = new StackPanel { Spacing = 8 };
        var titleRow = new DockPanel();
        titleRow.Children.Add(Badge(document.PrimarySource.Title(), ColorUtil.Tool(document.PrimarySource), ColorUtil.Soft(document.PrimarySource)));
        DockPanel.SetDock(titleRow.Children[0], Dock.Right);
        titleRow.Children.Add(new TextBlock
        {
            Text = document.Title,
            FontSize = 28,
            FontWeight = FontWeight.Bold,
            TextWrapping = TextWrapping.Wrap
        });
        header.Children.Add(titleRow);
        if (!string.IsNullOrEmpty(document.Subtitle))
        {
            header.Children.Add(new TextBlock
            {
                Text = document.Subtitle,
                FontSize = 17,
                Classes = { "muted" },
                TextWrapping = TextWrapping.Wrap
            });
        }

        PreviewPanel.Children.Add(header);
        PreviewPanel.Children.Add(new Separator());

        var blocks = MarkdownParser.SkippingRedundantTitle(MarkdownParser.Blocks(_store.DraftText), document.Title);
        foreach (var block in blocks)
        {
            PreviewPanel.Children.Add(RenderBlock(block));
        }

        if (blocks.Count == 0)
        {
            PreviewPanel.Children.Add(new TextBlock { Text = "这个文件是空的。切换到「编辑」开始写。", Classes = { "muted" } });
        }
    }

    static Control RenderBlock(MarkdownBlock block) => block switch
    {
        MarkdownBlock.Heading h => new TextBlock
        {
            Text = h.Text,
            FontSize = h.Level == 1 ? 24 : h.Level == 2 ? 19 : 15,
            FontWeight = FontWeight.SemiBold,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, h.Level == 1 ? 6 : 2, 0, 0)
        },
        MarkdownBlock.Paragraph p => new TextBlock { Text = p.Text, TextWrapping = TextWrapping.Wrap, LineHeight = 22 },
        MarkdownBlock.Bullets b => BulletList(b.Items, false),
        MarkdownBlock.Numbered n => BulletList(n.Items, true),
        MarkdownBlock.Code c => new Border
        {
            Classes = { "card" },
            Child = new SelectableTextBlock
            {
                Text = c.Text,
                FontFamily = new FontFamily("SF Mono, Cascadia Mono, Menlo, Consolas, monospace"),
                TextWrapping = TextWrapping.Wrap
            }
        },
        MarkdownBlock.Quote q => new Border
        {
            BorderBrush = new SolidColorBrush(Color.Parse("#8E8E93")),
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
        var stack = new StackPanel { Spacing = 4 };
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
                var cell = new TextBlock { Text = table.Rows[r][c], Margin = new Thickness(6), TextWrapping = TextWrapping.Wrap };
                Grid.SetRow(cell, r + 1);
                Grid.SetColumn(cell, c);
                grid.Children.Add(cell);
            }
        }

        return new Border { Classes = { "card" }, Child = grid, Padding = new Thickness(4) };
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
        else
        {
            BuildClusterInspector();
        }
    }

    void BuildClusterInspector()
    {
        InspectorPanel.Children.Add(FormSection("浏览",
            Labeled("当前范围", _store.SidebarSelection?.Title ?? "Skills"),
            _store.ClusterPrefix == null ? new TextBlock() : Labeled("聚类前缀", _store.ClusterPrefix),
            Labeled("条目", _store.ClusterItemCount.ToString()),
            new TextBlock
            {
                Text = "气泡大小按使用频率：agent 调用次数、收藏、装到几个工具。同名前缀会合并成一类，点开可以继续往下。",
                Classes = { "caption" },
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 4, 0, 0)
            }));

        if (_store.DuplicateSkills.Count > 0)
        {
            var dedupe = new Button { Content = $"一键去重 {_store.DuplicateSkills.Count} 个…", Classes = { "action" } };
            dedupe.Click += (_, _) => OpenSheet(HubSheet.Dedupe);
            InspectorPanel.Children.Add(FormSection("整理", dedupe));
        }

        if (_store.ClusterPrefix != null)
        {
            var back = new Button { Content = "返回上一层", Classes = { "action" } };
            back.Click += (_, _) => _store.PopCluster();
            var top = new Button { Content = "回到顶层", Classes = { "action" } };
            top.Click += (_, _) => _store.ResetClusters();
            InspectorPanel.Children.Add(FormSection("导航", back, top));
        }
    }

    void BuildSkillInspector(SkillItem skill)
    {
        var document = new DocumentRef.Skill(skill);
        InspectorPanel.Children.Add(FormSection(null, InspectorHeader(skill.Name, string.IsNullOrEmpty(skill.Description) ? "还没有 description" : skill.Description, skill.ToolSources, _store.IsStarredSkill(skill.Id), () => _store.ToggleStar(document))));
        InspectorPanel.Children.Add(FormSection("位置",
            PathRow("SKILL.md", skill.SkillFilePath),
            Labeled("文件", $"{skill.FileCount} 个"),
            Labeled("修改时间", skill.ModifiedAt.ToString("yyyy-MM-dd HH:mm"))));

        var installs = new StackPanel { Spacing = 8 };
        foreach (var entry in skill.Installations)
        {
            var row = new DockPanel();
            if (entry.Source.IsWritable())
            {
                var remove = new Button { Content = "移除", Classes = { "link" }, Margin = new Thickness(8, 0, 0, 0) };
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

        InspectorPanel.Children.Add(FormSection("安装位置", installs));
        if (skill.Health.Count > 0)
        {
            InspectorPanel.Children.Add(FormSection("健康", skill.Health.Select(issue =>
                (Control)new TextBlock { Text = issue.Title(), Foreground = Brushes.Orange }).ToArray()));
        }

        AddMetaSections(document);
        var actions = new StackPanel { Spacing = 2 };
        actions.Children.Add(ActionButton("安装到其他工具…", () => OpenSheet(HubSheet.Install), !skill.IsReadOnly && _store.AvailableInstallTargets(skill).Count > 0));
        if (_store.DuplicateSkills.Count > 0)
        {
            actions.Children.Add(ActionButton($"一键去重 {_store.DuplicateSkills.Count} 个…", () => OpenSheet(HubSheet.Dedupe)));
        }

        actions.Children.Add(ActionButton("在资源管理器中显示", () => _store.Reveal(document)));
        actions.Children.Add(ActionButton("归档…", () => _store.RequestArchive(document), !skill.IsReadOnly));
        var delete = new Button { Content = "删除实体…", Classes = { "destructive" }, IsEnabled = !skill.IsReadOnly };
        delete.Click += (_, _) => _store.RequestDelete(document);
        actions.Children.Add(delete);
        InspectorPanel.Children.Add(FormSection("操作", actions));

        var related = _store.RelatedSkills(skill);
        if (related.Count > 0)
        {
            var stack = new StackPanel { Spacing = 2 };
            foreach (var other in related)
            {
                stack.Children.Add(ActionButton(other.Name, () => _store.Select(new DocumentRef.Skill(other))));
            }

            InspectorPanel.Children.Add(FormSection("相关", stack));
        }
    }

    void BuildPromptInspector(PromptItem prompt)
    {
        var document = new DocumentRef.Prompt(prompt);
        InspectorPanel.Children.Add(FormSection(null, InspectorHeader(prompt.Title, prompt.ParentSkillName ?? prompt.Source.Title(), [prompt.Source], _store.IsStarredPrompt(prompt.Id), () => _store.ToggleStar(document))));
        InspectorPanel.Children.Add(FormSection("位置", PathRow("文件", prompt.CanonicalPath)));
        AddMetaSections(document);
        var actions = new StackPanel { Spacing = 2 };
        if (prompt.Kind == PromptKind.Embedded)
        {
            actions.Children.Add(ActionButton("另存到独立库", () => _store.SavePromptAsStandalone(prompt)));
        }

        actions.Children.Add(ActionButton("在资源管理器中显示", () => _store.Reveal(document)));
        actions.Children.Add(ActionButton("归档…", () => _store.RequestArchive(document), !prompt.IsReadOnly));
        var delete = new Button { Content = "删除…", Classes = { "destructive" }, IsEnabled = !prompt.IsReadOnly };
        delete.Click += (_, _) => _store.RequestDelete(document);
        actions.Children.Add(delete);
        InspectorPanel.Children.Add(FormSection("操作", actions));
    }

    void AddMetaSections(DocumentRef document)
    {
        var meta = _store.ItemMetaFor(document);
        var tagBox = new TextBox { Text = string.Join(", ", meta.Tags), Watermark = "标签，逗号分隔", Classes = { "ghost" } };
        tagBox.LostFocus += (_, _) =>
            _store.SetTags((tagBox.Text ?? "").Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries), document);
        var notes = new TextBox { Text = meta.Notes, AcceptsReturn = true, Height = 72, Watermark = "只保存在本机", Classes = { "ghost" } };
        notes.LostFocus += (_, _) => _store.SetNotes(notes.Text ?? "", document);
        InspectorPanel.Children.Add(FormSection("标签", tagBox));
        InspectorPanel.Children.Add(FormSection("备注", notes, new TextBlock
        {
            Text = UsageScore.Caption(
                document is DocumentRef.Skill skill ? _store.Usage.Skill(skill.Item).Count
                    : document is DocumentRef.Prompt prompt ? _store.Usage.Prompt(prompt.Item).Count
                    : 0,
                meta.Starred,
                document is DocumentRef.Skill s ? s.Item.LiveInstallCount : 1),
            Classes = { "caption" }
        }));
    }

    Control InspectorHeader(string title, string subtitle, IReadOnlyList<ToolSource> sources, bool starred, Action toggle)
    {
        var star = new Button { Classes = { "toolbar" }, HorizontalAlignment = HorizontalAlignment.Right };
        star.Content = Glyph.Make("star", 14, starred ? Brushes.Gold : null);
        star.Click += (_, _) => toggle();
        var top = new DockPanel();
        DockPanel.SetDock(star, Dock.Right);
        top.Children.Add(star);
        top.Children.Add(new TextBlock { Text = title, FontSize = 20, FontWeight = FontWeight.Bold, TextWrapping = TextWrapping.Wrap });
        var badges = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4 };
        foreach (var source in sources)
        {
            badges.Children.Add(Badge(source.Title(), ColorUtil.Tool(source), ColorUtil.Soft(source)));
        }

        var stack = new StackPanel { Spacing = 8 };
        stack.Children.Add(top);
        stack.Children.Add(new TextBlock { Text = subtitle, Classes = { "muted" }, TextWrapping = TextWrapping.Wrap });
        stack.Children.Add(badges);
        return stack;
    }

    static Control FormSection(string? title, params Control[] children)
    {
        var stack = new StackPanel { Spacing = 8 };
        if (!string.IsNullOrEmpty(title))
        {
            stack.Children.Add(new TextBlock { Text = title, Classes = { "section" } });
        }

        var inner = new StackPanel { Spacing = 8 };
        foreach (var child in children)
        {
            if (child is TextBlock { Text: "" })
            {
                continue;
            }

            inner.Children.Add(child);
        }

        stack.Children.Add(new Border { Classes = { "form" }, Child = inner });
        return stack;
    }

    static Button ActionButton(string title, Action action, bool enabled = true)
    {
        var button = new Button { Content = title, Classes = { "action" }, IsEnabled = enabled };
        button.Click += (_, _) => action();
        return button;
    }

    static Control PathRow(string label, string path)
    {
        var stack = new StackPanel { Spacing = 2 };
        stack.Children.Add(new TextBlock { Text = label, Classes = { "caption" } });
        stack.Children.Add(new SelectableTextBlock { Text = path, TextWrapping = TextWrapping.Wrap, FontSize = 12 });
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
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = new StackPanel
            {
                Margin = new Thickness(20),
                Spacing = 16,
                Children =
                {
                    new TextBlock { Text = _store.ErrorMessage ?? "", TextWrapping = TextWrapping.Wrap }
                }
            }
        };
        var ok = new Button { Content = "好", HorizontalAlignment = HorizontalAlignment.Right };
        ok.Click += (_, _) => window.Close();
        ((StackPanel)window.Content!).Children.Add(ok);
        await window.ShowDialog(this);
        _store.DismissError();
    }

    async Task ShowConfirmAsync(ConfirmAction action)
    {
        var confirm = new Button { Content = action.ConfirmTitle };
        var cancel = new Button { Content = "取消" };
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8 };
        buttons.Children.Add(cancel);
        buttons.Children.Add(confirm);
        var window = new Window
        {
            Title = action.Title,
            Width = 460,
            SizeToContent = SizeToContent.Height,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = new StackPanel
            {
                Margin = new Thickness(20),
                Spacing = 16,
                Children =
                {
                    new TextBlock { Text = action.Message, TextWrapping = TextWrapping.Wrap },
                    buttons
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
}
