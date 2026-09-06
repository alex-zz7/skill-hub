using System.Text.RegularExpressions;

namespace SkillHub.Core;

public static partial class Frontmatter
{
    public static FrontmatterDocument Parse(string raw)
    {
        var normalized = raw.Replace("\r\n", "\n");
        var lines = SplitKeepEmpty(normalized);
        if (lines.Count == 0 || lines[0].Trim() != "---")
        {
            return new FrontmatterDocument("", "", "", normalized, raw);
        }

        var index = 1;
        var fields = new Dictionary<string, string>(StringComparer.Ordinal);
        while (index < lines.Count)
        {
            var line = lines[index];
            var trimmed = line.Trim();
            if (trimmed == "---")
            {
                index++;
                break;
            }

            if (trimmed.Length == 0 || trimmed.StartsWith('#'))
            {
                index++;
                continue;
            }

            var colon = line.IndexOf(':');
            if (colon < 0)
            {
                index++;
                continue;
            }

            var key = line[..colon].Trim();
            var value = line[(colon + 1)..].Trim();

            if (value is "|" or "|-" or "|+" or ">" or ">-")
            {
                var folded = value.StartsWith('>');
                index++;
                var block = new List<string>();
                while (index < lines.Count)
                {
                    var next = lines[index];
                    var nextTrimmed = next.Trim();
                    if (nextTrimmed == "---")
                    {
                        break;
                    }

                    var indent = next.TakeWhile(c => c is ' ' or '\t').Count();
                    if (indent == 0 && nextTrimmed.Length > 0)
                    {
                        break;
                    }

                    block.Add(next.TrimStart(' ', '\t'));
                    index++;
                }

                fields[key] = folded
                    ? string.Join(' ', block).Trim()
                    : string.Join('\n', block).Trim('\n');
                continue;
            }

            fields[key] = Unquote(value);
            index++;
        }

        var body = string.Join('\n', lines.Skip(index)).Trim('\n');
        return new FrontmatterDocument(
            fields.GetValueOrDefault("name", ""),
            fields.GetValueOrDefault("description", ""),
            fields.GetValueOrDefault("version", ""),
            body,
            raw);
    }

    public static string Render(string name, string description, string body)
    {
        var safeName = name.Trim();
        var safeDescription = description.Trim();
        var content = body.Trim();
        var heading = content.Length == 0
            ? $"# {TitleCase(safeName)}\n\n## Instructions\n"
            : content;
        return $"""
            ---
            name: {safeName}
            description: {safeDescription}
            ---

            {heading}
            """;
    }

    public static string Slug(string value)
    {
        var mapped = value.ToLowerInvariant().Select(ch => char.IsLetter(ch) || char.IsNumber(ch) ? ch : '-');
        var collapsed = CollapseHyphens().Replace(new string(mapped.ToArray()), "-").Trim('-');
        return collapsed.Length <= 64 ? collapsed : collapsed[..64];
    }

    public static bool IsValidSkillName(string name) =>
        name.Length <= 64 && ValidName().IsMatch(name);

    static string Unquote(string value)
    {
        if (value.Length >= 2 &&
            ((value.StartsWith('"') && value.EndsWith('"')) || (value.StartsWith('\'') && value.EndsWith('\''))))
        {
            return value[1..^1];
        }

        return value;
    }

    static string TitleCase(string slug) =>
        string.Join(' ', slug.Split('-', StringSplitOptions.RemoveEmptyEntries)
            .Select(part => part.Length == 0 ? part : char.ToUpperInvariant(part[0]) + part[1..]));

    static List<string> SplitKeepEmpty(string text) =>
        text.Split('\n').ToList();

    [GeneratedRegex("-{2,}")]
    private static partial Regex CollapseHyphens();

    [GeneratedRegex("^[a-z0-9]+(?:-[a-z0-9]+)*$")]
    private static partial Regex ValidName();
}
