using System.Text.Json;
using System.Text.Json.Serialization;

namespace SkillHub.Core;

public sealed class MetaStore
{
    static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
    };

    public string FilePath { get; }
    public string UsageCachePath => Path.Combine(Path.GetDirectoryName(FilePath) ?? Path.GetTempPath(), "usage-cache.json");

    public MetaStore(string filePath)
    {
        FilePath = filePath;
    }

    public static MetaStore InApplicationSupport()
    {
        var root = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        if (string.IsNullOrEmpty(root))
        {
            root = Path.GetTempPath();
        }

        return new MetaStore(Path.Combine(root, "Skill Hub", "meta.json"));
    }

    public AppMeta Load(string? legacy = null)
    {
        try
        {
            if (!File.Exists(FilePath) && legacy != null && File.Exists(legacy))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
                File.Copy(legacy, FilePath);
            }

            if (!File.Exists(FilePath))
            {
                return AppMeta.Empty();
            }

            var json = File.ReadAllText(FilePath);
            return JsonSerializer.Deserialize<AppMeta>(json, Options) ?? AppMeta.Empty();
        }
        catch (Exception)
        {
            return AppMeta.Empty();
        }
    }

    public void Save(AppMeta meta)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        var json = JsonSerializer.Serialize(meta, Options);
        PathUtil.WriteAtomic(FilePath, json);
    }
}
