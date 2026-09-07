import Foundation

/// Counts agent invocations by reading Cursor, Claude, and Codex session transcripts.
/// Cursor/Codex use a skill by reading `SKILL.md`; Claude also has a dedicated `Skill` tool.
nonisolated enum UsageLog {
    /// Compiled once; Regex is not Sendable but these values are immutable after init.
    nonisolated(unsafe) private static let skillPath = try! Regex(#"(?:skills|skills-cursor|default-skills)/([A-Za-z0-9][A-Za-z0-9._-]{0,80})/SKILL\.md"#)
    nonisolated(unsafe) private static let promptPath = try! Regex(#"(?:\.codex/prompts|\.skill-hub/library/prompts)/([A-Za-z0-9][A-Za-z0-9._-]{0,80})\.md"#)

    private static let readTools: Set<String> = ["read", "read_file", "readfile", "view"]
    private static let skillTools: Set<String> = ["skill"]
    private static let skipTools: Set<String> = [
        "grep", "glob", "search", "write", "strreplace", "edit", "delete",
        "todowrite", "websearch", "webfetch"
    ]

    static func loadIndex(cacheURL: URL) -> UsageIndex {
        merge(loadCache(cacheURL))
    }

    /// Reuses per-file cache entries when mtime and size are unchanged. First run is slow; later ones are a directory walk.
    static func scan(home: URL, cacheURL: URL) -> UsageIndex {
        let previous = loadCache(cacheURL)
        var next: [String: UsageFileRecord] = [:]
        next.reserveCapacity(previous.count)
        var dirty = false
        let fm = FileManager.default
        for root in roots(home: home) where fm.fileExists(atPath: root.path) {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            while let url = enumerator.nextObject() as? URL {
                guard url.pathExtension == "jsonl" else { continue }
                let path = url.path
                if path.contains("/.cursor/") && !path.contains("/agent-transcripts/") { continue }
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let mtime = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
                let size = values?.fileSize ?? 0
                let key = url.standardizedFileURL.path
                if let cached = previous[key], abs(cached.modifiedAt - mtime) < 1, cached.size == size {
                    next[key] = cached
                    continue
                }
                var piece = UsageIndex()
                ingest(file: url, fileDate: Date(timeIntervalSince1970: mtime), into: &piece)
                next[key] = UsageFileRecord(modifiedAt: mtime, size: size, skills: piece.skills, prompts: piece.prompts)
                dirty = true
            }
        }
        if next.count != previous.count { dirty = true }
        if dirty { saveCache(next, to: cacheURL) }
        return merge(next)
    }

    private static func roots(home: URL) -> [URL] {
        [
            home.appending(path: ".cursor/projects", directoryHint: .isDirectory),
            home.appending(path: ".claude/projects", directoryHint: .isDirectory),
            home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
        ]
    }

    private static func merge(_ files: [String: UsageFileRecord]) -> UsageIndex {
        var index = UsageIndex()
        for record in files.values {
            var piece = UsageIndex()
            piece.skills = record.skills
            piece.prompts = record.prompts
            index.merge(piece)
        }
        return index
    }

    private static func loadCache(_ url: URL) -> [String: UsageFileRecord] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(UsageFileCache.self, from: data))?.files ?? [:]
    }

    private static func saveCache(_ files: [String: UsageFileRecord], to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(UsageFileCache(files: files)) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func ingest(file url: URL, fileDate: Date, into index: inout UsageIndex) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        for line in text.split(whereSeparator: \.isNewline) {
            ingest(line: String(line), fileDate: fileDate, into: &index)
        }
    }

    static func ingest(line: String, fileDate: Date, into index: inout UsageIndex) {
        if !line.contains("SKILL.md")
            && !line.contains("\"Skill\"")
            && !line.contains("library/prompts")
            && !line.contains(".codex/prompts")
        {
            return
        }
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else {
            recordPaths(in: line, at: fileDate, into: &index)
            return
        }
        walk(object, at: date(in: object) ?? fileDate, into: &index)
    }

    private static func walk(_ value: Any, at date: Date, into index: inout UsageIndex) {
        if let dictionary = value as? [String: Any] {
            if consider(dictionary, at: date, into: &index) { return }
            for nested in dictionary.values { walk(nested, at: date, into: &index) }
        } else if let array = value as? [Any] {
            for nested in array { walk(nested, at: date, into: &index) }
        }
    }

    /// Returns true when this object is a tool call we already handled (do not walk children).
    private static func consider(_ dictionary: [String: Any], at date: Date, into index: inout UsageIndex) -> Bool {
        let type = (dictionary["type"] as? String)?.lowercased()
        if type == "tool_result" || type == "function_call_output" { return true }

        let isCall = type == "tool_use" || type == "function_call" || type == "custom_tool_call"
            || dictionary["name"] != nil && dictionary["input"] != nil
        guard isCall, let name = dictionary["name"] as? String else { return false }

        let folded = name.lowercased()
        if skipTools.contains(folded) { return true }

        let input = dictionary["input"] ?? dictionary["arguments"]
        if skillTools.contains(folded) {
            if let skill = skillName(fromInput: input) {
                index.addSkill(skill, at: date)
            }
            return true
        }
        if readTools.contains(folded) {
            if let path = path(fromInput: input) {
                recordPaths(in: path, at: date, into: &index)
            }
            return true
        }
        if folded == "exec" || folded == "exec_command" || folded == "bash" || folded == "shell" {
            if let text = string(from: input) {
                recordPaths(in: text, at: date, into: &index)
            }
            return true
        }
        return false
    }

    private static func skillName(fromInput input: Any?) -> String? {
        if let dictionary = input as? [String: Any] {
            for key in ["skill", "name", "skill_name", "skillName"] {
                if let value = dictionary[key] as? String, !value.isEmpty { return value }
            }
        }
        return nil
    }

    private static func path(fromInput input: Any?) -> String? {
        if let dictionary = input as? [String: Any] {
            for key in ["path", "file_path", "filePath", "target_file", "targetFile"] {
                if let value = dictionary[key] as? String, !value.isEmpty { return value }
            }
        }
        return string(from: input)
    }

    private static func string(from input: Any?) -> String? {
        switch input {
        case let text as String: text
        case let dictionary as [String: Any]:
            (dictionary["command"] as? String)
                ?? (dictionary["cmd"] as? String)
                ?? (dictionary["input"] as? String)
        default: nil
        }
    }

    static func recordPaths(in text: String, at date: Date, into index: inout UsageIndex) {
        for match in text.matches(of: skillPath) {
            if let name = match.output[1].substring { index.addSkill(String(name), at: date) }
        }
        for match in text.matches(of: promptPath) {
            if let name = match.output[1].substring { index.addPrompt(String(name), at: date) }
        }
    }

    private static func date(in value: Any) -> Date? {
        guard let dictionary = value as? [String: Any] else { return nil }
        if let stamp = dictionary["timestamp"] as? String { return parseDate(stamp) }
        if let nested = dictionary["payload"] { return date(in: nested) }
        if let nested = dictionary["message"] { return date(in: nested) }
        return nil
    }

    private static func parseDate(_ raw: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(raw) { return date }
        return try? Date.ISO8601FormatStyle().parse(raw)
    }
}

nonisolated struct UsageFileRecord: Codable, Sendable, Equatable {
    var modifiedAt: TimeInterval
    var size: Int
    var skills: [String: UsageStat]
    var prompts: [String: UsageStat]
}

nonisolated struct UsageFileCache: Codable, Sendable {
    var files: [String: UsageFileRecord]
}
