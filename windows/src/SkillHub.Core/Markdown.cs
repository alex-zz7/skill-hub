namespace SkillHub.Core;

public abstract record MarkdownBlock
{
    public sealed record Heading(int Level, string Text) : MarkdownBlock;
    public sealed record Paragraph(string Text) : MarkdownBlock;
    public sealed record Bullets(IReadOnlyList<string> Items) : MarkdownBlock;
    public sealed record Numbered(IReadOnlyList<string> Items) : MarkdownBlock;
    public sealed record Code(string Text) : MarkdownBlock;
    public sealed record Quote(string Text) : MarkdownBlock;
    public sealed record Rule : MarkdownBlock;
    public sealed record Table(IReadOnlyList<string> Header, IReadOnlyList<IReadOnlyList<string>> Rows) : MarkdownBlock;
}

public static class MarkdownParser
{
    public static IReadOnlyList<MarkdownBlock> Blocks(string raw)
    {
        var body = Frontmatter.Parse(raw).Body;
        var lines = body.Replace("\r\n", "\n").Split('\n').ToList();
        var blocks = new List<MarkdownBlock>();
        var index = 0;

        while (index < lines.Count)
        {
            var line = lines[index];
            var trimmed = line.Trim();

            if (trimmed.Length == 0)
            {
                index++;
                continue;
            }

            if (trimmed.StartsWith("```", StringComparison.Ordinal))
            {
                index++;
                var code = new List<string>();
                while (index < lines.Count && !lines[index].Trim().StartsWith("```", StringComparison.Ordinal))
                {
                    code.Add(lines[index]);
                    index++;
                }

                if (index < lines.Count)
                {
                    index++;
                }

                blocks.Add(new MarkdownBlock.Code(string.Join('\n', code)));
                continue;
            }

            if (trimmed is "---" or "***" or "___")
            {
                blocks.Add(new MarkdownBlock.Rule());
                index++;
                continue;
            }

            if (TryHeading(trimmed, out var heading))
            {
                blocks.Add(heading);
                index++;
                continue;
            }

            if (trimmed.StartsWith("> ", StringComparison.Ordinal) || trimmed == ">")
            {
                var quoted = new List<string>();
                while (index < lines.Count)
                {
                    var next = lines[index].Trim();
                    if (next.StartsWith("> ", StringComparison.Ordinal))
                    {
                        quoted.Add(next[2..]);
                    }
                    else if (next == ">")
                    {
                        quoted.Add("");
                    }
                    else
                    {
                        break;
                    }

                    index++;
                }

                blocks.Add(new MarkdownBlock.Quote(string.Join('\n', quoted)));
                continue;
            }

            if (IsTableRow(trimmed))
            {
                var rows = new List<IReadOnlyList<string>>();
                while (index < lines.Count && IsTableRow(lines[index].Trim()))
                {
                    var cells = TableCells(lines[index]);
                    if (!IsTableSeparator(cells))
                    {
                        rows.Add(cells);
                    }

                    index++;
                }

                if (rows.Count > 0)
                {
                    blocks.Add(new MarkdownBlock.Table(rows[0].ToArray(), rows.Skip(1).Select(r => (IReadOnlyList<string>)r.ToArray()).ToArray()));
                }

                continue;
            }

            if (IsBullet(trimmed))
            {
                var items = new List<string>();
                while (index < lines.Count && IsBullet(lines[index].Trim()))
                {
                    items.Add(StripBullet(lines[index].Trim()));
                    index++;
                }

                blocks.Add(new MarkdownBlock.Bullets(items.ToArray()));
                continue;
            }

            if (IsNumbered(trimmed))
            {
                var items = new List<string>();
                while (index < lines.Count && IsNumbered(lines[index].Trim()))
                {
                    items.Add(StripNumber(lines[index].Trim()));
                    index++;
                }

                blocks.Add(new MarkdownBlock.Numbered(items.ToArray()));
                continue;
            }

            var paragraph = new List<string> { trimmed };
            index++;
            while (index < lines.Count)
            {
                var next = lines[index].Trim();
                if (next.Length == 0 || StartsBlock(next))
                {
                    break;
                }

                paragraph.Add(next);
                index++;
            }

            blocks.Add(new MarkdownBlock.Paragraph(string.Join(' ', paragraph)));
        }

        return blocks;
    }

    public static IReadOnlyList<MarkdownBlock> SkippingRedundantTitle(IReadOnlyList<MarkdownBlock> blocks, string title)
    {
        if (blocks.Count == 0 || blocks[0] is not MarkdownBlock.Heading(1, var text))
        {
            return blocks;
        }

        var compact = text.Replace(" ", "", StringComparison.Ordinal).ToLowerInvariant();
        var name = title.Replace("-", "", StringComparison.Ordinal).Replace(" ", "", StringComparison.Ordinal).ToLowerInvariant();
        if (compact == name || string.Equals(text, title, StringComparison.CurrentCultureIgnoreCase))
        {
            return blocks.Skip(1).ToArray();
        }

        return blocks;
    }

    static bool TryHeading(string trimmed, out MarkdownBlock heading)
    {
        heading = new MarkdownBlock.Rule();
        if (!trimmed.StartsWith('#'))
        {
            return false;
        }

        var hashes = trimmed.TakeWhile(c => c == '#').Count();
        if (hashes is < 1 or > 6 || trimmed.Length <= hashes)
        {
            return false;
        }

        if (trimmed[hashes] != ' ')
        {
            return false;
        }

        heading = new MarkdownBlock.Heading(hashes, trimmed[hashes..].Trim());
        return true;
    }

    static bool StartsBlock(string line) =>
        line.StartsWith('#') || line.StartsWith("```", StringComparison.Ordinal) || line.StartsWith("> ", StringComparison.Ordinal)
        || IsBullet(line) || IsNumbered(line) || IsTableRow(line) || line == "---";

    static bool IsTableRow(string line) =>
        line.StartsWith('|') && line.AsSpan(1).Contains('|');

    static bool IsTableSeparator(IReadOnlyList<string> cells) =>
        cells.Count > 0 && cells.All(cell => cell.Replace(":", "", StringComparison.Ordinal).Replace("-", "", StringComparison.Ordinal).Trim().Length == 0);

    static List<string> TableCells(string line)
    {
        var parts = line.Split('|').Select(p => p.Trim()).ToList();
        if (parts.Count > 0 && parts[0].Length == 0)
        {
            parts.RemoveAt(0);
        }

        if (parts.Count > 0 && parts[^1].Length == 0)
        {
            parts.RemoveAt(parts.Count - 1);
        }

        return parts;
    }

    static bool IsBullet(string line) =>
        line.StartsWith("- ", StringComparison.Ordinal) || line.StartsWith("* ", StringComparison.Ordinal) || line.StartsWith("• ", StringComparison.Ordinal);

    static string StripBullet(string line) => IsBullet(line) ? line[2..] : line;

    static bool IsNumbered(string line)
    {
        var dot = line.IndexOf('.');
        if (dot <= 0)
        {
            return false;
        }

        var prefix = line[..dot];
        return prefix.All(char.IsDigit) && line[dot..].StartsWith(". ", StringComparison.Ordinal);
    }

    static string StripNumber(string line)
    {
        var dot = line.IndexOf('.');
        return dot < 0 ? line : line[(dot + 2)..];
    }
}
