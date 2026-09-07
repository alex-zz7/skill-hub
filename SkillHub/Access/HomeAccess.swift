import AppKit
import Foundation
import Observation
import os

/// Holds the sandbox permission for the user's home directory. The app cannot see `~/.cursor`,
/// `~/.claude` and friends until the user picks their home folder once; the resulting
/// security-scoped bookmark is stored in UserDefaults and re-opened on every launch.
@Observable
final class HomeAccess {
    enum Status: Equatable {
        case restoring
        case needsGrant
        case granted(URL)
    }

    private(set) var status: Status = .restoring
    private(set) var lastError: String?

    private let defaults: UserDefaults
    private let bookmarkKey = "homeBookmark"
    @ObservationIgnored private var accessedURL: URL?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isGranted: Bool {
        if case .granted = status { return true }
        return false
    }

    /// The user's real home even inside the sandbox, where `homeDirectoryForCurrentUser` reports the container.
    static var realHome: URL {
        if let record = getpwuid(getuid()), let dir = record.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    func restore() {
        guard let data = defaults.data(forKey: bookmarkKey) else {
            status = .needsGrant
            return
        }
        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
            try startAccessing(url)
            if stale { try persist(url) }
            status = .granted(url)
        } catch {
            Logger.access.error("Could not restore home bookmark: \(error.localizedDescription, privacy: .public)")
            status = .needsGrant
        }
    }

    func requestGrant() {
        let expected = Self.realHome
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = true
        panel.directoryURL = expected
        let home = expected.path
        panel.title = String(localized: "授权访问主目录")
        panel.message = String(localized: "Skill Hub 需要读写 \(home) 下的 .cursor、.claude、.codex、.agents 等文件夹。已为你定位到主目录，直接点「授权」即可。")
        panel.prompt = String(localized: "授权")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        adopt(url)
    }

    func revoke() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        defaults.removeObject(forKey: bookmarkKey)
        status = .needsGrant
    }

    private func adopt(_ url: URL) {
        let picked = url.resolvingSymlinksInPath().standardizedFileURL.path
        let expected = Self.realHome.resolvingSymlinksInPath().standardizedFileURL.path
        guard picked == expected else {
            lastError = String(localized: "需要选择你的用户主目录 \(expected)，而不是 \(picked)。")
            return
        }
        do {
            try persist(url)
            try startAccessing(url)
            lastError = nil
            status = .granted(url)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func startAccessing(_ url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else { throw HubError.accessDenied }
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = url
    }

    private func persist(_ url: URL) throws {
        let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: bookmarkKey)
    }
}
