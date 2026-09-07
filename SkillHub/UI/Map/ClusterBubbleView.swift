import SwiftUI

struct ClusterBubbleView: View {
    let node: ClusterNode
    let diameter: CGFloat
    let action: () -> Void

    @State private var isHovering = false

    private var tint: Color { Theme.tint(for: node.title) }

    /// Long-unused bubbles wash out so the map reads as "what can go" instead of just "what exists".
    private var staleness: Double {
        UsageScore.staleness(lastInvokedAt: node.lastInvokedAt, modifiedAt: node.modifiedAt)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tint.gradient)
                    .saturation(1 - staleness * 0.8)
                    .opacity(1 - staleness * 0.35)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(isHovering ? 0.9 : 0.25), lineWidth: isHovering ? 2 : 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: isHovering ? 10 : 4, y: 2)

                VStack(spacing: 2) {
                    Text(displayTitle)
                        .font(.system(size: min(20, max(12, diameter * 0.15)), weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    if node.isGroup {
                        Text(node.count, format: .number)
                            .font(.system(size: min(15, max(11, diameter * 0.11)), weight: .medium, design: .rounded))
                            .opacity(0.9)
                    }
                }
                .foregroundStyle(.white)
                .padding(diameter > 110 ? 12 : 8)
                .frame(width: diameter * 0.88, height: diameter * 0.88)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(.circle)
        }
        .buttonStyle(BubbleButtonStyle())
        .onHover { isHovering = $0 }
        .animation(Theme.quick, value: isHovering)
        .help(helpText)
        .accessibilityLabel(node.isGroup ? Text("\(node.title)，\(node.count) 个") : Text(node.title))
        .accessibilityHint(node.isGroup ? "打开这一类" : "打开")
    }

    private var displayTitle: String {
        node.title.replacingOccurrences(of: "-", with: " ")
    }

    private var helpText: String {
        let recent = UsageScore.lastUsedText(node.lastInvokedAt)
        return node.isGroup
            ? String(localized: "\(node.title) · \(node.count) 个 · \(recent)，点开这一类")
            : "\(node.title) · \(recent)"
    }
}
