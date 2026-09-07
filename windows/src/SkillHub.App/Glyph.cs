using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace SkillHub.App;

/// Compact SF-Symbol-like glyphs so the Windows shell can use the same icon language as the Mac app.
public sealed class Glyph : Control
{
    public static readonly StyledProperty<string> KindProperty =
        AvaloniaProperty.Register<Glyph, string>(nameof(Kind), "dot");

    public static readonly StyledProperty<IBrush?> FillProperty =
        AvaloniaProperty.Register<Glyph, IBrush?>(nameof(Fill));

    public string Kind
    {
        get => GetValue(KindProperty);
        set => SetValue(KindProperty, value);
    }

    public IBrush? Fill
    {
        get => GetValue(FillProperty);
        set => SetValue(FillProperty, value);
    }

    static Glyph()
    {
        AffectsRender<Glyph>(KindProperty, FillProperty);
        WidthProperty.OverrideDefaultValue<Glyph>(14);
        HeightProperty.OverrideDefaultValue<Glyph>(14);
    }

    public override void Render(DrawingContext context)
    {
        var geometry = Geometry.Parse(Path(Kind));
        var brush = Fill ?? Brushes.Gray;
        var matrix = Matrix.CreateScale(Bounds.Width / 16, Bounds.Height / 16);
        using (context.PushTransform(matrix))
        {
            context.DrawGeometry(brush, null, geometry);
        }
    }

    public static Glyph Make(string kind, double size = 14, IBrush? fill = null) =>
        new() { Kind = kind, Width = size, Height = size, Fill = fill };

    static string Path(string kind) => kind switch
    {
        "pie" => "M8 2 A6 6 0 1 1 2 8 L8 8 Z M8 2 L8 8 L14 8 A6 6 0 0 0 8 2 Z",
        "grid" => "M2 2h5v5H2z M9 2h5v5H9z M2 9h5v5H2z M9 9h5v5H9z",
        "star" => "M8 2 L10 6.2 L14.5 6.8 L11.2 10 L12.1 14.5 L8 12.2 L3.9 14.5 L4.8 10 L1.5 6.8 L6 6.2 Z",
        "dup" => "M4 4h7v7H4z M6 6h7v7H6z",
        "health" => "M8 14 C3 10 2 7 4.5 4.8 C6 3.6 8 4.6 8 6 C8 4.6 10 3.6 11.5 4.8 C14 7 13 10 8 14 Z",
        "cursor" => "M3 2 L3 12 L6 9 L8 14 L10 13 L8 8 L13 8 Z",
        "spark" => "M8 1 L9.2 6 L14 7 L9.2 8 L8 13 L6.8 8 L2 7 L6.8 6 Z",
        "code" => "M6 3 L2 8 L6 13 M10 3 L14 8 L10 13",
        "people" => "M6 7 A2 2 0 1 0 6 3 A2 2 0 0 0 6 7 M11 7 A1.7 1.7 0 1 0 11 3.6 A1.7 1.7 0 0 0 11 7 M2 13 C2 10 4 9 6 9 C8 9 10 10 10 13 M10 13 C10 11 12 10 13 10 C14.5 10 15.5 11 15.5 13",
        "wand" => "M3 13 L8 8 M9 3 L10 6 L13 7 L10 8 L9 11 L8 8 L5 7 L8 6 Z",
        "books" => "M3 3h3v11H3z M7 3h3v11H7z M11 4 l3-1 v11 l-3 1z",
        "quote" => "M3 6 h4 v5 H4 L3 14 V6 M9 6 h4 v5 h-3 L9 14 V6",
        "folder" => "M2 5 h5 l1.5 1.5 H14 v7 H2z M2 5 V4 h4 l1 1",
        "plus" => "M8 3 V13 M3 8 H13",
        "refresh" => "M13 8 A5 5 0 1 1 11 4 M11 4 h3 v-0.1 L12 6",
        "sidebar" => "M2 3 h12 v10 H2z M11 3 v10",
        "chevronRight" => "M6 3 L11 8 L6 13",
        "chevronLeft" => "M10 3 L5 8 L10 13",
        "chevronUp" => "M3 10 L8 5 L13 10",
        "warning" => "M8 2 L15 14 H1 Z M8 6 v4 M8 12 v0.8",
        "tray" => "M2 6 h12 v7 H2z M5 6 L6.5 3 h3 L11 6",
        "link" => "M6 8 A3 3 0 0 1 9 5 L11 3 A3 3 0 0 1 15 7 L13 9 M10 8 A3 3 0 0 1 7 11 L5 13 A3 3 0 0 1 1 9 L3 7",
        "archive" => "M2 3 h12 v3 H2z M3 6 v8 h10 V6 M6 9 h4",
        "trash" => "M3 5 h10 M6 5 V3 h4 v2 M5 5 v9 h6 V5",
        "save" => "M3 3 h8 l2 2 v8 H3z M5 3 v4 h6 V3 M5 11 h6",
        "pencil" => "M3 13 l1.2-4 L12 1.2 14.8 4 6 13z",
        "doc" => "M4 2 h6 l3 3 v9 H4z M10 2 v3 h3",
        "docs" => "M3 4 h7 v10 H3z M6 2 h7 v10",
        "check" => "M3 8 L6.5 12 L13 4",
        "dot" => "M8 6 A2 2 0 1 0 8 10 A2 2 0 0 0 8 6",
        _ => "M8 6 A2 2 0 1 0 8 10 A2 2 0 0 0 8 6"
    };
}
