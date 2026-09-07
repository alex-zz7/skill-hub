import SwiftUI

struct InstallationRow: View {
    @Environment(CatalogStore.self) private var store
    let installation: Installation
    let onRemove: (Installation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Label {
                    Text(installation.source.title)
                } icon: {
                    Image(systemName: installation.isSymlink ? "link" : "folder.fill")
                        .foregroundStyle(installation.isBroken ? .red : installation.source.tint)
                }
                Text(installation.isSymlink ? "链接" : "实体")
                    .font(Theme.secondary)
                    .foregroundStyle(.secondary)
                if installation.isBroken {
                    Text("已损坏")
                        .font(Theme.secondary)
                        .foregroundStyle(.red)
                }
                Spacer()
                if installation.source.isWritable {
                    Button("移除", systemImage: "minus.circle", action: remove)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("移除这份安装")
                }
            }
            Text(abbreviated)
                .font(Theme.mono)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }

    private var abbreviated: String {
        let home = store.paths.home.path
        return installation.path.hasPrefix(home + "/") ? "~" + installation.path.dropFirst(home.count) : installation.path
    }

    private func remove() {
        onRemove(installation)
    }
}
