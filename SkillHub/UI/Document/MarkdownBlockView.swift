import SwiftUI

struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            InlineMarkdownText(text: text)
                .font(headingFont(level))
                .padding(.top, level <= 2 ? 10 : 4)

        case .paragraph(let text):
            InlineMarkdownText(text: text)
                .font(.body)
                .lineSpacing(5)

        case .bullets(let items):
            MarkdownListView(items: items, ordered: false)

        case .numbered(let items):
            MarkdownListView(items: items, ordered: true)

        case .code(let code):
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .padding(12)
            }
            .scrollIndicators(.hidden)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: Theme.cornerRadius))

        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.tint)
                    .frame(width: 3)
                InlineMarkdownText(text: text)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

        case .rule:
            Divider()
                .padding(.vertical, 4)

        case .table(let headers, let rows):
            MarkdownTableView(headers: headers, rows: rows)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title.bold()
        case 2: .title2.bold()
        case 3: .title3.weight(.semibold)
        default: .headline
        }
    }
}
