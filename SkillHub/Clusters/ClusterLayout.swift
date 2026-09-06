import Foundation

/// Packs circles into an ellipse around a central nucleus, largest first, on concentric rings.
/// Purely geometric; the view decides how to animate into these slots.
nonisolated enum ClusterLayout {
    struct Placement: Equatable, Sendable {
        var diameter: CGFloat
        var center: CGPoint
    }

    static func nucleusDiameter(canvas: CGSize) -> CGFloat {
        min(140, max(96, min(canvas.width, canvas.height) * 0.11))
    }

    static func plan(nodes: [ClusterNode], canvas: CGSize) -> [String: Placement] {
        guard canvas.width > 40, canvas.height > 40, !nodes.isEmpty else { return [:] }
        // Heavier nodes are placed first, so if the canvas cannot hold everything the important ones survive.
        let priority = Dictionary(uniqueKeysWithValues: nodes
            .sorted { $0.weight != $1.weight ? $0.weight > $1.weight : $0.id < $1.id }
            .enumerated()
            .map { ($1.id, $0) })
        var sizes = diameters(for: nodes, canvas: canvas)
        for _ in 0..<8 {
            let slots = pack(sizes: sizes, priority: priority, canvas: canvas)
            if slots.count == sizes.count {
                return merge(sizes: sizes, slots: slots)
            }
            for key in sizes.keys {
                sizes[key] = max(minimumDiameter, (sizes[key] ?? 80) * 0.88)
            }
        }
        return merge(sizes: sizes, slots: pack(sizes: sizes, priority: priority, canvas: canvas))
    }

    /// Below this a bubble can no longer show a readable label, so packing gives up instead of shrinking further.
    private static let minimumDiameter: CGFloat = 48

    private static func merge(sizes: [String: CGFloat], slots: [String: CGPoint]) -> [String: Placement] {
        Dictionary(uniqueKeysWithValues: slots.map { id, slot in
            (id, Placement(diameter: sizes[id] ?? 80, center: slot))
        })
    }

    private static func diameters(for nodes: [ClusterNode], canvas: CGSize) -> [String: CGFloat] {
        let span = min(canvas.width, canvas.height)
        let weights = nodes.map { max($0.weight, 1) }
        let lo = weights.min() ?? 1
        let hi = weights.max() ?? 1
        // Scale with the canvas but never let the "largest" size fall below the "smallest" on a narrow map.
        let minD = min(78, max(minimumDiameter, span * 0.11))
        let maxD = max(minD + 12, min(176, span * 0.24))
        var raw: [String: CGFloat] = [:]
        for node in nodes {
            let t = hi - lo < 0.01 ? 0.5 : (max(node.weight, 1) - lo) / (hi - lo)
            raw[node.id] = minD + CGFloat(t.squareRoot()) * (maxD - minD)
        }

        let rx = canvas.width * 0.46
        let ry = canvas.height * 0.46
        let nucleus = nucleusDiameter(canvas: canvas) / 2
        let available = max(800, .pi * rx * ry * 0.56 - .pi * nucleus * nucleus)
        let area = raw.values.reduce(0) { $0 + .pi * ($1 / 2) * ($1 / 2) }
        if area > available {
            let scale = (available / area).squareRoot()
            for key in raw.keys {
                raw[key] = max(minimumDiameter, (raw[key] ?? minD) * scale)
            }
        }
        return raw
    }

    private static func pack(sizes: [String: CGFloat], priority: [String: Int], canvas: CGSize) -> [String: CGPoint] {
        let origin = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let rx = canvas.width * 0.46
        let ry = canvas.height * 0.46
        let nucleus = nucleusDiameter(canvas: canvas) / 2
        let gap: CGFloat = 11
        var placed: [(CGPoint, CGFloat)] = []
        var result: [String: CGPoint] = [:]
        let ordered = sizes.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return priority[lhs.key, default: .max] < priority[rhs.key, default: .max]
        }

        for (id, diameter) in ordered {
            let radius = diameter / 2
            var found: CGPoint?
            let minT = min(0.92, (nucleus + radius + gap) / max(min(rx, ry), 1))
            let maxT = max(minT, 1 - radius / max(min(rx, ry), 1))
            var t = minT
            search: while t <= maxT + 0.001 {
                let ringX = rx * t
                let ringY = ry * t
                let steps = max(8, Int((ringX + ringY) * .pi / max(radius * 1.8, 28)))
                let spin = CGFloat(placed.count) * 0.41
                for step in 0..<steps {
                    let angle = spin + CGFloat(step) / CGFloat(steps) * .pi * 2
                    let point = CGPoint(x: origin.x + cos(angle) * ringX, y: origin.y + sin(angle) * ringY)
                    let nx = (point.x - origin.x) / max(rx - radius - 4, 1)
                    let ny = (point.y - origin.y) / max(ry - radius - 4, 1)
                    if nx * nx + ny * ny > 1 { continue }
                    if hypot(point.x - origin.x, point.y - origin.y) < nucleus + radius + gap { continue }
                    if placed.allSatisfy({ hypot($0.0.x - point.x, $0.0.y - point.y) >= $0.1 + radius + gap }) {
                        found = point
                        break search
                    }
                }
                t += 0.05
            }
            if let found {
                placed.append((found, radius))
                result[id] = found
            }
        }
        return result
    }
}
