import Foundation

nonisolated struct SkillItem: Identifiable, Hashable, Sendable {
    var id: String { canonicalPath }
    var canonicalPath: String
    var name: String
    var folderName: String
    var description: String
    var version: String
    var skillFilePath: String
    var installations: [Installation]
    var fileCount: Int
    var modifiedAt: Date
    var health: [HealthIssue]
    var isReadOnly: Bool
    var author: String = ""
    var origin: String = ""
    /// Canonical paths of other skills that share this name but are separate folders.
    var sameNamePaths: [String] = []

    var toolSources: [ToolSource] {
        Array(Set(installations.map(\.source))).sorted { $0.title < $1.title }
    }

    var isDuplicateInstall: Bool { installations.count > 1 }
    var symlinkCount: Int { installations.count(where: \.isSymlink) }
    var realCount: Int { installations.count { !$0.isSymlink && !$0.isBroken } }
    var liveInstallCount: Int { installations.count { !$0.isBroken } }

    /// Where this skill came from and how it got into each tool — the "why do I have this" line.
    var originSummary: String {
        var parts: [String] = []
        if installations.contains(where: { $0.source == .cursorBuiltin }) {
            parts.append(String(localized: "Cursor 内置"))
        }
        let real = installations.filter { !$0.isSymlink && !$0.isBroken && $0.source != .cursorBuiltin }.map(\.source.title)
        let linked = installations.filter { $0.isSymlink && !$0.isBroken }.map(\.source.title)
        let separator = String(localized: "、")
        if !real.isEmpty {
            let list = Array(Set(real)).sorted().joined(separator: separator)
            parts.append(String(localized: "实体在 \(list)"))
        }
        if !linked.isEmpty {
            let list = Array(Set(linked)).sorted().joined(separator: separator)
            parts.append(String(localized: "链接到 \(list)"))
        }
        if !author.isEmpty {
            parts.append(String(localized: "作者 \(author)"))
        }
        if let host = Self.originHost(origin) {
            parts.append(host)
        }
        if !sameNamePaths.isEmpty {
            parts.append(String(localized: "另有 \(sameNamePaths.count) 份同名"))
        }
        return parts.joined(separator: " · ")
    }

    private static func originHost(_ origin: String) -> String? {
        let trimmed = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let host = url.host() {
            let path = url.path().split(separator: "/").prefix(2).joined(separator: "/")
            return path.isEmpty ? host : "\(host)/\(path)"
        }
        return String(trimmed.prefix(40))
    }
}
