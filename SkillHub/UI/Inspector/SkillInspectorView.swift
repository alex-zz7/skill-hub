import SwiftUI

struct SkillInspectorView: View {
    @Environment(CatalogStore.self) private var store
    let skill: SkillItem

    private var document: DocumentRef { .skill(skill) }

    var body: some View {
        Form {
            InspectorHeader(
                title: skill.name,
                subtitle: skill.description.isEmpty ? String(localized: "还没有 description") : skill.description,
                sources: skill.toolSources,
                starred: store.isStarred(skillID: skill.id),
                onToggleStar: toggleStar
            )

            Section("位置") {
                PathRow(label: "SKILL.md", path: skill.skillFilePath)
                if skill.canonicalPath != skill.skillFilePath {
                    PathRow(label: "目录", path: skill.canonicalPath)
                }
                if !skill.version.isEmpty {
                    LabeledContent("版本", value: skill.version)
                }
                LabeledContent("文件") {
                    Text("\(skill.fileCount) 个")
                }
                LabeledContent("修改时间") {
                    Text(skill.modifiedAt, format: .dateTime.year().month().day().hour().minute())
                }
                LabeledContent("Agent 调用") {
                    Text(store.usage.skill(skill).count, format: .number)
                }
                LabeledContent("上次调用", value: UsageScore.lastUsedText(store.usage.skill(skill).lastInvokedAt))
            }

            Section {
                if !skill.originSummary.isEmpty {
                    Text(skill.originSummary)
                }
                if !skill.author.isEmpty {
                    LabeledContent("作者", value: skill.author)
                }
                if !skill.origin.isEmpty {
                    PathRow(label: "出处", path: skill.origin)
                }
                ForEach(skill.sameNamePaths, id: \.self) { path in
                    PathRow(label: "同名", path: path)
                }
            } header: {
                Text("来源")
            } footer: {
                if !skill.sameNamePaths.isEmpty {
                    Text("同名但不是同一个文件夹，内容可能已经不一样了。重复安装只算同一份的多个链接。")
                }
            }

            Section {
                ForEach(skill.installations, id: \.path) { install in
                    InstallationRow(installation: install, onRemove: removeInstall)
                }
            } header: {
                Text("安装位置")
            } footer: {
                if skill.isDuplicateInstall {
                    Text("同一份文件出现在多个工具目录，所以算重复安装。")
                }
            }

            if !skill.health.isEmpty {
                Section("健康") {
                    ForEach(skill.health, id: \.self) { issue in
                        Label(issue.title, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            ItemMetaSections(document: document)

            Section("操作") {
                Button("安装到其他工具…", systemImage: "arrow.down.to.line", action: install)
                    .disabled(skill.isReadOnly || store.availableInstallTargets(for: skill).isEmpty)
                if !store.duplicateSkills.isEmpty {
                    Button("一键去重 \(store.duplicateSkills.count) 个…", systemImage: "square.on.square", action: dedupe)
                }
                Button("在 Finder 中显示", systemImage: "folder", action: reveal)
                Button("归档…", systemImage: "archivebox", action: archive)
                    .disabled(skill.isReadOnly)
                Button("删除实体…", systemImage: "trash", role: .destructive, action: delete)
                    .disabled(skill.isReadOnly)
            }

            RelatedSkillsSection(skill: skill)
        }
        .formStyle(.grouped)
        .font(Theme.body)
    }

    private func toggleStar() {
        store.toggleStar(for: document)
    }

    private func removeInstall(_ install: Installation) {
        store.request(.removeInstall(skillID: skill.id, path: install.path, isSymlink: install.isSymlink))
    }

    private func install() {
        store.activeSheet = .install
    }

    private func dedupe() {
        store.activeSheet = .dedupe
    }

    private func reveal() {
        store.reveal(document)
    }

    private func archive() {
        store.requestArchive(document)
    }

    private func delete() {
        store.requestDelete(document)
    }
}
