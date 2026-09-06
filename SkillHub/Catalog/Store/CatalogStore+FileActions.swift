import AppKit
import Foundation

extension CatalogStore {
    // MARK: Saving

    func saveDraft() {
        guard let document = currentDocument else { return }
        do {
            guard !document.isReadOnly else { throw HubError.builtinReadOnly }
            let url = URL(fileURLWithPath: document.filePath)
            try assertAllowed(url)
            try draftText.write(to: url, atomically: true, encoding: .utf8)
            loadedText = draftText
            setStatus("已保存 \(document.title)")
            refresh()
        } catch {
            present(error)
        }
    }

    func discardDraft() {
        draftText = loadedText
        documentMode = .preview
    }

    // MARK: Creating

    func createSkill(name: String, description: String, source: ToolSource) {
        do {
            let slug = Frontmatter.slug(name)
            guard Frontmatter.isValidSkillName(slug) else { throw HubError.invalidName }
            guard source.isWritable, source.isSkillRoot, let root = paths.skillRoot(source) else {
                throw HubError.builtinReadOnly
            }
            let fm = FileManager.default
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let folder = root.appending(path: slug, directoryHint: .isDirectory)
            try assertAllowed(folder)
            if fm.fileExists(atPath: folder.path) { throw HubError.alreadyExists(slug) }
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appending(path: "SKILL.md")
            try Frontmatter.render(name: slug, description: description, body: "")
                .write(to: file, atomically: true, encoding: .utf8)
            activeSheet = nil
            setStatus("已新建 skill「\(slug)」")
            let newID = HubPaths.realPath(folder)
            refresh { [self] in
                sidebarSelection = .skills(.all)
                selectedSkillID = newID
            }
        } catch {
            present(error)
        }
    }

    func createPrompt(title: String, body: String) {
        do {
            try paths.ensureContentDirectories()
            let slug = Frontmatter.slug(title)
            guard !slug.isEmpty else { throw HubError.invalidName }
            let file = paths.promptLibrary.appending(path: "\(slug).md")
            try assertAllowed(file)
            if FileManager.default.fileExists(atPath: file.path) { throw HubError.alreadyExists(slug) }
            let text = "# \(title.trimmingCharacters(in: .whitespacesAndNewlines))\n\n\(body)\n"
            try text.write(to: file, atomically: true, encoding: .utf8)
            activeSheet = nil
            setStatus("已新建 prompt「\(title)」")
            let newID = HubPaths.realPath(file)
            refresh { [self] in
                sidebarSelection = .prompts(.all)
                selectedPromptID = newID
            }
        } catch {
            present(error)
        }
    }

    func savePromptAsStandalone(_ prompt: PromptItem) {
        do {
            try paths.ensureContentDirectories()
            let slug = Frontmatter.slug(prompt.title)
            let dest = paths.promptLibrary.appending(path: "\(slug).md")
            try assertAllowed(dest)
            if FileManager.default.fileExists(atPath: dest.path) { throw HubError.alreadyExists(slug) }
            try FileManager.default.copyItem(at: URL(fileURLWithPath: prompt.canonicalPath), to: dest)
            setStatus("已另存到独立库")
            let newID = HubPaths.realPath(dest)
            refresh { [self] in
                sidebarSelection = .prompts(.all)
                selectedPromptID = newID
            }
        } catch {
            present(error)
        }
    }

    // MARK: Installing

    func availableInstallTargets(for skill: SkillItem) -> [ToolSource] {
        let installed = Set(skill.installations.map(\.source))
        return ToolSource.skillRoots.filter { $0.isWritable && !installed.contains($0) }
    }

    func install(_ skill: SkillItem, to source: ToolSource, asCopy: Bool) {
        do {
            guard source.isWritable, source.isSkillRoot, let root = paths.skillRoot(source) else {
                throw HubError.builtinReadOnly
            }
            let fm = FileManager.default
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let dest = root.appending(path: skill.folderName, directoryHint: .isDirectory)
            try assertAllowed(dest)
            if fm.fileExists(atPath: dest.path) { throw HubError.alreadyExists(skill.folderName) }
            let canonical = URL(fileURLWithPath: skill.canonicalPath, isDirectory: true)
            if asCopy {
                try fm.copyItem(at: canonical, to: dest)
            } else {
                try fm.createSymbolicLink(at: dest, withDestinationURL: canonical)
            }
            activeSheet = nil
            setStatus(asCopy ? "已复制到 \(source.title)" : "已链接到 \(source.title)")
            refresh()
        } catch {
            present(error)
        }
    }

    // MARK: Deduplicating

    func dedupe(_ skill: SkillItem, keeping keep: Installation) {
        do {
            try applyDedupe(skill: skill, keep: keep)
            activeSheet = nil
            setStatus("已只保留 \(keep.source.title) 里的「\(skill.name)」")
            refresh()
        } catch {
            present(error)
        }
    }

    func dedupeAll(policy: DedupePolicy) {
        let targets = duplicateSkills
        guard !targets.isEmpty else {
            activeSheet = nil
            return
        }
        var succeeded = 0
        var failed = 0
        var lastFailure: (any Error)?
        for skill in targets {
            guard let keep = installationToKeep(for: skill, policy: policy) else { continue }
            do {
                try applyDedupe(skill: skill, keep: keep)
                succeeded += 1
            } catch {
                failed += 1
                lastFailure = error
            }
        }
        activeSheet = nil
        if let lastFailure, failed > 0 {
            setStatus("去重完成 \(succeeded) 个，失败 \(failed) 个")
            present(lastFailure)
        } else {
            setStatus("已去重 \(succeeded) 个 skill")
        }
        refresh()
    }

    private func installationToKeep(for skill: SkillItem, policy: DedupePolicy) -> Installation? {
        switch policy {
        case .keepEntity:
            skill.installations.first { !$0.isSymlink && $0.source.isWritable }
                ?? skill.installations.first { !$0.isSymlink }
                ?? skill.installations.first { $0.source.isWritable }
        case .prefer(let source):
            skill.installations.first { $0.source == source }
                ?? installationToKeep(for: skill, policy: .keepEntity)
        }
    }

    private func applyDedupe(skill: SkillItem, keep: Installation) throws {
        let fm = FileManager.default
        let keepURL = URL(fileURLWithPath: keep.path, isDirectory: true)
        if keep.source.isWritable {
            try assertAllowed(keepURL)
        }

        for install in skill.installations where install.path != keep.path && install.source.isWritable {
            if install.isSymlink {
                try removeInstall(at: install.path, expectSymlink: true)
                continue
            }
            let real = HubPaths.realPath(URL(fileURLWithPath: install.path, isDirectory: true))
            if real == skill.canonicalPath { continue }
            let url = URL(fileURLWithPath: install.path, isDirectory: true)
            try assertAllowed(url)
            try fm.removeItem(at: url)
        }

        // If the survivor is itself a symlink, swap in the real folder so nothing dangles.
        let keptIsSymlink = (try? keepURL.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
        if keptIsSymlink, keep.source.isWritable {
            try removeInstall(at: keep.path, expectSymlink: true)
            let canonical = URL(fileURLWithPath: skill.canonicalPath, isDirectory: true)
            if HubPaths.standardizedPath(canonical) != HubPaths.standardizedPath(keepURL) {
                try assertAllowed(canonical)
                if fm.fileExists(atPath: keepURL.path) {
                    try fm.removeItem(at: keepURL)
                }
                try fm.moveItem(at: canonical, to: keepURL)
            }
        }
    }

    // MARK: Confirmed actions

    func request(_ action: ConfirmAction) {
        pendingConfirm = action
        isShowingConfirm = true
    }

    func requestDelete(_ document: DocumentRef) {
        switch document {
        case .skill(let skill):
            request(.deleteSkill(skillID: skill.id, isLastEntity: skill.realCount <= 1))
        case .prompt(let prompt):
            request(.deletePrompt(promptID: prompt.id, isLastEntity: prompt.kind == .standalone))
        }
    }

    func requestArchive(_ document: DocumentRef) {
        switch document {
        case .skill(let skill): request(.archiveSkill(skillID: skill.id))
        case .prompt(let prompt): request(.archivePrompt(promptID: prompt.id))
        }
    }

    func perform(_ action: ConfirmAction) {
        do {
            switch action {
            case .removeInstall(_, let path, let isSymlink):
                try removeInstall(at: path, expectSymlink: isSymlink)
                setStatus(isSymlink ? "已移除符号链接" : "已移除该安装")
            case .deleteSkill(let id, _):
                try deleteSkillEntity(id)
                selectedSkillID = nil
                setStatus("已删除 skill")
            case .deletePrompt(let id, _):
                try deletePrompt(id)
                selectedPromptID = nil
                setStatus("已删除 prompt")
            case .archiveSkill(let id):
                try archiveSkill(id)
                selectedSkillID = nil
                setStatus("已归档 skill")
            case .archivePrompt(let id):
                try archivePrompt(id)
                selectedPromptID = nil
                setStatus("已归档 prompt")
            }
            pendingConfirm = nil
            isShowingConfirm = false
            refresh()
        } catch {
            pendingConfirm = nil
            isShowingConfirm = false
            present(error)
        }
    }

    func reveal(_ document: DocumentRef) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: document.revealPath)])
    }

    func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: Filesystem primitives

    private func removeInstall(at path: String, expectSymlink: Bool) throws {
        let url = URL(fileURLWithPath: path)
        try assertAllowed(url)
        let isSymlink = (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true
        if expectSymlink && !isSymlink { throw HubError.lastEntity }
        try FileManager.default.removeItem(at: url)
    }

    private func deleteSkillEntity(_ id: String) throws {
        guard let skill = skills.first(where: { $0.id == id }) else { throw HubError.notFound }
        for install in skill.installations where install.isSymlink {
            try? removeInstall(at: install.path, expectSymlink: true)
        }
        let canonical = URL(fileURLWithPath: skill.canonicalPath, isDirectory: true)
        try assertAllowed(canonical)
        try FileManager.default.removeItem(at: canonical)
    }

    private func archiveSkill(_ id: String) throws {
        guard let skill = skills.first(where: { $0.id == id }) else { throw HubError.notFound }
        try paths.ensureContentDirectories()
        for install in skill.installations where install.isSymlink {
            try? removeInstall(at: install.path, expectSymlink: true)
        }
        let dest = paths.archiveRoot.appending(path: "\(archiveStamp())-\(skill.folderName)", directoryHint: .isDirectory)
        let canonical = URL(fileURLWithPath: skill.canonicalPath, isDirectory: true)
        try assertAllowed(canonical)
        try FileManager.default.moveItem(at: canonical, to: dest)
        mutateMeta { meta in
            meta.archiveLog.insert(
                ArchiveRecord(originalPath: skill.canonicalPath, archivePath: dest.path, name: skill.name, date: .now),
                at: 0
            )
        }
    }

    private func deletePrompt(_ id: String) throws {
        guard let prompt = prompts.first(where: { $0.id == id }) else { throw HubError.notFound }
        let url = URL(fileURLWithPath: prompt.canonicalPath)
        try assertAllowed(url)
        try FileManager.default.removeItem(at: url)
    }

    private func archivePrompt(_ id: String) throws {
        guard let prompt = prompts.first(where: { $0.id == id }) else { throw HubError.notFound }
        try paths.ensureContentDirectories()
        let url = URL(fileURLWithPath: prompt.canonicalPath)
        let dest = paths.archiveRoot.appending(path: "\(archiveStamp())-\(url.lastPathComponent)")
        try assertAllowed(url)
        try FileManager.default.moveItem(at: url, to: dest)
        mutateMeta { meta in
            meta.archiveLog.insert(
                ArchiveRecord(originalPath: prompt.canonicalPath, archivePath: dest.path, name: prompt.title, date: .now),
                at: 0
            )
        }
    }

    private func archiveStamp() -> String {
        Date.now.formatted(
            .verbatim(
                "\(year: .defaultDigits)\(month: .twoDigits)\(day: .twoDigits)-\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)\(second: .twoDigits)",
                timeZone: .current,
                calendar: .current
            )
        )
    }

    /// Refuses to touch anything outside the tool folders and the app's own content root.
    private func assertAllowed(_ url: URL) throws {
        let path = url.standardizedFileURL.path
        if paths.isBuiltinPath(path) { throw HubError.builtinReadOnly }
        let allowed = paths.writableRoots(options: scanOptions).contains { root in
            path == root || path.hasPrefix(root + "/")
        }
        if !allowed { throw HubError.pathNotAllowed(path) }
    }
}
