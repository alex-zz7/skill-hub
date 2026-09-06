import Foundation

/// Every filesystem location Skill Hub reads or writes, derived from one home directory so the
/// same code works against the real home in the app and a temporary folder in tests.
nonisolated struct HubPaths: Sendable, Equatable {
    let home: URL

    init(home: URL) {
        self.home = home.standardizedFileURL
    }

    static let ignoreNames: Set<String> = [
        "node_modules", ".git", ".raw", "vendor_imports", ".tmp",
        "plugins.bak", "dist", ".DS_Store", "DerivedData", "build",
        "test-results", "comparison-results"
    ]

    /// User-visible content root. Prompts and archives live here so other tools can reach them.
    var contentRoot: URL { home.appending(path: ".skill-hub", directoryHint: .isDirectory) }
    var archiveRoot: URL { contentRoot.appending(path: "archive", directoryHint: .isDirectory) }
    var promptLibrary: URL { contentRoot.appending(path: "library/prompts", directoryHint: .isDirectory) }
    /// Location of the metadata file before it moved into the app container.
    var legacyMetaFile: URL { contentRoot.appending(path: "meta.json") }

    func skillRoot(_ source: ToolSource) -> URL? {
        let relative: String? = switch source {
        case .cursorUser: ".cursor/skills"
        case .cursorBuiltin: ".cursor/skills-cursor"
        case .claude: ".claude/skills"
        case .codex: ".codex/skills"
        case .agents: ".agents/skills"
        case .proma: ".proma/default-skills"
        case .promptLibrary, .codexPrompts, .custom: nil
        }
        return relative.map { home.appending(path: $0, directoryHint: .isDirectory) }
    }

    func promptRoot(_ source: ToolSource) -> URL? {
        switch source {
        case .promptLibrary: promptLibrary
        case .codexPrompts: home.appending(path: ".codex/prompts", directoryHint: .isDirectory)
        default: nil
        }
    }

    func isBuiltinPath(_ path: String) -> Bool {
        guard let builtin = skillRoot(.cursorBuiltin) else { return false }
        let prefix = builtin.standardizedFileURL.path
        return path == prefix || path.hasPrefix(prefix + "/")
    }

    func ensureContentDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: promptLibrary, withIntermediateDirectories: true)
        try fm.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
    }

    /// `.cursor/skills` and `.claude/skills` folders inside each project under `~/Projects`.
    func projectSkillRoots() -> [URL] {
        let fm = FileManager.default
        var seen = Set<String>()
        var roots: [URL] = []
        for folderName in ["Projects", "projects"] {
            let projects = home.appending(path: folderName, directoryHint: .isDirectory)
            guard let children = try? fm.contentsOfDirectory(
                at: projects,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for child in children {
                for relative in [".cursor/skills", ".claude/skills"] {
                    let candidate = child.appending(path: relative, directoryHint: .isDirectory)
                    let real = Self.realPath(candidate)
                    guard fm.fileExists(atPath: candidate.path), seen.insert(real).inserted else { continue }
                    roots.append(candidate)
                }
            }
        }
        return roots
    }

    /// Roots the app is allowed to modify. Anything outside is refused before touching disk.
    func writableRoots(options: ScanOptions) -> [String] {
        var roots = ToolSource.skillRoots.compactMap { skillRoot($0)?.standardizedFileURL.path }
        roots.append(contentRoot.standardizedFileURL.path)
        roots.append(contentsOf: options.customPromptRoots.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        if let codex = promptRoot(.codexPrompts) {
            roots.append(codex.standardizedFileURL.path)
        }
        if options.scanProjectSkills {
            roots.append(contentsOf: projectSkillRoots().map { $0.standardizedFileURL.path })
        }
        return roots
    }

    static func standardizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    static func realPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
