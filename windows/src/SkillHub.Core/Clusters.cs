namespace SkillHub.Core;

public abstract record ClusterKind
{
    public sealed record Skill(string Id) : ClusterKind;
    public sealed record Prompt(string Id) : ClusterKind;
    public sealed record Group(string Prefix, IReadOnlyList<string> MemberIds) : ClusterKind;
}

public sealed record ClusterNode(
    string Id,
    string Title,
    ClusterKind Kind,
    double Weight,
    int Count,
    int OpenCount)
{
    public bool IsGroup => Kind is ClusterKind.Group;

    public IReadOnlyList<string> MemberIds => Kind switch
    {
        ClusterKind.Skill s => [s.Id],
        ClusterKind.Prompt p => [p.Id],
        ClusterKind.Group g => g.MemberIds,
        _ => []
    };
}

public static class ClusterGrouping
{
    public static IReadOnlyList<string> Tokens(string name) =>
        name.ToLowerInvariant()
            .Replace('_', '-')
            .Split(['-', ' '], StringSplitOptions.RemoveEmptyEntries);

    public static bool Belongs(string name, string prefix)
    {
        var n = name.ToLowerInvariant();
        var p = prefix.ToLowerInvariant();
        return n == p || n.StartsWith(p + "-", StringComparison.Ordinal) || n.StartsWith(p + " ", StringComparison.Ordinal);
    }

    public static string? NextPrefix(string name, string? parent)
    {
        var parts = Tokens(name);
        var depth = parent == null ? 0 : Tokens(parent).Count;
        if (parts.Count <= depth + 1)
        {
            return null;
        }

        return string.Join('-', parts.Take(depth + 1));
    }
}

public static class ClusterBuilder
{
    public sealed record Item(string Id, string Title, double Weight, int OpenCount, bool IsSkill);

    public static IReadOnlyList<ClusterNode> Nodes(IReadOnlyList<Item> items, string? parent, int? looseCap)
    {
        var buckets = new Dictionary<string, List<int>>(StringComparer.Ordinal);
        var loose = new List<int>();

        for (var index = 0; index < items.Count; index++)
        {
            var key = ClusterGrouping.NextPrefix(items[index].Title, parent);
            if (key != null)
            {
                if (!buckets.TryGetValue(key, out var list))
                {
                    list = [];
                    buckets[key] = list;
                }

                list.Add(index);
            }
            else
            {
                loose.Add(index);
            }
        }

        var stillLoose = new List<int>();
        foreach (var index in loose)
        {
            var key = items[index].Title.ToLowerInvariant();
            if (buckets.ContainsKey(key))
            {
                buckets[key].Add(index);
            }
            else
            {
                stillLoose.Add(index);
            }
        }

        var groups = new List<ClusterNode>();
        foreach (var (key, indexes) in buckets)
        {
            if (indexes.Count < 2)
            {
                stillLoose.AddRange(indexes);
                continue;
            }

            var members = indexes.Select(i => items[i]).ToArray();
            groups.Add(new ClusterNode(
                $"group:{key}",
                key,
                new ClusterKind.Group(key, members.Select(m => m.Id).ToArray()),
                members.Sum(m => m.Weight),
                members.Length,
                members.Sum(m => m.OpenCount)));
        }

        groups.Sort((a, b) => b.Weight.CompareTo(a.Weight));

        var singles = stillLoose.Select(i => items[i]).OrderByDescending(i => i.Weight).ToList();
        var visible = looseCap is int cap ? singles.Take(cap).ToList() : singles;
        var singleNodes = visible.Select(item => new ClusterNode(
            item.Id,
            item.Title,
            item.IsSkill ? new ClusterKind.Skill(item.Id) : new ClusterKind.Prompt(item.Id),
            item.Weight,
            1,
            item.OpenCount));

        return groups.Concat(singleNodes).ToArray();
    }
}

public readonly record struct MapSize(double Width, double Height);
public readonly record struct MapPoint(double X, double Y);
public readonly record struct Placement(double Diameter, MapPoint Center);

public static class ClusterLayout
{
    const double MinimumDiameter = 48;

    public static double NucleusDiameter(MapSize canvas) =>
        Math.Min(140, Math.Max(96, Math.Min(canvas.Width, canvas.Height) * 0.11));

    public static IReadOnlyDictionary<string, Placement> Plan(IReadOnlyList<ClusterNode> nodes, MapSize canvas)
    {
        if (canvas.Width <= 40 || canvas.Height <= 40 || nodes.Count == 0)
        {
            return new Dictionary<string, Placement>();
        }

        var ordered = nodes
            .OrderByDescending(n => n.Weight)
            .ThenBy(n => n.Id, StringComparer.Ordinal)
            .ToList();
        var priority = ordered.Select((node, index) => (node.Id, index)).ToDictionary(p => p.Id, p => p.index);
        var sizes = Diameters(nodes, canvas);
        for (var i = 0; i < 8; i++)
        {
            var slots = Pack(sizes, priority, canvas);
            if (slots.Count == sizes.Count)
            {
                return Merge(sizes, slots);
            }

            foreach (var key in sizes.Keys.ToArray())
            {
                sizes[key] = Math.Max(MinimumDiameter, sizes[key] * 0.88);
            }
        }

        return Merge(sizes, Pack(sizes, priority, canvas));
    }

    static Dictionary<string, Placement> Merge(Dictionary<string, double> sizes, Dictionary<string, MapPoint> slots) =>
        slots.ToDictionary(kv => kv.Key, kv => new Placement(sizes.GetValueOrDefault(kv.Key, 80), kv.Value));

    static Dictionary<string, double> Diameters(IReadOnlyList<ClusterNode> nodes, MapSize canvas)
    {
        var span = Math.Min(canvas.Width, canvas.Height);
        var weights = nodes.Select(n => Math.Max(n.Weight, 1)).ToArray();
        var lo = weights.Min();
        var hi = weights.Max();
        var minD = Math.Min(78, Math.Max(MinimumDiameter, span * 0.11));
        var maxD = Math.Max(minD + 12, Math.Min(176, span * 0.24));
        var raw = new Dictionary<string, double>();
        foreach (var node in nodes)
        {
            var t = hi - lo < 0.01 ? 0.5 : (Math.Max(node.Weight, 1) - lo) / (hi - lo);
            raw[node.Id] = minD + Math.Sqrt(t) * (maxD - minD);
        }

        var rx = canvas.Width * 0.46;
        var ry = canvas.Height * 0.46;
        var nucleus = NucleusDiameter(canvas) / 2;
        var available = Math.Max(800, Math.PI * rx * ry * 0.56 - Math.PI * nucleus * nucleus);
        var area = raw.Values.Sum(d => Math.PI * (d / 2) * (d / 2));
        if (area > available)
        {
            var scale = Math.Sqrt(available / area);
            foreach (var key in raw.Keys.ToArray())
            {
                raw[key] = Math.Max(MinimumDiameter, raw[key] * scale);
            }
        }

        return raw;
    }

    static Dictionary<string, MapPoint> Pack(Dictionary<string, double> sizes, Dictionary<string, int> priority, MapSize canvas)
    {
        var origin = new MapPoint(canvas.Width / 2, canvas.Height / 2);
        var rx = canvas.Width * 0.46;
        var ry = canvas.Height * 0.46;
        var nucleus = NucleusDiameter(canvas) / 2;
        const double gap = 11;
        var placed = new List<(MapPoint Point, double Radius)>();
        var result = new Dictionary<string, MapPoint>();
        var ordered = sizes
            .OrderByDescending(kv => kv.Value)
            .ThenBy(kv => priority.GetValueOrDefault(kv.Key, int.MaxValue))
            .ToList();

        foreach (var (id, diameter) in ordered)
        {
            var radius = diameter / 2;
            MapPoint? found = null;
            var minT = Math.Min(0.92, (nucleus + radius + gap) / Math.Max(Math.Min(rx, ry), 1));
            var maxT = Math.Max(minT, 1 - radius / Math.Max(Math.Min(rx, ry), 1));
            var t = minT;
            while (t <= maxT + 0.001)
            {
                var ringX = rx * t;
                var ringY = ry * t;
                var steps = Math.Max(8, (int)((ringX + ringY) * Math.PI / Math.Max(radius * 1.8, 28)));
                var spin = placed.Count * 0.41;
                var hit = false;
                for (var step = 0; step < steps; step++)
                {
                    var angle = spin + step / (double)steps * Math.PI * 2;
                    var point = new MapPoint(origin.X + Math.Cos(angle) * ringX, origin.Y + Math.Sin(angle) * ringY);
                    var nx = (point.X - origin.X) / Math.Max(rx - radius - 4, 1);
                    var ny = (point.Y - origin.Y) / Math.Max(ry - radius - 4, 1);
                    if (nx * nx + ny * ny > 1)
                    {
                        continue;
                    }

                    if (Hypot(point.X - origin.X, point.Y - origin.Y) < nucleus + radius + gap)
                    {
                        continue;
                    }

                    if (placed.All(p => Hypot(p.Point.X - point.X, p.Point.Y - point.Y) >= p.Radius + radius + gap))
                    {
                        found = point;
                        hit = true;
                        break;
                    }
                }

                if (hit)
                {
                    break;
                }

                t += 0.05;
            }

            if (found is { } placedPoint)
            {
                placed.Add((placedPoint, radius));
                result[id] = placedPoint;
            }
        }

        return result;
    }

    static double Hypot(double x, double y) => Math.Sqrt(x * x + y * y);
}

public static class UsageScore
{
    public static double Score(
        int openCount,
        DateTime? lastOpenedAt,
        bool starred,
        int installs,
        DateTime modifiedAt,
        DateTime now)
    {
        var opens = openCount * 10.0;
        var star = starred ? 16.0 : 0;
        var places = Math.Max(installs, 1) * 3.0;
        var last = lastOpenedAt ?? modifiedAt;
        var daysSinceOpen = (now - last).TotalDays;
        var recency = Math.Max(0, 18 - daysSinceOpen * 0.45);
        var freshness = Math.Max(0, 6 - (now - modifiedAt).TotalDays / 10);
        return Math.Max(1, 2 + opens + star + places + recency + freshness);
    }

    public static double Score(SkillItem skill, ItemMeta meta, DateTime now) =>
        Score(meta.OpenCount, meta.LastOpenedAt, meta.Starred, skill.LiveInstallCount, skill.ModifiedAt, now);

    public static double Score(PromptItem prompt, ItemMeta meta, DateTime now) =>
        Score(meta.OpenCount, meta.LastOpenedAt, meta.Starred, 1, prompt.ModifiedAt, now);

    public static string Caption(int openCount, bool starred, int installs)
    {
        var parts = new List<string>();
        if (openCount > 0)
        {
            parts.Add($"打开 {openCount} 次");
        }

        if (starred)
        {
            parts.Add("已收藏");
        }

        if (installs > 1)
        {
            parts.Add($"装在 {installs} 处");
        }

        return parts.Count == 0 ? "还没打开过" : string.Join(" · ", parts);
    }
}

public static class ThemeTint
{
    static readonly string[] Palette =
    [
        "#FF3B30", "#0A84FF", "#FF9F0A", "#30D158", "#BF5AF2",
        "#64D2FF", "#FF375F", "#5E5CE6", "#63E6E2", "#A2845E",
        "#5AC8F5", "#FFD60A"
    ];

    public static string ForKey(string key)
    {
        var sum = key.EnumerateRunes().Aggregate(0, (acc, rune) => acc + rune.Value);
        return Palette[Math.Abs(sum) % Palette.Length];
    }
}
