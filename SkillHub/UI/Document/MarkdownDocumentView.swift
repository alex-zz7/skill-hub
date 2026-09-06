import SwiftUI

struct MarkdownDocumentView: View {
    let raw: String
    let title: String

    var body: some View {
        let blocks = MarkdownParser.skippingRedundantTitle(MarkdownParser.blocks(from: raw), title: title)
        LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                MarkdownBlockView(block: block)
            }
        }
    }
}
