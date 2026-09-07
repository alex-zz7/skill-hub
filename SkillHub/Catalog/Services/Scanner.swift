import Foundation

/// Walks every tool's skill folder and builds a deduplicated catalog. Runs on the concurrent pool
/// because a full walk of `~/Projects` can take hundreds of milliseconds.
nonisolated enum Scanner {
    @concurrent
    static func scan(paths: HubPaths, options: ScanOptions) async -> CatalogSnapshot {
        scanSync(paths: paths, options: options)
    }

    static func scanSync(paths: HubPaths, options: ScanOptions) -> CatalogSnapshot {
        let fm = FileManager.default
        var buckets: [String: SkillDraft] = [:]
        var brokenOrphans: [Installation] = []

        for source in ToolSource.skillRoots {
            guard let root = paths.skillRoot(source), fm.fileExists(atPath: root.path) else { continue }
            collectSkills(in: root, source: source, paths: paths, into: &buckets, orphans: &brokenOrphans)
        }

        if options.scanProjectSkills {
            for root in paths.projectSkillRoots() {
                collectSkills(in: root, source: .custom, paths: paths, into: &buckets, orphans: &brokenOrphans)
            }
        }

        var skills = buckets.values.map { $0.finish(paths: paths) }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        markSameNames(&skills)

        var prompts: [PromptItem] = []
        var seenPrompt = Set<String>()

        for skill in skills {
            for prompt in embeddedPrompts(in: skill) where seenPrompt.insert(prompt.canonicalPath).inserted {
                prompts.append(prompt)
            }
        }

        var standaloneRoots: [(ToolSource, URL)] = [(.promptLibrary, paths.promptLibrary)]
        if let codex = paths.promptRoot(.codexPrompts) {
            standaloneRoots.append((.codexPrompts, codex))
        }
        standaloneRoots += options.customPromptRoots.map { (.custom, URL(fileURLWithPath: $0, isDirectory: true)) }

        for (source, root) in standaloneRoots {
            for prompt in standalonePrompts(in: root, source: source) where seenPrompt.insert(prompt.canonicalPath).inserted {
                prompts.append(prompt)
            }
        }

        prompts.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return CatalogSnapshot(skills: skills, prompts: prompts, brokenOrphans: brokenOrphans)
    }

    private struct SkillDraft {
        var canonicalPath: String
        var folderName: String
        var document: FrontmatterDocument
        var skillFilePath: String
        var installations: [Installation]
        var fileCount: Int
        var modifiedAt: Date
        var health: Set<HealthIssue>

        func finish(paths: HubPaths) -> SkillItem {
            var issues = health
            if document.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.insert(.missingDescription)
            }
            if installations.contains(where: \.isBroken) {
                issues.insert(.brokenSymlink)
            }
            let readOnly = installations.allSatisfy { !$0.source.isWritable } || paths.isBuiltinPath(canonicalPath)
            return SkillItem(
                canonicalPath: canonicalPath,
                name: document.name.isEmpty ? folderName : document.name,
                folderName: folderName,
                description: document.description,
                version: document.version,
                skillFilePath: skillFilePath,
                installations: installations.sorted { $0.source.title < $1.source.title },
                fileCount: fileCount,
                modifiedAt: modifiedAt,
                health: issues.sorted { $0.rawValue < $1.rawValue },
                isReadOnly: readOnly,
                author: document.author,
                origin: document.origin
            )
        }
    }

    /// Two folders with the same skill name are not a "duplicate install" (that is one folder, many links);
    /// they are separate copies that may have drifted, which is the case prefix grouping alone cannot show.
    private static func markSameNames(_ skills: inout [SkillItem]) {
        var byName: [String: [Int]] = [:]
        for (index, skill) in skills.enumerated() {
            byName[skill.name.lowercased(), default: []].append(index)
        }
        for indexes in byName.values where indexes.count > 1 {
            for index in indexes {
                skills[index].sameNamePaths = indexes
                    .filter { $0 != index }
                    .map { skills[$0].canonicalPath }
                if !skills[index].health.contains(.sameNameElsewhere) {
                    skills[index].health.append(.sameNameElsewhere)
                    skills[index].health.sort { $0.rawValue < $1.rawValue }
                }
            }
        }
    }

    private static func collectSkills(
        in root: URL,
        source: ToolSource,
        paths: HubPaths,
        into buckets: inout [String: SkillDraft],
        orphans: inout [Installation]
    ) {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for child in children {
            let name = child.lastPathComponent
            if HubPaths.ignoreNames.contains(name) { continue }

            let values = try? child.resourceValues(forKeys: [.isSymbolicLinkKey])
            let isSymlink = values?.isSymbolicLink == true
            var isDirectory: ObjCBool = false
            let exists = fm.fileExists(atPath: child.path, isDirectory: &isDirectory)

            if isSymlink && !exists {
                orphans.append(Installation(source: source, path: HubPaths.standardizedPath(child), isSymlink: true, isBroken: true))
                continue
            }
            if !isDirectory.boolValue { continue }

            let real = URL(fileURLWithPath: HubPaths.realPath(child), isDirectory: true)
            let skillFile = real.appending(path: "SKILL.md")
            let listingPath = HubPaths.standardizedPath(child)
            let canonical = HubPaths.standardizedPath(real)
            let hasSkillFile = fm.fileExists(atPath: skillFile.path)
            let install = Installation(source: source, path: listingPath, isSymlink: isSymlink, isBroken: !hasSkillFile)

            if !hasSkillFile {
                if isSymlink { orphans.append(install) }
                continue
            }

            if var draft = buckets[canonical] {
                if !draft.installations.contains(where: { $0.path == listingPath }) {
                    draft.installations.append(install)
                }
                buckets[canonical] = draft
                continue
            }

            let raw = (try? String(contentsOf: skillFile, encoding: .utf8)) ?? ""
            let modified = (try? skillFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            buckets[canonical] = SkillDraft(
                canonicalPath: canonical,
                folderName: real.lastPathComponent,
                document: Frontmatter.parse(raw),
                skillFilePath: HubPaths.standardizedPath(skillFile),
                installations: [install],
                fileCount: countFiles(in: real),
                modifiedAt: modified,
                health: []
            )
        }
    }

    private static func countFiles(in root: URL) -> Int {
        var count = 0
        enumerate(in: root) { _, isDirectory in
            if !isDirectory { count += 1 }
        }
        return count
    }

    private static func embeddedPrompts(in skill: SkillItem) -> [PromptItem] {
        let root = URL(fileURLWithPath: skill.canonicalPath, isDirectory: true)
        var items: [PromptItem] = []
        enumerate(in: root) { url, isDirectory in
            guard !isDirectory else { return }
            let filename = url.lastPathComponent
            guard filename != "SKILL.md", !filename.hasSuffix(".stderr.txt") else { return }
            let ext = url.pathExtension.lowercased()
            guard ext == "md" || ext == "txt" else { return }
            let inPromptsDir = url.pathComponents.dropLast().contains { $0.lowercased() == "prompts" }
            let nameHit = filename.lowercased().contains("prompt") && ext == "md"
            guard inPromptsDir || nameHit else { return }
            items.append(
                PromptItem(
                    canonicalPath: HubPaths.realPath(url),
                    title: displayTitle(for: url),
                    kind: .embedded,
                    source: skill.installations.first?.source ?? .custom,
                    parentSkillName: skill.name,
                    parentSkillPath: skill.canonicalPath,
                    modifiedAt: modificationDate(of: url) ?? skill.modifiedAt,
                    isReadOnly: skill.isReadOnly
                )
            )
        }
        return items
    }

    private static func standalonePrompts(in root: URL, source: ToolSource) -> [PromptItem] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        var items: [PromptItem] = []
        enumerate(in: root) { url, isDirectory in
            guard !isDirectory, url.lastPathComponent != "SKILL.md" else { return }
            let ext = url.pathExtension.lowercased()
            guard ext == "md" || ext == "txt" else { return }
            items.append(
                PromptItem(
                    canonicalPath: HubPaths.realPath(url),
                    title: displayTitle(for: url),
                    kind: .standalone,
                    source: source,
                    parentSkillName: nil,
                    parentSkillPath: nil,
                    modifiedAt: modificationDate(of: url) ?? .distantPast,
                    isReadOnly: !source.isWritable
                )
            )
        }
        return items
    }

    private static func displayTitle(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ")
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func enumerate(in root: URL, visit: (URL, Bool) -> Void) {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        while let url = enumerator.nextObject() as? URL {
            if HubPaths.ignoreNames.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            visit(url, values?.isDirectory == true)
        }
    }
}
