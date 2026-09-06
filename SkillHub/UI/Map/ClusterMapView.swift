import SwiftUI

/// Bubbles packed around a nucleus. On each layout change the bubbles travel from the centre to
/// their slots with a critically damped spring; with Reduce Motion they simply fade in place.
struct ClusterMapView: View {
    let nodes: [ClusterNode]
    let title: String
    let itemCount: Int
    let canGoUp: Bool
    let replayToken: Int
    let onOpen: (ClusterNode) -> Void
    let onNucleusTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var canvas: CGSize = .zero
    @State private var placements: [String: ClusterLayout.Placement] = [:]
    @State private var expanded = false

    private var center: CGPoint {
        CGPoint(x: canvas.width / 2, y: canvas.height / 2)
    }

    private var layoutKey: String {
        let ids = nodes.map { "\($0.id):\(Int($0.weight))" }.joined(separator: "|")
        return "\(ids)|\(Int(canvas.width))x\(Int(canvas.height))"
    }

    var body: some View {
        ZStack {
            ForEach(nodes) { node in
                if let placement = placements[node.id] {
                    ClusterBubbleView(node: node, diameter: placement.diameter) {
                        onOpen(node)
                    }
                    .position(expanded || reduceMotion ? placement.center : center)
                    .opacity(expanded ? 1 : 0)
                }
            }

            NucleusView(
                title: title,
                count: itemCount,
                diameter: ClusterLayout.nucleusDiameter(canvas: canvas),
                canGoUp: canGoUp,
                action: onNucleusTap
            )
            .position(center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            canvas = size
        }
        .onChange(of: layoutKey, initial: true) {
            placements = ClusterLayout.plan(nodes: nodes, canvas: canvas)
        }
        .task(id: "\(layoutKey)|\(replayToken)") {
            await replay()
        }
    }

    private func replay() async {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { expanded = false }

        // Let the collapsed frame render before animating out, otherwise the two writes collapse into one.
        try? await Task.sleep(for: .milliseconds(30))
        guard !Task.isCancelled else { return }

        withAnimation(reduceMotion ? .easeOut(duration: 0.25) : Theme.settle) {
            expanded = true
        }
    }
}
