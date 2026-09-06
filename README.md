# Skill Hub

本地管理 AI 编程助手的 skills（`SKILL.md` 文件夹）和 prompts。扫描 Cursor、Claude Code、Codex、Agents、Proma 等工具目录，聚类、去重、预览、编辑、归档。不联网，不收集数据。

商店名：**AI Skills Hub**。Mac 上菜单栏 / Dock 显示 **Skill Hub**。

> **Windows 现在装不了这个 App。** 它是 SwiftUI + App Sandbox 的原生 macOS 应用，不能交叉编译成 `.exe`。下面 Windows 一节写的是技能文件本身怎么管，不是客户端安装包。

---

## 系统要求

| 平台 | 能不能装这个 App | 最低要求 |
| --- | --- | --- |
| macOS | 可以 | macOS 15 Sequoia 或更新 |
| Windows | 不可以 | 没有 Windows 客户端 |
| Linux | 不可以 | 没有 Linux 客户端 |

---

## macOS 安装

### 方式 A：Mac App Store（推荐）

上架后从这里安装（付费下载，约 $1.99）：

**https://apps.apple.com/us/app/id6809165417**

1. 用 Mac 打开上面的链接，或在 App Store 搜索 **AI Skills Hub**。
2. 购买并安装。
3. 第一次打开时，按提示授权一次**主目录**（标准系统文件夹选择面板）。这是必须的：各工具把 skills 放在 `~/.cursor/skills`、`~/.claude/skills` 等固定路径，不授权就扫不到任何内容。
4. 授权后会扫描本机已装工具。如果一台干净的测试机上什么都没有，列表为空；用工具栏 **新建 › 新建 Skill** 建一个示例即可把预览、编辑、安装到其他工具、去重、归档走一遍。

应用只读写这些 skill 文件夹和 `~/.skill-hub`。收藏、标签、备注存在 App 沙盒容器里。

### 方式 B：从源码编译（开发者）

需要本机已装 [Xcode](https://developer.apple.com/xcode/)（本仓库按 Xcode 26 / Swift 6 配置）和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
brew install xcodegen
git clone https://github.com/alex-zz7/skill-hub.git
cd skill-hub
scripts/dev.sh
```

`scripts/dev.sh` 会生成 Xcode 工程、打 Debug 包并打开 **Skill Hub.app**。沙盒只在签名后的二进制上生效，所以要用你的 Apple Development 证书（Xcode 自动签名）。

只生成工程、自己在 Xcode 里跑：

```bash
xcodegen generate
open SkillHub.xcodeproj
```

打 Mac App Store 包（需要发行证书，一般跟 Xcode 登录的开发者账号走）：

```bash
scripts/archive.sh
# 产物：build/export/Skill Hub.pkg
```

---

## Windows：现在怎么用

**没有安装包，也不要去找 `.exe`。** 把 macOS 的 `.app` / `.pkg` 拷到 Windows 上打不开。

Windows 上 Cursor、Claude Code、Codex 仍然会把 skills 写到用户目录。你可以自己打开这些文件夹增删改：

| 工具 | Windows 路径 |
| --- | --- |
| Cursor | `%USERPROFILE%\.cursor\skills` |
| Cursor 内置（不要改） | `%USERPROFILE%\.cursor\skills-cursor` |
| Claude | `%USERPROFILE%\.claude\skills` |
| Codex | `%USERPROFILE%\.codex\skills` |
| Agents | `%USERPROFILE%\.agents\skills` |
| Proma | `%USERPROFILE%\.proma\default-skills` |
| Codex Prompts | `%USERPROFILE%\.codex\prompts` |

PowerShell 里快速打开 Cursor 的 skills 目录：

```powershell
explorer "$env:USERPROFILE\.cursor\skills"
```

每个 skill 是一个文件夹，里面至少有 `SKILL.md`。改文件、复制到另一个工具目录、删掉重复副本，都是普通文件操作。没有 Skill Hub 的气泡图、一键去重和归档。

如果以后要做 Windows 客户端，需要单独写一版（例如 Tauri / 原生），**不是**把现在的 Mac 工程打包出去。需要的话开 Issue 说一声。

---

## 它扫哪些 Mac 路径

和 Windows 是同一套相对路径，只是家目录写法不同：

| 工具 | macOS 路径 |
| --- | --- |
| Cursor | `~/.cursor/skills` |
| Cursor 内置（只读） | `~/.cursor/skills-cursor` |
| Claude | `~/.claude/skills` |
| Codex | `~/.codex/skills` |
| Agents | `~/.agents/skills` |
| Proma | `~/.proma/default-skills` |
| Codex Prompts | `~/.codex/prompts` |
| 本应用库 / 归档 | `~/.skill-hub/` |
| 项目级（可选） | `~/Projects/*/.cursor/skills`、`~/Projects/*/.claude/skills` |

---

## 隐私与支持

- 隐私政策：https://ai-skills-hub.zoshh.workers.dev/privacy
- 支持页：https://ai-skills-hub.zoshh.workers.dev
- 联系：rowoverz@gmail.com

本应用无网络权限、无分析 SDK、无账号、无内购。

---

## 许可证

[MIT](LICENSE)
