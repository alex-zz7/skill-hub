import Foundation

/// How the middle column orders bubbles-as-rows.
nonisolated enum RankMode: String, CaseIterable, Identifiable, Sendable {
    /// Most agent calls first (groups: most members first).
    case calls
    /// Most recently called first; long-unused sinks to the bottom.
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calls: String(localized: "按调用")
        case .recent: String(localized: "按最近")
        }
    }
}
