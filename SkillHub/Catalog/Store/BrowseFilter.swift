import Foundation

nonisolated enum BrowseFilter: Hashable, Identifiable, Sendable {
    case all
    case tool(ToolSource)
    case duplicates
    case starred
    case health
    case standalone
    case embedded

    var id: String {
        switch self {
        case .all: "all"
        case .tool(let source): "tool.\(source.rawValue)"
        case .duplicates: "duplicates"
        case .starred: "starred"
        case .health: "health"
        case .standalone: "standalone"
        case .embedded: "embedded"
        }
    }

    var title: String {
        switch self {
        case .all: "全部"
        case .tool(let source): source.title
        case .duplicates: "重复安装"
        case .starred: "收藏"
        case .health: "健康问题"
        case .standalone: "独立文件"
        case .embedded: "Skill 内嵌"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "square.grid.2x2"
        case .tool(let source): source.symbolName
        case .duplicates: "square.on.square"
        case .starred: "star"
        case .health: "heart.text.square"
        case .standalone: "doc.text"
        case .embedded: "doc.on.doc"
        }
    }

    static let skillFilters: [BrowseFilter] = [.all, .starred, .duplicates, .health]
    static let promptFilters: [BrowseFilter] = [.all, .starred, .standalone, .embedded]
    static let promptSources: [BrowseFilter] = [.tool(.promptLibrary), .tool(.codexPrompts)]
}
