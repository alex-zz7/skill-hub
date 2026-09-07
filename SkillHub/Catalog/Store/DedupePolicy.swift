import Foundation

nonisolated enum DedupePolicy: Hashable, Identifiable, Sendable {
    case keepEntity
    case prefer(ToolSource)

    var id: String {
        switch self {
        case .keepEntity: "entity"
        case .prefer(let source): "prefer.\(source.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .keepEntity: String(localized: "只留实体目录，删掉其余符号链接")
        case .prefer(let source): String(localized: "优先保留 \(source.title) 里的那一份")
        }
    }

    static let all: [DedupePolicy] = [.keepEntity] + ToolSource.skillRoots.filter(\.isWritable).map { .prefer($0) }
}
