import SwiftUI

/// A monospaced path with a copy button; shows `~` for the home folder to keep rows short.
struct PathRow: View {
    @Environment(CatalogStore.self) private var store
    let label: String
    let path: String

    @State private var copied = false

    var body: some View {
        LabeledContent {
            HStack(alignment: .top, spacing: 6) {
                Text(abbreviated)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .truncationMode(.middle)
                Button(copied ? "已复制" : "复制路径", systemImage: copied ? "checkmark" : "doc.on.doc", action: copy)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("复制完整路径")
            }
        } label: {
            Text(label)
        }
    }

    private var abbreviated: String {
        let home = store.paths.home.path
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func copy() {
        store.copyToPasteboard(path)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
