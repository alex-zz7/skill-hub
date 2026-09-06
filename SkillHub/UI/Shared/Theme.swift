import SwiftUI

/// Shared design constants. Everything else comes from system styles so light/dark mode,
/// increased contrast, and accessibility settings are handled by the platform.
enum Theme {
    static let cornerRadius: CGFloat = 8
    static let mapMinHeight: CGFloat = 440
    static let readingWidth: CGFloat = 760

    /// Critically damped: no overshoot, settles cleanly. Used for anything the user did not fling.
    static let settle = Animation.spring(duration: 0.5, bounce: 0)
    static let quick = Animation.spring(duration: 0.22, bounce: 0)

    private static let palette: [Color] = [
        .red, .blue, .orange, .green, .purple, .teal, .pink, .indigo, .mint, .brown, .cyan, .yellow
    ]

    /// Stable colour for a name so the same cluster keeps its hue across launches.
    static func tint(for key: String) -> Color {
        let sum = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(sum) % palette.count]
    }
}

extension ToolSource {
    var tint: Color {
        switch self {
        case .cursorUser: .blue
        case .cursorBuiltin: .gray
        case .claude: .orange
        case .codex: .green
        case .agents: .indigo
        case .proma: .pink
        case .promptLibrary: .brown
        case .codexPrompts: .teal
        case .custom: .secondary
        }
    }
}
