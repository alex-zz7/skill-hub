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
    private(set) var meta = AppMeta.empty
    private(set) var isScanning = false
    private(set) var hasLoaded = false

    // Navigation
    var sidebarSelection: SidebarItem? = .skills(.all)
    var selectedSkillID: SkillItem.ID?
    var selectedPromptID: PromptItem.ID?
    var searchText = ""
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
        refresh()
    }

    func refresh() {
        scanGeneration += 1
        let generation = scanGeneration
        let paths = paths
        let options = scanOptions
        isScanning = true
        scanTask?.cancel()
        scanTask = Task {
            let snapshot = await Scanner.scan(paths: paths, options: options)
            guard generation == scanGeneration, !Task.isCancelled else { return }
            apply(snapshot)
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
        switch sidebarSelection {
        case .overview, .none: nil
        case .skills: selectedSkill.map(DocumentRef.skill)
        case .prompts: selectedPrompt.map(DocumentRef.prompt)
        }
    }

    func sidebarDidChange() {
        clusterPath.removeAll()
        searchText = ""
        documentMode = .preview
        selectionDidChange()
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
        recordOpen(document)
    }

    func select(_ document: DocumentRef) {
        switch document {
        case .skill(let skill):
            if sidebarSelection?.isPrompts != false { sidebarSelection = .skills(.all) }
            selectedSkillID = skill.id
        case .prompt(let prompt):
            if sidebarSelection?.isPrompts != true { sidebarSelection = .prompts(.all) }
            selectedPromptID = prompt.id
        }
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

    func popCluster() {
        guard !clusterPath.isEmpty else {
            mapReplayToken += 1
            return
        }
        clusterPath.removeLast()
        mapReplayToken += 1
    }

    func resetClusters() {
        clusterPath.removeAll()
        mapReplayToken += 1
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
