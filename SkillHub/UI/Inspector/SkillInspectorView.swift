import SwiftUI

struct SkillInspectorView: View {
    @Environment(CatalogStore.self) private var store
    let skill: SkillItem

    private var document: DocumentRef { .skill(skill) }

    var body: some View {
        Form {
            InspectorHeader(
                title: skill.name,
                subtitle: skill.description.isEmpty ? "还没有 description" : skill.description,
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
