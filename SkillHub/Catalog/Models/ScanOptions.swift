import Foundation

/// The subset of user settings the scanner needs, copied out so the scan can run off the main actor.
nonisolated struct ScanOptions: Sendable, Equatable {
    var scanProjectSkills = false
    var customPromptRoots: [String] = []

    init(scanProjectSkills: Bool = false, customPromptRoots: [String] = []) {
        self.scanProjectSkills = scanProjectSkills
        self.customPromptRoots = customPromptRoots
    }

    init(meta: AppMeta) {
        scanProjectSkills = meta.scanProjectSkills
        customPromptRoots = meta.customPromptRoots
    }
}
