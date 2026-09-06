import Foundation

struct ClusterRankedRow: Identifiable {
    var id: String { node.id }
    let node: ClusterNode
    let rank: Int
    /// 0…1 share of the top-ranked value, used for the bar length.
    let fraction: Double
}
