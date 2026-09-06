import SwiftUI

struct DocumentHeaderView: View {
    let document: DocumentRef

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(document.title)
                    .font(.largeTitle.bold())
                Spacer(minLength: 0)
                ToolBadge(source: document.primarySource)
            }
            if !document.subtitle.isEmpty {
                Text(document.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}
