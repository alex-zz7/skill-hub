using System.Diagnostics;

namespace SkillHub.Core;

/// Creates directory links. Prefers a real symlink; on Windows without Developer Mode
/// falls back to a junction so install-to-other-tools still works without admin.
public static class FileLinks
{
    public static void CreateDirectoryLink(string linkPath, string targetPath)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(linkPath)!);
        try
        {
            Directory.CreateSymbolicLink(linkPath, targetPath);
            return;
        }
        catch (Exception ex) when (OperatingSystem.IsWindows() && ex is IOException or UnauthorizedAccessException)
        {
            CreateJunction(linkPath, targetPath);
        }
    }

    static void CreateJunction(string linkPath, string targetPath)
    {
        if (Directory.Exists(linkPath) || File.Exists(linkPath))
        {
            throw new HubException(HubError.AlreadyExists(Path.GetFileName(linkPath)));
        }

        var start = new ProcessStartInfo
        {
            FileName = "cmd.exe",
            Arguments = $"/c mklink /J \"{linkPath}\" \"{targetPath}\"",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardError = true,
            RedirectStandardOutput = true
        };
        using var process = Process.Start(start) ?? throw new HubException(HubError.Io("无法创建目录联接。"));
        process.WaitForExit();
        if (process.ExitCode != 0)
        {
            var error = process.StandardError.ReadToEnd();
            throw new HubException(HubError.Io(string.IsNullOrWhiteSpace(error)
                ? "无法创建目录联接。请在 Windows 设置里打开「开发人员模式」后再用符号链接。"
                : error.Trim()));
        }
    }
}
