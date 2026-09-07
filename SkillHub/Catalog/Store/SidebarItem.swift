import Foundation

/// What the sidebar has selected: the overview dashboard, or a filtered list of skills or prompts.
nonisolated enum SidebarItem: Hashable, Sendable {
    case overview
    case skills(BrowseFilter)
    case prompts(BrowseFilter)

    var isPrompts: Bool {
        if case .prompts = self { return true }
        return false
    }

    var isOverview: Bool { self == .overview }

    var filter: BrowseFilter? {
        switch self {
        case .overview: nil
        case .skills(let filter), .prompts(let filter): filter
        }
    }

    var title: String {
        switch self {
        case .overview: String(localized: "总览")
        case .skills(let filter): filter == .all ? "Skills" : filter.title
        case .prompts(let filter): filter == .all ? "Prompts" : filter.title
        }
    }
}
