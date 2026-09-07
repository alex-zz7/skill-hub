import Foundation
import Observation
import os

/// Single source of truth for the window: the scanned catalog, user metadata, navigation state,
/// and the document being viewed. Every filesystem mutation goes through here so path checks
/// and refreshes happen in one place.
@Observable
final class CatalogStore {
    let paths: HubPaths
    private let metaStore: MetaStore

    // Catalog
    private(set) var skills: [SkillItem] = []
    private(set) var prompts: [PromptItem] = []
    private(set) var stats = OverviewStats.empty
    private(set) var usage = UsageIndex.empty
    private(set) var meta = AppMeta.empty
    private(set) var isScanning = false
    private(set) var hasLoaded = false

    // Navigation
    var sidebarSelection: SidebarItem? = .skills(.all)
    var selectedSkillID: SkillItem.ID?
    var selectedPromptID: PromptItem.ID?
    var searchText = ""
    var rankMode: RankMode = .calls
    private(set) var clusterPath: [String] = []
    private(set) var mapReplayToken = 0

    // Document
    var documentMode: DocumentMode = .preview
    var draftText = ""
    var loadedText = ""
    @ObservationIgnored private var loadedDocumentPath: String?

    // Presentation
    var activeSheet: HubSheet?
    var pendingConfirm: ConfirmAction?
    var isShowingConfirm = false
    private(set) var statusMessage: String?
    var isShowingError = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var scanGeneration = 0
    @ObservationIgnored private var afterNextScan: (() -> Void)?
    @ObservationIgnored var countCache: [SidebarItem: Int] = [:]

    init(paths: HubPaths, metaStore: MetaStore = .inApplicationSupport()) {
        self.paths = paths
        self.metaStore = metaStore
    }

    var isDirty: Bool { draftText != loadedText }

    var scanOptions: ScanOptions { ScanOptions(meta: meta) }

    // MARK: Lifecycle

    func bootstrap() {
        meta = metaStore.load(migratingFrom: paths.legacyMetaFile)
        usage = UsageLog.loadIndex(cacheURL: metaStore.usageCacheURL)
        refresh()
    }

    func refresh() {
        scanGeneration += 1
        let generation = scanGeneration
        let paths = paths
        let options = scanOptions
        let cacheURL = metaStore.usageCacheURL
        isScanning = true
        scanTask?.cancel()
        scanTask = Task {
            let snapshot = await Scanner.scan(paths: paths, options: options)
            guard generation == scanGeneration, !Task.isCancelled else { return }
            apply(snapshot)
            let home = paths.home
            let latest = await Task.detached {
                UsageLog.scan(home: home, cacheURL: cacheURL)
            }.value
            guard generation == scanGeneration, !Task.isCancelled else { return }
            if latest != usage { usage = latest }
        }
    }

    /// Runs a scan and then `then`, used after creating something so the new item can be selected.
    func refresh(then: @escaping () -> Void) {
        afterNextScan = then
        refresh()
    }

    private func apply(_ snapshot: CatalogSnapshot) {
        countCache.removeAll(keepingCapacity: true)
        skills = snapshot.skills
        prompts = snapshot.prompts
        stats = OverviewStats(snapshot: snapshot)
        isScanning = false
        hasLoaded = true
        afterNextScan?()
        afterNextScan = nil
        reloadDocumentIfNeeded()
        Logger.catalog.info("Scan finished: \(snapshot.skills.count) skills, \(snapshot.prompts.count) prompts")
    }

    // MARK: Selection

    var selectedSkill: SkillItem? {
        skills.first { $0.id == selectedSkillID }
    }

    var selectedPrompt: PromptItem? {
        prompts.first { $0.id == selectedPromptID }
    }

    var currentDocument: DocumentRef? {
        if let skill = selectedSkill { return .skill(skill) }
        if let prompt = selectedPrompt { return .prompt(prompt) }
        return nil
    }

    /// User picked a sidebar row (or ⌘1/2/3). Clears the open document so that filter's map shows.
    func chooseSidebar(_ item: SidebarItem?) {
        guard sidebarSelection != item else { return }
        sidebarSelection = item
        clusterPath.removeAll()
        searchText = ""
        documentMode = .preview
        selectedSkillID = nil
        selectedPromptID = nil
        mapReplayToken += 1
        selectionDidChange()
    }

    /// Leaves the document so the current filter's bubble map is visible again.
    func showClusterMap() {
        selectedSkillID = nil
        selectedPromptID = nil
        documentMode = .preview
        selectionDidChange()
        replayMap()
    }

    /// Called by the view whenever the selected skill/prompt ID or sidebar changes.
    func selectionDidChange() {
        guard let document = currentDocument else {
            loadedDocumentPath = nil
            loadedText = ""
            draftText = ""
            documentMode = .preview
            return
        }
        guard loadedDocumentPath != document.filePath else { return }
        loadDocument(document)
    }

    func select(_ document: DocumentRef) {
        switch document {
        case .skill(let skill):
            if sidebarSelection?.isPrompts == true {
                sidebarSelection = .skills(.all)
            }
            selectedPromptID = nil
            selectedSkillID = skill.id
        case .prompt(let prompt):
            if sidebarSelection?.isOverview != true && sidebarSelection?.isPrompts != true {
                sidebarSelection = .prompts(.all)
            }
            selectedSkillID = nil
            selectedPromptID = prompt.id
        }
        selectionDidChange()
    }

    private func loadDocument(_ document: DocumentRef) {
        let text = (try? String(contentsOfFile: document.filePath, encoding: .utf8)) ?? ""
        loadedDocumentPath = document.filePath
        loadedText = text
        draftText = text
        documentMode = .preview
    }

    private func reloadDocumentIfNeeded() {
        guard let document = currentDocument else {
            if selectedSkillID != nil || selectedPromptID != nil { selectionDidChange() }
            return
        }
        guard !isDirty else { return }
        let text = (try? String(contentsOfFile: document.filePath, encoding: .utf8)) ?? ""
        loadedDocumentPath = document.filePath
        loadedText = text
        draftText = text
    }

    // MARK: Cluster drill-down

    var clusterPrefix: String? {
        clusterPath.isEmpty ? nil : clusterPath.joined(separator: "-")
    }

    func openCluster(prefix: String) {
        clusterPath = ClusterGrouping.tokens(prefix)
        mapReplayToken += 1
    }

    /// Going up does not replay the explosion; bubbles glide to their new slots so back feels instant.
    func popCluster() {
        guard !clusterPath.isEmpty else {
            mapReplayToken += 1
            return
        }
        clusterPath.removeLast()
    }

    func resetClusters() {
        clusterPath.removeAll()
    }

    func replayMap() {
        mapReplayToken += 1
    }

    // MARK: Feedback

    func present(_ error: any Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
        Logger.catalog.error("\(error.localizedDescription, privacy: .public)")
    }

    func setStatus(_ message: String) {
        statusMessage = message
    }

    // MARK: Metadata persistence

    func mutateMeta(_ change: (inout AppMeta) -> Void) {
        change(&meta)
        countCache.removeAll(keepingCapacity: true)
        do {
            try metaStore.save(meta)
        } catch {
            Logger.meta.error("Failed to save meta: \(error.localizedDescription, privacy: .public)")
        }
    }
}
