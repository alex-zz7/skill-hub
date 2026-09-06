import SwiftUI

struct MarkdownListView: View {
    let items: [String]
    let ordered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(ordered ? "\(offset + 1)." : "•")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: ordered ? 24 : 12, alignment: .trailing)
                        .accessibilityHidden(true)
                    InlineMarkdownText(text: item)
                        .font(.body)
                }
            }
        }
    }
}
