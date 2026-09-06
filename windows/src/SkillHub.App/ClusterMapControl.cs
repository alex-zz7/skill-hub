using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using SkillHub.Core;

namespace SkillHub.App;

public sealed class ClusterMapControl : Control
{
    public static readonly StyledProperty<IReadOnlyList<ClusterNode>?> NodesProperty =
        AvaloniaProperty.Register<ClusterMapControl, IReadOnlyList<ClusterNode>?>(nameof(Nodes));

    public static readonly StyledProperty<string> NucleusTitleProperty =
        AvaloniaProperty.Register<ClusterMapControl, string>(nameof(NucleusTitle), "Skills");

    public static readonly StyledProperty<int> NucleusCountProperty =
        AvaloniaProperty.Register<ClusterMapControl, int>(nameof(NucleusCount));

    public IReadOnlyList<ClusterNode>? Nodes
    {
        get => GetValue(NodesProperty);
        set => SetValue(NodesProperty, value);
    }

    public string NucleusTitle
    {
        get => GetValue(NucleusTitleProperty);
        set => SetValue(NucleusTitleProperty, value);
    }

    public int NucleusCount
    {
        get => GetValue(NucleusCountProperty);
        set => SetValue(NucleusCountProperty, value);
    }

    public event Action<ClusterNode>? NodeActivated;
    public event Action? NucleusActivated;

    IReadOnlyDictionary<string, Placement> _placements = new Dictionary<string, Placement>();

    static ClusterMapControl()
    {
        AffectsRender<ClusterMapControl>(NodesProperty, NucleusTitleProperty, NucleusCountProperty);
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        Relayout(finalSize);
        return base.ArrangeOverride(finalSize);
    }

    protected override void OnPropertyChanged(AvaloniaPropertyChangedEventArgs change)
    {
        base.OnPropertyChanged(change);
        if (change.Property == NodesProperty)
        {
            Relayout(Bounds.Size);
            InvalidateVisual();
        }
    }

    void Relayout(Size size)
    {
        var nodes = Nodes ?? [];
        _placements = ClusterLayout.Plan(nodes, new MapSize(size.Width, size.Height));
    }

    public override void Render(DrawingContext context)
    {
        var nodes = Nodes ?? [];
        foreach (var node in nodes)
        {
            if (!_placements.TryGetValue(node.Id, out var slot))
            {
                continue;
            }

            var radius = slot.Diameter / 2;
            var origin = new Point(slot.Center.X - radius, slot.Center.Y - radius);
            var rect = new Rect(origin, new Size(slot.Diameter, slot.Diameter));
            context.DrawEllipse(ColorUtil.ClusterSoft(node.Title), new Pen(ColorUtil.Cluster(node.Title), 1.4), rect.Center, radius, radius);

            var typeface = new Typeface(FontFamily.Default, FontStyle.Normal, node.IsGroup ? FontWeight.SemiBold : FontWeight.Medium);
            var title = Truncate(node.Title, radius > 40 ? 14 : 10);
            var titleLayout = new FormattedText(title, System.Globalization.CultureInfo.CurrentCulture, FlowDirection.LeftToRight, typeface, radius > 40 ? 13 : 11, ColorUtil.Cluster(node.Title));
            context.DrawText(titleLayout, new Point(slot.Center.X - titleLayout.Width / 2, slot.Center.Y - 10));

            var caption = node.IsGroup ? $"{node.Count}" : "";
            if (caption.Length > 0)
            {
                var cap = new FormattedText(caption, System.Globalization.CultureInfo.CurrentCulture, FlowDirection.LeftToRight, Typeface.Default, 10, Brushes.Gray);
                context.DrawText(cap, new Point(slot.Center.X - cap.Width / 2, slot.Center.Y + 8));
            }
        }

        var nucleus = ClusterLayout.NucleusDiameter(new MapSize(Bounds.Width, Bounds.Height));
        var center = new Point(Bounds.Width / 2, Bounds.Height / 2);
        context.DrawEllipse(
            new SolidColorBrush(Color.Parse("#0A84FF")) { Opacity = 0.12 },
            new Pen(ColorUtil.Brush("#0A84FF"), 1.5),
            center,
            nucleus / 2,
            nucleus / 2);
        var name = new FormattedText(Truncate(NucleusTitle, 16), System.Globalization.CultureInfo.CurrentCulture, FlowDirection.LeftToRight, new Typeface(FontFamily.Default, FontStyle.Normal, FontWeight.SemiBold), 13, Brushes.DodgerBlue);
        context.DrawText(name, new Point(center.X - name.Width / 2, center.Y - 12));
        var count = new FormattedText($"{NucleusCount} 个", System.Globalization.CultureInfo.CurrentCulture, FlowDirection.LeftToRight, Typeface.Default, 11, Brushes.Gray);
        context.DrawText(count, new Point(center.X - count.Width / 2, center.Y + 8));
    }

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        var pos = e.GetPosition(this);
        var nucleus = ClusterLayout.NucleusDiameter(new MapSize(Bounds.Width, Bounds.Height)) / 2;
        var center = new Point(Bounds.Width / 2, Bounds.Height / 2);
        if (Distance(pos, center) <= nucleus)
        {
            NucleusActivated?.Invoke();
            return;
        }

        foreach (var node in Nodes ?? [])
        {
            if (!_placements.TryGetValue(node.Id, out var slot))
            {
                continue;
            }

            if (Distance(pos, new Point(slot.Center.X, slot.Center.Y)) <= slot.Diameter / 2)
            {
                NodeActivated?.Invoke(node);
                return;
            }
        }
    }

    static double Distance(Point a, Point b)
    {
        var dx = a.X - b.X;
        var dy = a.Y - b.Y;
        return Math.Sqrt(dx * dx + dy * dy);
    }

    static string Truncate(string text, int max) =>
        text.Length <= max ? text : text[..Math.Max(0, max - 1)] + "…";
}
