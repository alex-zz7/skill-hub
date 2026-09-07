import Foundation

nonisolated enum HubError: LocalizedError, Equatable {
    case accessDenied
    case pathNotAllowed(String)
    case builtinReadOnly
    case alreadyExists(String)
    case notFound
    case invalidName
    case lastEntity
    case io(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            String(localized: "没有拿到主目录的访问权限。请在「文件 › 重新授权主目录…」里重新授权。")
        case .pathNotAllowed(let path):
            String(localized: "路径不在允许的根目录内：\(path)")
        case .builtinReadOnly:
            String(localized: "Cursor 内置 skill 只读，不能修改。")
        case .alreadyExists(let name):
            String(localized: "「\(name)」已经存在。")
        case .notFound:
            String(localized: "找不到这个文件。")
        case .invalidName:
            String(localized: "名字只能用小写字母、数字和连字符，最多 64 个字符。")
        case .lastEntity:
            String(localized: "这是最后一份实体文件，不能只当作链接移除。")
        case .io(let message):
            message
        }
    }
}
