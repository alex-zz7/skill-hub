import Foundation
import Testing
@testable import SkillHub

/// Builds a throwaway home directory that mimics the real tool folders.
struct TemporaryHome {
    let url: URL
    let paths: HubPaths

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "skillhub-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        paths = HubPaths(home: url)
    }

    func makeSkill(_ source: ToolSource, folder: String, name: String? = nil, description: String = "desc") throws -> URL {
        let root = try #require(paths.skillRoot(source))
        let dir = root.appending(path: folder, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let text = Frontmatter.render(name: name ?? folder, description: description, body: "# \(folder)\n")
        try text.write(to: dir.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)
        return dir
    }

    func link(_ source: ToolSource, folder: String, to target: URL) throws {
        let root = try #require(paths.skillRoot(source))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root.appending(path: folder), withDestinationURL: target)
    }

    func tearDown() {
        try? FileManager.default.removeItem(at: url)
    }
}

struct ScannerTests {
    @Test func dedupesSymlinkedInstallsIntoOneSkill() throws {
        let home = try TemporaryHome()
        defer { home.tearDown() }

        let real = try home.makeSkill(.agents, folder: "blog-write")
        try home.link(.cursorUser, folder: "blog-write", to: real)
        try home.link(.claude, folder: "blog-write", to: real)

        let snapshot = Scanner.scanSync(paths: home.paths, options: ScanOptions())
        #expect(snapshot.skills.count == 1)
        let skill = try #require(snapshot.skills.first)
        #expect(skill.installations.count == 3)
        #expect(skill.symlinkCount == 2)
        #expect(skill.realCount == 1)
        #expect(skill.isDuplicateInstall)
        #expect(skill.health.isEmpty)
        #expect(Set(skill.toolSources) == [.agents, .cursorUser, .claude])
    }

    @Test func reportsBrokenLinksAndMissingDescriptions() throws {
        let home = try TemporaryHome()
        defer { home.tearDown() }

        _ = try home.makeSkill(.claude, folder: "quiet", description: "")
        try home.link(.codex, folder: "gone", to: home.url.appending(path: "nowhere"))

        let snapshot = Scanner.scanSync(paths: home.paths, options: ScanOptions())
        #expect(snapshot.skills.count == 1)
        #expect(snapshot.skills.first?.health == [.missingDescription])
        #expect(snapshot.brokenOrphans.count == 1)
        #expect(snapshot.brokenOrphans.first?.source == .codex)

        let stats = OverviewStats(snapshot: snapshot)
        #expect(stats.missingDescriptions == 1)
        #expect(stats.brokenLinks == 1)
    }

    @Test func builtinSkillsAreReadOnly() throws {
        let home = try TemporaryHome()
        defer { home.tearDown() }

        _ = try home.makeSkill(.cursorBuiltin, folder: "builtin")
        _ = try home.makeSkill(.cursorUser, folder: "mine")

        let snapshot = Scanner.scanSync(paths: home.paths, options: ScanOptions())
        let builtin = try #require(snapshot.skills.first { $0.name == "builtin" })
        let mine = try #require(snapshot.skills.first { $0.name == "mine" })
        #expect(builtin.isReadOnly)
        #expect(!mine.isReadOnly)
    }

    @Test func findsEmbeddedAndStandalonePrompts() throws {
        let home = try TemporaryHome()
        defer { home.tearDown() }

        let skill = try home.makeSkill(.claude, folder: "writer")
        let promptsDir = skill.appending(path: "prompts", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: promptsDir, withIntermediateDirectories: true)
        try "# Outline".write(to: promptsDir.appending(path: "outline.md"), atomically: true, encoding: .utf8)
        try "ignored".write(to: skill.appending(path: "README.md"), atomically: true, encoding: .utf8)

        try home.paths.ensureContentDirectories()
        try "# Standalone".write(to: home.paths.promptLibrary.appending(path: "weekly-report.md"), atomically: true, encoding: .utf8)

        let snapshot = Scanner.scanSync(paths: home.paths, options: ScanOptions())
        #expect(snapshot.prompts.count == 2)
        let embedded = try #require(snapshot.prompts.first { $0.kind == .embedded })
        #expect(embedded.title == "outline")
        #expect(embedded.parentSkillName == "writer")
        let standalone = try #require(snapshot.prompts.first { $0.kind == .standalone })
        #expect(standalone.title == "weekly report")
        #expect(standalone.source == .promptLibrary)
    }

    @Test func projectSkillsOnlyWhenEnabled() throws {
        let home = try TemporaryHome()
        defer { home.tearDown() }

        let project = home.url.appending(path: "Projects/demo/.cursor/skills/local-skill", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try Frontmatter.render(name: "local-skill", description: "d", body: "")
            .write(to: project.appending(path: "SKILL.md"), atomically: true, encoding: .utf8)

        #expect(Scanner.scanSync(paths: home.paths, options: ScanOptions()).skills.isEmpty)
        let enabled = Scanner.scanSync(paths: home.paths, options: ScanOptions(scanProjectSkills: true))
        #expect(enabled.skills.count == 1)
        #expect(enabled.skills.first?.installations.first?.source == .custom)
    }

    @Test func writableRootsExcludeUnrelatedPaths() throws {
        let home = try TemporaryHome()
        defer { home.tearDown() }
        let roots = home.paths.writableRoots(options: ScanOptions())
        #expect(roots.contains(home.paths.contentRoot.path))
        #expect(roots.contains(home.paths.skillRoot(.claude)!.path))
        #expect(!roots.contains(home.url.path))
    }
}
