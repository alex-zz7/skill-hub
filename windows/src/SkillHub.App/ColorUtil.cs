using Avalonia.Media;
using SkillHub.Core;

namespace SkillHub.App;

static class ColorUtil
{
    public static IBrush Brush(string hex) =>
        new SolidColorBrush(Color.Parse(hex));

    public static IBrush Tool(ToolSource source) => Brush(source.TintHex());

    public static IBrush Soft(ToolSource source) =>
        new SolidColorBrush(Color.Parse(source.TintHex())) { Opacity = 0.16 };

    public static IBrush Cluster(string key) => Brush(ThemeTint.ForKey(key));

    public static IBrush ClusterSoft(string key) =>
        new SolidColorBrush(Color.Parse(ThemeTint.ForKey(key))) { Opacity = 0.22 };
}
