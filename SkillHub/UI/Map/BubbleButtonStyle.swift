import SwiftUI

/// Feedback on pointer-down, not on release: the bubble compresses the instant it is pressed.
struct BubbleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.quick, value: configuration.isPressed)
    }
}
