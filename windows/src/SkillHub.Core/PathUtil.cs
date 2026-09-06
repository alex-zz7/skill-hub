namespace SkillHub.Core;

/// Path helpers that behave the same on macOS (tests) and Windows (the shipped app).
public static class PathUtil
{
    public static string Standardize(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return path;
        }

        return TrimTrailingSeparators(Path.GetFullPath(path));
    }

    public static string RealPath(string path)
    {
        var full = Standardize(path);
        try
        {
            if (Directory.Exists(full))
            {
                var info = new DirectoryInfo(full);
                var target = info.ResolveLinkTarget(returnFinalTarget: true);
                return Standardize(target?.FullName ?? info.FullName);
            }

            if (File.Exists(full))
            {
                var info = new FileInfo(full);
                var target = info.ResolveLinkTarget(returnFinalTarget: true);
                return Standardize(target?.FullName ?? info.FullName);
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }

        return full;
    }

    public static bool IsSymbolicLink(string path)
    {
        try
        {
            var file = new FileInfo(path);
            if (!string.IsNullOrEmpty(file.LinkTarget))
            {
                return true;
            }

            var directory = new DirectoryInfo(path);
            if (!string.IsNullOrEmpty(directory.LinkTarget))
            {
                return true;
            }

            if (file.Exists || directory.Exists)
            {
                return file.Attributes.HasFlag(FileAttributes.ReparsePoint)
                       || directory.Attributes.HasFlag(FileAttributes.ReparsePoint);
            }
        }
        catch (FileNotFoundException)
        {
        }
        catch (DirectoryNotFoundException)
        {
        }
        catch (IOException)
        {
        }

        return false;
    }

    public static bool Exists(string path)
    {
        return Directory.Exists(path) || File.Exists(path);
    }

    public static bool IsDirectory(string path)
    {
        try
        {
            return Directory.Exists(path);
        }
        catch (IOException)
        {
            return false;
        }
    }

    public static bool IsUnder(string root, string path)
    {
        var r = Standardize(root);
        var p = Standardize(path);
        if (OperatingSystem.IsWindows())
        {
            r = r.ToLowerInvariant();
            p = p.ToLowerInvariant();
        }

        return p == r || p.StartsWith(r + Path.DirectorySeparatorChar, StringComparison.Ordinal);
    }

    public static void WriteAtomic(string path, string text)
    {
        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var tmp = path + ".tmp";
        File.WriteAllText(tmp, text, new System.Text.UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        File.Move(tmp, path, overwrite: true);
    }

    public static DateTime ModificationDate(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                return File.GetLastWriteTime(path);
            }

            if (Directory.Exists(path))
            {
                return Directory.GetLastWriteTime(path);
            }
        }
        catch (IOException)
        {
        }

        return DateTime.MinValue;
    }

    public static IEnumerable<string> ImmediateChildren(string root)
    {
        if (!Directory.Exists(root))
        {
            yield break;
        }

        IEnumerable<string> entries;
        try
        {
            entries = Directory.EnumerateFileSystemEntries(root);
        }
        catch (IOException)
        {
            yield break;
        }
        catch (UnauthorizedAccessException)
        {
            yield break;
        }

        foreach (var entry in entries)
        {
            var name = Path.GetFileName(entry);
            if (name.StartsWith('.') && name is not "." and not "..")
            {
                continue;
            }

            yield return entry;
        }
    }

    static string TrimTrailingSeparators(string path)
    {
        if (path.Length <= 1)
        {
            return path;
        }

        // Keep Windows drive root "C:\" intact.
        var trimmed = path.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        return string.IsNullOrEmpty(trimmed) ? path : trimmed;
    }
}
