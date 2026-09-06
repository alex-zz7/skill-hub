import SwiftUI

struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, cell in
                    InlineMarkdownText(text: cell)
                        .font(.callout.weight(.semibold))
                        .padding(.vertical, 6)
                }
            }
            Divider()
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        InlineMarkdownText(text: cell)
                            .font(.callout)
                            .padding(.vertical, 6)
                    }
                }
                Divider()
            }
        }
    }
}
