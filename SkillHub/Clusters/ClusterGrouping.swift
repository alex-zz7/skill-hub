import Foundation

/// Groups items by shared name prefixes: `blog-write`, `blog-audit`, `blog-seo` all fall under `blog`,
/// and drilling into `blog` groups by the next token.
nonisolated enum ClusterGrouping {
    static func tokens(_ name: String) -> [String] {
        name.lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .split(whereSeparator: { $0 == "-" || $0 == " " })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func belongs(name: String, prefix: String) -> Bool {
        let n = name.lowercased()
        let p = prefix.lowercased()
        return n == p || n.hasPrefix(p + "-") || n.hasPrefix(p + " ")
    }

    /// The prefix one level deeper than `parent`, or nil when the name has no further level to group by.
    static func nextPrefix(of name: String, deeperThan parent: String?) -> String? {
        let parts = tokens(name)
        let depth = parent.map { tokens($0).count } ?? 0
        guard parts.count > depth + 1 else { return nil }
        return parts.prefix(depth + 1).joined(separator: "-")
    }
}
