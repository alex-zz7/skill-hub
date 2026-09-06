namespace SkillHub.Core;

public enum HubErrorKind
{
    AccessDenied,
    PathNotAllowed,
    BuiltinReadOnly,
    AlreadyExists,
    NotFound,
    InvalidName,
    LastEntity,
    Io
}

public readonly record struct HubError(HubErrorKind Kind, string Message, string? Detail = null)
{
    public static HubError AccessDenied() =>
        new(HubErrorKind.AccessDenied, "没有拿到主目录的访问权限。");

    public static HubError PathNotAllowed(string path) =>
        new(HubErrorKind.PathNotAllowed, $"路径不在允许的根目录内：{path}", path);

    public static HubError BuiltinReadOnly() =>
        new(HubErrorKind.BuiltinReadOnly, "Cursor 内置 skill 只读，不能修改。");

    public static HubError AlreadyExists(string name) =>
        new(HubErrorKind.AlreadyExists, $"「{name}」已经存在。", name);

    public static HubError NotFound() =>
        new(HubErrorKind.NotFound, "找不到这个文件。");

    public static HubError InvalidName() =>
        new(HubErrorKind.InvalidName, "名字只能用小写字母、数字和连字符，最多 64 个字符。");

    public static HubError LastEntity() =>
        new(HubErrorKind.LastEntity, "这是最后一份实体文件，不能只当作链接移除。");

    public static HubError Io(string message) =>
        new(HubErrorKind.Io, message);
}

public sealed class HubException : Exception
{
    public HubError Error { get; }

    public HubException(HubError error) : base(error.Message)
    {
        Error = error;
    }
}
