namespace SkillHub.Core;

public enum ToolSource
{
    CursorUser,
    CursorBuiltin,
    Claude,
    Codex,
    Agents,
    Proma,
    PromptLibrary,
    CodexPrompts,
    Custom
}

public static class ToolSourceInfo
{
    public static readonly ToolSource[] SkillRoots =
    [
        ToolSource.CursorUser,
        ToolSource.CursorBuiltin,
        ToolSource.Claude,
        ToolSource.Codex,
        ToolSource.Agents,
        ToolSource.Proma
    ];

    public static string Title(this ToolSource source) => source switch
    {
        ToolSource.CursorUser => "Cursor",
        ToolSource.CursorBuiltin => "Cursor 内置",
        ToolSource.Claude => "Claude",
        ToolSource.Codex => "Codex",
        ToolSource.Agents => "Agents",
        ToolSource.Proma => "Proma",
        ToolSource.PromptLibrary => "Skill Hub 库",
        ToolSource.CodexPrompts => "Codex Prompts",
        ToolSource.Custom => "自定义",
        _ => source.ToString()
    };

    public static string Glyph(this ToolSource source) => source switch
    {
        ToolSource.CursorUser => "◎",
        ToolSource.CursorBuiltin => "◌",
        ToolSource.Claude => "✶",
        ToolSource.Codex => "</>",
        ToolSource.Agents => "👥",
        ToolSource.Proma => "✦",
        ToolSource.PromptLibrary => "▤",
        ToolSource.CodexPrompts => "❝",
        _ => "📁"
    };

    public static bool IsWritable(this ToolSource source) => source != ToolSource.CursorBuiltin;

    public static bool IsSkillRoot(this ToolSource source) => source switch
    {
        ToolSource.CursorUser or ToolSource.CursorBuiltin or ToolSource.Claude
            or ToolSource.Codex or ToolSource.Agents or ToolSource.Proma => true,
        _ => false
    };

    public static string TintHex(this ToolSource source) => source switch
    {
        ToolSource.CursorUser => "#0A84FF",
        ToolSource.CursorBuiltin => "#8E8E93",
        ToolSource.Claude => "#FF9F0A",
        ToolSource.Codex => "#30D158",
        ToolSource.Agents => "#5E5CE6",
        ToolSource.Proma => "#FF375F",
        ToolSource.PromptLibrary => "#A2845E",
        ToolSource.CodexPrompts => "#64D2FF",
        _ => "#8E8E93"
    };
}
