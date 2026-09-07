import SwiftUI

/// First-run screen: explains exactly why the app needs the home folder and asks once.
struct AccessGateView: View {
    @Environment(HomeAccess.self) private var access

    var body: some View {
        VStack(spacing: 28) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("先授权访问你的主目录")
                    .font(.title.bold())
                Text("Skill Hub 会读取并管理这些文件夹里的 skills 和 prompts。它们都在你的主目录下，所以只需要授权一次。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            AccessFolderList()

            VStack(spacing: 12) {
                Button("选择主目录并授权", action: access.requestGrant)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)

                if let error = access.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                }

                Text("授权只保存在这台 Mac 上，随时可以在「文件 › 重新授权主目录…」里更改。")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

private struct AccessFolderList: View {
    private let folders: [(String, String)] = [
        ("~/.cursor/skills", "Cursor"),
        ("~/.claude/skills", "Claude Code"),
        ("~/.codex/skills", "Codex"),
        ("~/.agents/skills", String(localized: "通用 Agent skills")),
        ("~/.skill-hub", String(localized: "Skill Hub 的 prompt 库和归档"))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(folders, id: \.0) { path, owner in
                LabeledContent {
                    Text(owner)
                        .foregroundStyle(.secondary)
                } label: {
                    Text(path)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 440)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: Theme.cornerRadius))
    }
}
