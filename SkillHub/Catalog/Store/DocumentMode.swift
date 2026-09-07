import Foundation

nonisolated enum DocumentMode: String, CaseIterable, Identifiable, Sendable {
    case preview
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview: String(localized: "预览")
        case .edit: String(localized: "编辑")
        }
    }

    var symbolName: String {
        switch self {
        case .preview: "doc.richtext"
        case .edit: "pencil"
        }
    }
}
