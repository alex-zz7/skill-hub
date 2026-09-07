import Foundation
import os

/// Persists `AppMeta` as JSON inside the app's own Application Support folder. Earlier builds kept it
/// at `~/.skill-hub/meta.json`; the first load after upgrading copies that file across.
nonisolated struct MetaStore: Sendable {
    let fileURL: URL
    var usageCacheURL: URL { fileURL.deletingLastPathComponent().appending(path: "usage-cache.json") }

    static func inApplicationSupport() -> MetaStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return MetaStore(fileURL: base.appending(path: "Skill Hub/meta.json"))
    }

    func load(migratingFrom legacy: URL? = nil) -> AppMeta {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path), let legacy, fm.fileExists(atPath: legacy.path) {
            try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.copyItem(at: legacy, to: fileURL)
        }
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(AppMeta.self, from: data)
        } catch {
            Logger.meta.error("Failed to decode meta.json, starting fresh: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    func save(_ meta: AppMeta) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(meta).write(to: fileURL, options: .atomic)
    }
}
