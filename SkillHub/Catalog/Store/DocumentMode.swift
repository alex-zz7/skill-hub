import Foundation

nonisolated enum DocumentMode: String, CaseIterable, Identifiable, Sendable {
    case preview
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview: "预览"
        case .edit: "编辑"
        }
    }

    var symbolName: String {
        switch self {
        case .preview: "doc.richtext"
        case .edit: "pencil"
        }
    }
}
