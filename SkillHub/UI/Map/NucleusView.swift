import SwiftUI

/// The centre of the map: shows what is being looked at, and acts as "back" or "shuffle".
struct NucleusView: View {
    let title: String
    let count: Int
    let diameter: CGFloat
    let canGoUp: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(count, format: .number)
                    .font(.system(size: diameter * 0.26, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(title.replacingOccurrences(of: "-", with: " "))
                    .font(.system(size: max(12, diameter * 0.11), weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Label(canGoUp ? "返回" : "重排", systemImage: canGoUp ? "chevron.up" : "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(10)
            .frame(width: diameter, height: diameter)
            .background(.regularMaterial, in: .circle)
            .overlay {
                Circle().strokeBorder(.separator, lineWidth: 1)
            }
            .contentShape(.circle)
        }
        .buttonStyle(BubbleButtonStyle())
        .animation(Theme.quick, value: count)
        .help(canGoUp ? "返回上一层" : "重新排列气泡")
        .accessibilityLabel("\(title)，\(count) 个")
        .accessibilityHint(canGoUp ? "返回上一层" : "重新排列气泡")
    }
}
