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

    public static readonly StyledProperty<bool> CanGoUpProperty =
        AvaloniaProperty.Register<ClusterMapControl, bool>(nameof(CanGoUp));

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

    public bool CanGoUp
    {
        get => GetValue(CanGoUpProperty);
        set => SetValue(CanGoUpProperty, value);
    }

    public event Action<ClusterNode>? NodeActivated;
    public event Action? NucleusActivated;

    IReadOnlyDictionary<string, Placement> _placements = new Dictionary<string, Placement>();

    static ClusterMapControl()
    {
        AffectsRender<ClusterMapControl>(NodesProperty, NucleusTitleProperty, NucleusCountProperty, CanGoUpProperty);
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

    void Relayout(Size size) =>
        _placements = ClusterLayout.Plan(Nodes ?? [], new MapSize(size.Width, size.Height));

    public override void Render(DrawingContext context)
    {
        if (Bounds.Width > 40 && Bounds.Height > 40 && (Nodes?.Count ?? 0) > 0 && _placements.Count == 0)
        {
            Relayout(Bounds.Size);
        }

        foreach (var node in Nodes ?? [])
        {
            if (!_placements.TryGetValue(node.Id, out var slot))
            {
                continue;
            }

            var radius = slot.Diameter / 2;
            var center = new Point(slot.Center.X, slot.Center.Y);
            var color = Color.Parse(ThemeTint.ForKey(node.Title));
            var fill = new LinearGradientBrush
            {
                StartPoint = new RelativePoint(0.5, 0, RelativeUnit.Relative),
                EndPoint = new RelativePoint(0.5, 1, RelativeUnit.Relative),
                GradientStops =
                {
                    new GradientStop(Lighten(color, 0.22), 0),
                    new GradientStop(color, 1)
                }
            };
            context.DrawEllipse(fill, new Pen(new SolidColorBrush(Colors.White, 0.28), 1), center, radius, radius);

            var title = Truncate(node.Title.Replace('-', ' '), radius > 40 ? 16 : 10);
            var titleSize = Math.Clamp(slot.Diameter * 0.15, 12, 20);
            var titleLayout = new FormattedText(title, System.Globalization.CultureInfo.CurrentCulture, FlowDirection.LeftToRight, new Typeface(FontFamily.Default, FontStyle.Normal, FontWeight.SemiBold), titleSize, Brushes.White);
            context.DrawText(titleLayout, new Point(center.X - titleLayout.Width / 2, center.Y - (node.IsGroup ? 12 : 8)));
            if (node.IsGroup)
            {
                var cap = new FormattedText(node.Count.ToString(), System.Globalization.CultureInfo.CurrentCulture, FlowDirection.LeftToRight, new Typeface(FontFamily.Default, FontStyle.Normal, FontWeight.Medium), Math.Clamp(slot.Diameter * 0.11, 11, 15), new SolidColorBrush(Colors.White, 0.9));
                context.DrawText(cap, new Point(center.X - cap.Width / 2, center.Y + 8));
            }
        }

        var nucleus = ClusterLayout.NucleusDiameter(new MapSize(Bounds.Width, Bounds.Height));
        var origin = new Point(Bounds.Width / 2, Bounds.Height / 2);
        context.DrawEllipse(
            new SolidColorBrush(Color.Parse("#F2F2F7"), 0.92),
            new Pen(new SolidColorBrush(Color.Parse("#D8D8DC")), 1),
            origin,
            nucleus / 2,
            nucleus / 2);

        var count = new FormattedText(
            NucleusCount.ToString(),
            System.Globalization.CultureInfo.CurrentCulture,
            FlowDirection.LeftToRight,
            new Typeface(FontFamily.Default, FontStyle.Normal, FontWeight.Bold),
            nucleus * 0.26,
            new SolidColorBrush(Color.Parse("#1D1D1F")));
        context.DrawText(count, new Point(origin.X - count.Width / 2, origin.Y - nucleus * 0.28));

        var name = new FormattedText(
            Truncate(NucleusTitle.Replace('-', ' '), 16),
            System.Globalization.CultureInfo.CurrentCulture,
            FlowDirection.LeftToRight,
            new Typeface(FontFamily.Default, FontStyle.Normal, FontWeight.Medium),
            Math.Max(12, nucleus * 0.11),
            new SolidColorBrush(Color.Parse("#1D1D1F")));
        context.DrawText(name, new Point(origin.X - name.Width / 2, origin.Y - 2));

        var hint = new FormattedText(
            CanGoUp ? "返回" : "重排",
            System.Globalization.CultureInfo.CurrentCulture,
            FlowDirection.LeftToRight,
            Typeface.Default,
            10,
            new SolidColorBrush(Color.Parse("#6E6E73")));
        context.DrawText(hint, new Point(origin.X - hint.Width / 2, origin.Y + nucleus * 0.16));
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

    static Color Lighten(Color color, double amount) =>
        Color.FromRgb(
            (byte)Math.Min(255, color.R + (255 - color.R) * amount),
            (byte)Math.Min(255, color.G + (255 - color.G) * amount),
            (byte)Math.Min(255, color.B + (255 - color.B) * amount));

    static double Distance(Point a, Point b)
    {
        var dx = a.X - b.X;
        var dy = a.Y - b.Y;
        return Math.Sqrt(dx * dx + dy * dy);
    }

    static string Truncate(string text, int max) =>
        text.Length <= max ? text : text[..Math.Max(0, max - 1)] + "…";
}
