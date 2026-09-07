using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace SkillHub.Core;

public sealed class UsageStat
{
    public int Count { get; set; }
    public DateTime? LastInvokedAt { get; set; }

    public static UsageStat Empty => new();

    public void Add(DateTime? date)
    {
        Count++;
        if (date is { } when && (LastInvokedAt == null || when > LastInvokedAt))
        {
            LastInvokedAt = when;
        }
    }
}

public sealed class UsageIndex
{
    public Dictionary<string, UsageStat> Skills { get; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, UsageStat> Prompts { get; } = new(StringComparer.OrdinalIgnoreCase);

    public static UsageIndex Empty { get; } = new();

    public UsageStat Skill(SkillItem item) =>
        Lookup(Skills, item.FolderName) ?? Lookup(Skills, item.Name) ?? UsageStat.Empty;

    public UsageStat Prompt(PromptItem item)
    {
        var stem = Path.GetFileNameWithoutExtension(item.CanonicalPath);
        return Lookup(Prompts, stem) ?? Lookup(Prompts, item.Title) ?? UsageStat.Empty;
    }

    public void AddSkill(string raw, DateTime? date)
    {
        var name = raw.Trim();
        if (name.Length == 0)
        {
            return;
        }

        Add(Skills, name, date);
        var colon = name.LastIndexOf(':');
        if (colon >= 0 && colon < name.Length - 1)
        {
            Add(Skills, name[(colon + 1)..], date);
        }
    }

    public void AddPrompt(string raw, DateTime? date) => Add(Prompts, raw, date);

    public void Merge(UsageIndex other)
    {
        MergeInto(Skills, other.Skills);
        MergeInto(Prompts, other.Prompts);
    }

    static void MergeInto(Dictionary<string, UsageStat> dest, Dictionary<string, UsageStat> src)
    {
        foreach (var (key, stat) in src)
        {
            if (!dest.TryGetValue(key, out var current))
            {
                dest[key] = new UsageStat { Count = stat.Count, LastInvokedAt = stat.LastInvokedAt };
                continue;
            }

            current.Count += stat.Count;
            if (stat.LastInvokedAt is { } at && (current.LastInvokedAt == null || at > current.LastInvokedAt))
            {
                current.LastInvokedAt = at;
            }
        }
    }

    static UsageStat? Lookup(Dictionary<string, UsageStat> map, string raw) =>
        map.TryGetValue(raw.Trim(), out var stat) ? stat : null;

    static void Add(Dictionary<string, UsageStat> map, string raw, DateTime? date)
    {
        var key = raw.Trim();
        if (key.Length == 0)
        {
            return;
        }

        if (!map.TryGetValue(key, out var stat))
        {
            stat = new UsageStat();
            map[key] = stat;
        }

        stat.Add(date);
    }
}

public static class UsageLog
{
    static readonly Regex SkillPath = new(
        @"(?:skills|skills-cursor|default-skills)/([A-Za-z0-9][A-Za-z0-9._-]{0,80})/SKILL\.md",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);
    static readonly Regex PromptPath = new(
        @"(?:\.codex/prompts|\.skill-hub/library/prompts)/([A-Za-z0-9][A-Za-z0-9._-]{0,80})\.md",
        RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    static readonly HashSet<string> ReadTools = new(StringComparer.OrdinalIgnoreCase)
    {
        "read", "read_file", "readfile", "view"
    };
    static readonly HashSet<string> SkillTools = new(StringComparer.OrdinalIgnoreCase) { "skill" };
    static readonly HashSet<string> SkipTools = new(StringComparer.OrdinalIgnoreCase)
    {
        "grep", "glob", "search", "write", "strreplace", "edit", "delete",
        "todowrite", "websearch", "webfetch"
    };

    static readonly JsonSerializerOptions CacheOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public static UsageIndex LoadIndex(string cachePath) => Merge(LoadCache(cachePath));

    public static UsageIndex Scan(string home, string cachePath)
    {
        var previous = LoadCache(cachePath);
        var next = new Dictionary<string, UsageFileRecord>(StringComparer.Ordinal);
        var dirty = false;
        foreach (var file in EnumerateLogs(home))
        {
            FileInfo info;
            try
            {
                info = new FileInfo(file);
            }
            catch (Exception)
            {
                continue;
            }

            if (!info.Exists)
            {
                continue;
            }

            var key = info.FullName;
            if (previous.TryGetValue(key, out var cached)
                && cached.Size == info.Length
                && Math.Abs((cached.ModifiedAt - info.LastWriteTimeUtc).TotalSeconds) < 1)
            {
                next[key] = cached;
                continue;
            }

            var piece = new UsageIndex();
            IngestFile(file, piece);
            next[key] = new UsageFileRecord
            {
                ModifiedAt = info.LastWriteTimeUtc,
                Size = info.Length,
                Skills = new Dictionary<string, UsageStat>(piece.Skills, StringComparer.OrdinalIgnoreCase),
                Prompts = new Dictionary<string, UsageStat>(piece.Prompts, StringComparer.OrdinalIgnoreCase)
            };
            dirty = true;
        }

        if (next.Count != previous.Count)
        {
            dirty = true;
        }

        if (dirty)
        {
            SaveCache(cachePath, next);
        }

        return Merge(next);
    }

    static IEnumerable<string> EnumerateLogs(string home)
    {
        foreach (var root in new[]
                 {
                     Path.Combine(home, ".cursor", "projects"),
                     Path.Combine(home, ".claude", "projects"),
                     Path.Combine(home, ".codex", "sessions")
                 })
        {
            if (!Directory.Exists(root))
            {
                continue;
            }

            IEnumerable<string> files;
            try
            {
                files = Directory.EnumerateFiles(root, "*.jsonl", SearchOption.AllDirectories);
            }
            catch (Exception)
            {
                continue;
            }

            foreach (var file in files)
            {
                var normalized = file.Replace('\\', '/');
                if (normalized.Contains("/.cursor/", StringComparison.OrdinalIgnoreCase)
                    && !normalized.Contains("/agent-transcripts/", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                yield return file;
            }
        }
    }

    static UsageIndex Merge(Dictionary<string, UsageFileRecord> files)
    {
        var index = new UsageIndex();
        foreach (var record in files.Values)
        {
            var piece = new UsageIndex();
            foreach (var (key, stat) in record.Skills)
            {
                piece.Skills[key] = stat;
            }

            foreach (var (key, stat) in record.Prompts)
            {
                piece.Prompts[key] = stat;
            }

            index.Merge(piece);
        }

        return index;
    }

    static Dictionary<string, UsageFileRecord> LoadCache(string path)
    {
        try
        {
            if (!File.Exists(path))
            {
                return new Dictionary<string, UsageFileRecord>(StringComparer.Ordinal);
            }

            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<UsageFileCache>(json, CacheOptions)?.Files
                   ?? new Dictionary<string, UsageFileRecord>(StringComparer.Ordinal);
        }
        catch (Exception)
        {
            return new Dictionary<string, UsageFileRecord>(StringComparer.Ordinal);
        }
    }

    static void SaveCache(string path, Dictionary<string, UsageFileRecord> files)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            var json = JsonSerializer.Serialize(new UsageFileCache { Files = files }, CacheOptions);
            PathUtil.WriteAtomic(path, json);
        }
        catch (Exception)
        {
            // Cache is optional; the next scan can rebuild it.
        }
    }

    public static void IngestLine(string line, DateTime fileDate, UsageIndex index)
    {
        if (!line.Contains("SKILL.md", StringComparison.Ordinal)
            && !line.Contains("\"Skill\"", StringComparison.Ordinal)
            && !line.Contains("library/prompts", StringComparison.Ordinal)
            && !line.Contains(".codex/prompts", StringComparison.Ordinal))
        {
            return;
        }

        try
        {
            using var doc = JsonDocument.Parse(line);
            Walk(doc.RootElement, DateOf(doc.RootElement) ?? fileDate, index);
        }
        catch (JsonException)
        {
            RecordPaths(line, fileDate, index);
        }
    }

    static void IngestFile(string path, UsageIndex index)
    {
        DateTime stamp;
        try
        {
            stamp = File.GetLastWriteTime(path);
        }
        catch (Exception)
        {
            return;
        }

        IEnumerable<string> lines;
        try
        {
            lines = File.ReadLines(path);
        }
        catch (Exception)
        {
            return;
        }

        foreach (var line in lines)
        {
            IngestLine(line, stamp, index);
        }
    }

    static void Walk(JsonElement value, DateTime date, UsageIndex index)
    {
        switch (value.ValueKind)
        {
            case JsonValueKind.Object:
                if (Consider(value, date, index))
                {
                    return;
                }

                foreach (var property in value.EnumerateObject())
                {
                    Walk(property.Value, date, index);
                }

                break;
            case JsonValueKind.Array:
                foreach (var item in value.EnumerateArray())
                {
                    Walk(item, date, index);
                }

                break;
        }
    }

    static bool Consider(JsonElement dictionary, DateTime date, UsageIndex index)
    {
        var type = dictionary.TryGetProperty("type", out var typeEl) && typeEl.ValueKind == JsonValueKind.String
            ? typeEl.GetString()
            : null;
        if (type is "tool_result" or "function_call_output")
        {
            return true;
        }

        var hasName = dictionary.TryGetProperty("name", out var nameEl) && nameEl.ValueKind == JsonValueKind.String;
        var hasInput = dictionary.TryGetProperty("input", out _) || dictionary.TryGetProperty("arguments", out _);
        var isCall = type is "tool_use" or "function_call" or "custom_tool_call" || hasName && hasInput;
        if (!isCall || !hasName)
        {
            return false;
        }

        var name = nameEl.GetString() ?? "";
        if (SkipTools.Contains(name))
        {
            return true;
        }

        JsonElement input = default;
        var gotInput = dictionary.TryGetProperty("input", out input) || dictionary.TryGetProperty("arguments", out input);

        if (SkillTools.Contains(name))
        {
            if (gotInput && SkillName(input) is { } skill)
            {
                index.AddSkill(skill, date);
            }

            return true;
        }

        if (ReadTools.Contains(name))
        {
            if (gotInput && PathFrom(input) is { } path)
            {
                RecordPaths(path, date, index);
            }

            return true;
        }

        if (name.Equals("exec", StringComparison.OrdinalIgnoreCase)
            || name.Equals("exec_command", StringComparison.OrdinalIgnoreCase)
            || name.Equals("bash", StringComparison.OrdinalIgnoreCase)
            || name.Equals("shell", StringComparison.OrdinalIgnoreCase))
        {
            if (gotInput && StringFrom(input) is { } text)
            {
                RecordPaths(text, date, index);
            }

            return true;
        }

        return false;
    }

    static string? SkillName(JsonElement input)
    {
        if (input.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        foreach (var key in new[] { "skill", "name", "skill_name", "skillName" })
        {
            if (input.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String)
            {
                var text = value.GetString();
                if (!string.IsNullOrWhiteSpace(text))
                {
                    return text;
                }
            }
        }

        return null;
    }

    static string? PathFrom(JsonElement input)
    {
        if (input.ValueKind == JsonValueKind.Object)
        {
            foreach (var key in new[] { "path", "file_path", "filePath", "target_file", "targetFile" })
            {
                if (input.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String)
                {
                    var text = value.GetString();
                    if (!string.IsNullOrWhiteSpace(text))
                    {
                        return text;
                    }
                }
            }
        }

        return StringFrom(input);
    }

    static string? StringFrom(JsonElement input) => input.ValueKind switch
    {
        JsonValueKind.String => input.GetString(),
        JsonValueKind.Object when input.TryGetProperty("command", out var command) => command.GetString(),
        JsonValueKind.Object when input.TryGetProperty("cmd", out var cmd) => cmd.GetString(),
        JsonValueKind.Object when input.TryGetProperty("input", out var nested) => nested.GetString(),
        _ => null
    };

    public static void RecordPaths(string text, DateTime date, UsageIndex index)
    {
        foreach (Match match in SkillPath.Matches(text))
        {
            index.AddSkill(match.Groups[1].Value, date);
        }

        foreach (Match match in PromptPath.Matches(text))
        {
            index.AddPrompt(match.Groups[1].Value, date);
        }
    }

    static DateTime? DateOf(JsonElement value)
    {
        if (value.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        if (value.TryGetProperty("timestamp", out var stamp) && stamp.ValueKind == JsonValueKind.String
            && DateTime.TryParse(stamp.GetString(), out var parsed))
        {
            return parsed.ToLocalTime();
        }

        if (value.TryGetProperty("payload", out var payload))
        {
            return DateOf(payload);
        }

        if (value.TryGetProperty("message", out var message))
        {
            return DateOf(message);
        }

        return null;
    }
}

sealed class UsageFileCache
{
    public Dictionary<string, UsageFileRecord> Files { get; set; } = new(StringComparer.Ordinal);
}

sealed class UsageFileRecord
{
    public DateTime ModifiedAt { get; set; }
    public long Size { get; set; }
    public Dictionary<string, UsageStat> Skills { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, UsageStat> Prompts { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
