import Foundation

nonisolated enum ClusterBuilder {
    struct Item: Sendable {
        var id: String
        var title: String
        var weight: Double
        var openCount: Int
        var isSkill: Bool
        var lastInvokedAt: Date? = nil
        var modifiedAt: Date = .distantPast
    }

    /// Groups `items` one level below `parent`. Singletons never form a group; they stay loose.
    /// `looseCap` limits how many loose items appear so a map with 200 skills stays readable.
    static func nodes(from items: [Item], parent: String?, looseCap: Int?) -> [ClusterNode] {
        var buckets: [String: [Int]] = [:]
        var loose: [Int] = []

        for (index, item) in items.enumerated() {
            if let key = ClusterGrouping.nextPrefix(of: item.title, deeperThan: parent) {
                buckets[key, default: []].append(index)
            } else {
                loose.append(index)
            }
        }

        // A bare `blog` item joins the `blog` group formed by `blog-*` siblings.
        var stillLoose: [Int] = []
        for index in loose {
            let key = items[index].title.lowercased()
            if buckets[key] != nil {
                buckets[key, default: []].append(index)
            } else {
                stillLoose.append(index)
            }
        }

        var groups: [ClusterNode] = []
        for (key, indexes) in buckets {
            if indexes.count < 2 {
                stillLoose.append(contentsOf: indexes)
                continue
            }
            let members = indexes.map { items[$0] }
            groups.append(
                ClusterNode(
                    id: "group:\(key)",
                    title: key,
                    kind: .group(prefix: key, memberIDs: members.map(\.id)),
                    weight: members.reduce(0) { $0 + $1.weight },
                    count: members.count,
                    openCount: members.reduce(0) { $0 + $1.openCount },
                    lastInvokedAt: members.compactMap(\.lastInvokedAt).max(),
                    modifiedAt: members.map(\.modifiedAt).max() ?? .distantPast
                )
            )
        }
        groups.sort { $0.weight > $1.weight }

        let singles = stillLoose.map { items[$0] }.sorted { $0.weight > $1.weight }
        let visible = looseCap.map { Array(singles.prefix($0)) } ?? singles
        let singleNodes = visible.map { item in
            ClusterNode(
                id: item.id,
                title: item.title,
                kind: item.isSkill ? .skill(item.id) : .prompt(item.id),
                weight: item.weight,
                count: 1,
                openCount: item.openCount,
                lastInvokedAt: item.lastInvokedAt,
                modifiedAt: item.modifiedAt
            )
        }
        return groups + singleNodes
    }
}
