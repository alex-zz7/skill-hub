using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using SkillHub.Core;

namespace SkillHub.App;

abstract class SheetWindow : Window
{
    protected SheetWindow(string title)
    {
        Title = title;
        Width = 460;
        SizeToContent = SizeToContent.Height;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        CanResize = false;
        Background = Avalonia.Media.Brushes.White;
    }

    protected static StackPanel Form(params Control[] children)
    {
        var stack = new StackPanel { Margin = new Thickness(20), Spacing = 12 };
        foreach (var child in children)
        {
            stack.Children.Add(child);
        }

        return stack;
    }

    protected static StackPanel Actions(Button primary, Action cancel)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Spacing = 8 };
        var close = new Button { Content = "取消" };
        close.Click += (_, _) => cancel();
        row.Children.Add(close);
        row.Children.Add(primary);
        return row;
    }
}

sealed class NewSkillWindow : SheetWindow
{
    public NewSkillWindow(CatalogStore store) : base("新建 Skill")
    {
        var name = new TextBox { Watermark = "例如 blog-outline" };
        var slug = new TextBlock { Classes = { "caption" } };
        var description = new TextBox { Watermark = "一句话说明什么时候用它", AcceptsReturn = true, Height = 72 };
        var sources = ToolSourceInfo.SkillRoots.Where(s => s.IsWritable()).ToArray();
        var picker = new ComboBox { ItemsSource = sources.Select(s => s.Title()).ToArray(), SelectedIndex = 0 };
        name.TextChanged += (_, _) =>
        {
            var value = Frontmatter.Slug(name.Text ?? "");
            slug.Text = value.Length == 0 ? "将创建为 —" : $"将创建为 {value}";
            slug.Foreground = Frontmatter.IsValidSkillName(value) ? Brushes.Gray : Brushes.IndianRed;
        };

        var create = new Button { Content = "创建" };
        create.Click += (_, _) =>
        {
            var source = sources[Math.Max(0, picker.SelectedIndex)];
            store.CreateSkill(name.Text ?? "", description.Text ?? "", source);
            Close();
        };

        Content = Form(
            new TextBlock { Text = "名字只能包含小写字母、数字和连字符。description 会写进 SKILL.md 的 frontmatter。", Classes = { "muted" }, TextWrapping = TextWrapping.Wrap },
            name,
            slug,
            description,
            new TextBlock { Text = "安装到", FontWeight = FontWeight.SemiBold },
            picker,
            Actions(create, Close));
    }
}

sealed class NewPromptWindow : SheetWindow
{
    public NewPromptWindow(CatalogStore store) : base("新建 Prompt")
    {
        var title = new TextBox { Watermark = "例如 周报总结" };
        var body = new TextBox { Watermark = "可以留空，稍后再编辑", AcceptsReturn = true, Height = 160, Classes = { "mono" } };
        var hint = new TextBlock { Classes = { "caption" }, TextWrapping = TextWrapping.Wrap };
        title.TextChanged += (_, _) =>
        {
            var slug = Frontmatter.Slug(title.Text ?? "");
            hint.Text = $"会保存为 ~/.skill-hub/library/prompts/{(slug.Length == 0 ? "…" : slug)}.md";
        };

        var create = new Button { Content = "创建" };
        create.Click += (_, _) =>
        {
            store.CreatePrompt(title.Text ?? "", body.Text ?? "");
            Close();
        };

        Content = Form(title, body, hint, Actions(create, Close));
    }
}

sealed class InstallWindow : SheetWindow
{
    public InstallWindow(CatalogStore store) : base("安装到其他工具")
    {
        var skill = store.SelectedSkill;
        var targets = skill == null ? [] : store.AvailableInstallTargets(skill);
        var picker = new ComboBox { ItemsSource = targets.Select(t => t.Title()).ToArray(), SelectedIndex = targets.Count > 0 ? 0 : -1 };
        var copy = new CheckBox { Content = "复制成独立实体，而不是符号链接" };
        var hint = new TextBlock
        {
            Classes = { "muted" },
            TextWrapping = TextWrapping.Wrap,
            Text = "符号链接指回同一个目录，在任何工具里修改都是同一份文件。推荐。Windows 若未开开发人员模式，会改用目录联接。"
        };
        copy.IsCheckedChanged += (_, _) =>
            hint.Text = copy.IsChecked == true
                ? "复制后两边各自独立，修改不会同步。"
                : "符号链接指回同一个目录，在任何工具里修改都是同一份文件。推荐。Windows 若未开开发人员模式，会改用目录联接。";

        var primary = new Button { Content = "链接", IsEnabled = skill != null && targets.Count > 0 };
        copy.IsCheckedChanged += (_, _) => primary.Content = copy.IsChecked == true ? "复制" : "链接";
        primary.Click += (_, _) =>
        {
            if (skill == null || picker.SelectedIndex < 0)
            {
                return;
            }

            store.Install(skill, targets[picker.SelectedIndex], copy.IsChecked == true);
            Close();
        };

        Content = Form(
            new TextBlock { Text = skill == null ? "没有选中 skill。" : $"Skill：{skill.Name}" },
            targets.Count == 0
                ? new TextBlock { Text = "已经装到所有可写的工具里了。", Classes = { "muted" } }
                : picker,
            copy,
            hint,
            Actions(primary, Close));
    }
}

sealed class DedupeWindow : SheetWindow
{
    public DedupeWindow(CatalogStore store) : base("一键去重")
    {
        var policies = DedupePolicy.All;
        var picker = new ComboBox { ItemsSource = policies.Select(p => p.Title).ToArray(), SelectedIndex = 0 };
        var list = new StackPanel { Spacing = 4 };
        foreach (var skill in store.DuplicateSkills.Take(8))
        {
            list.Children.Add(new TextBlock
            {
                Text = $"{skill.Name}  ·  {string.Join(" · ", skill.ToolSources.Select(s => s.Title()))}",
                TextWrapping = TextWrapping.Wrap
            });
        }

        if (store.DuplicateSkills.Count > 8)
        {
            list.Children.Add(new TextBlock { Text = $"…还有 {store.DuplicateSkills.Count - 8} 个", Classes = { "caption" } });
        }

        var primary = new Button
        {
            Content = $"去重 {store.DuplicateSkills.Count} 个",
            IsEnabled = store.DuplicateSkills.Count > 0
        };
        primary.Click += (_, _) =>
        {
            store.DedupeAll(policies[Math.Max(0, picker.SelectedIndex)]);
            Close();
        };

        Content = Form(
            new TextBlock
            {
                Text = $"有 {store.DuplicateSkills.Count} 个 skill 同时出现在多个工具目录里。选择保留哪一份，其余会被移除。Cursor 内置目录只读，不会改动。",
                Classes = { "muted" },
                TextWrapping = TextWrapping.Wrap
            },
            new TextBlock { Text = "保留策略", FontWeight = FontWeight.SemiBold },
            picker,
            list,
            Actions(primary, Close));
    }
}
