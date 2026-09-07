import Foundation

nonisolated enum BrowseFilter: Hashable, Identifiable, Sendable {
    case all
    case tool(ToolSource)
    case duplicates
    case starred
    case health
    case stale
    case standalone
    case embedded

    var id: String {
        switch self {
        case .all: "all"
        case .tool(let source): "tool.\(source.rawValue)"
        case .duplicates: "duplicates"
        case .starred: "starred"
        case .health: "health"
        case .stale: "stale"
        case .standalone: "standalone"
        case .embedded: "embedded"
        }
    }

    var title: String {
        switch self {
        case .all: String(localized: "全部")
        case .tool(let source): source.title
        case .duplicates: String(localized: "重复安装")
        case .starred: String(localized: "收藏")
        case .health: String(localized: "健康问题")
        case .stale: String(localized: "长期没用")
        case .standalone: String(localized: "独立文件")
        case .embedded: String(localized: "Skill 内嵌")
        }
    }

    var symbolName: String {
        switch self {
        case .all: "square.grid.2x2"
        case .tool(let source): source.symbolName
        case .duplicates: "square.on.square"
        case .starred: "star"
        case .health: "heart.text.square"
        case .stale: "zzz"
        case .standalone: "doc.text"
        case .embedded: "doc.on.doc"
        }
    }

    static let skillFilters: [BrowseFilter] = [.all, .starred, .duplicates, .health, .stale]
    static let promptFilters: [BrowseFilter] = [.all, .starred, .stale, .standalone, .embedded]
    static let promptSources: [BrowseFilter] = [.tool(.promptLibrary), .tool(.codexPrompts)]
}
