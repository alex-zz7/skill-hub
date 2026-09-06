# Skill Hub

本地管理 AI 编程助手的 skills（`SKILL.md` 文件夹）和 prompts。扫描 Cursor、Claude Code、Codex、Agents、Proma 等工具目录，聚类、去重、预览、编辑、归档。不联网，不收集数据。

商店名：**AI Skills Hub**。窗口标题 / Dock 显示 **Skill Hub**。

两套客户端，同一套规则：

- **macOS**：原生 SwiftUI（本仓库根目录）。App Store 上架。
- **Windows**：Avalonia 桌面版（`windows/`）。扫描路径、去重、归档、气泡图逻辑与 Mac 对齐。不能把 `.app` 交叉编译成 `.exe`，所以 Windows 是单独写的一版。

收藏、标签、备注存在各自系统的应用数据目录里，不会自动同步；磁盘上的 skill 文件夹是同一套。

---

## 系统要求

| 平台 | 客户端 | 最低要求 |
| --- | --- | --- |
| macOS | 原生 Skill Hub | macOS 15 Sequoia 或更新 |
| Windows | SkillHub.exe（自包含） | Windows 10 1809+ x64 |
| Linux | 无 | — |

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

## Windows 安装

### 方式 A：下载现成包

1. 打开 [Releases](https://github.com/alex-zz7/skill-hub/releases) 或仓库 **Actions** 里最新一次 `Windows client` 的产物。
2. 下载 `SkillHub-win-x64.zip`，解压到任意目录（例如 `D:\Apps\SkillHub`）。
3. 双击 `SkillHub.exe`。不需要单独装 .NET。
4. 第一次打开会直接扫描 `%USERPROFILE%` 下的工具目录，没有 Mac 那种授权门。

SmartScreen 可能提示「未知发布者」：选「更多信息 → 仍要运行」。这是未做 Authenticode 签名的开源包，正常。

「安装到其他工具」默认做目录链接。若 Windows 没开[开发人员模式](https://learn.microsoft.com/windows/apps/get-started/enable-your-device-for-development)，创建符号链接会失败，客户端会改用目录联接（junction）。也可以勾选「复制成独立实体」。

### 方式 B：从源码编译

需要 [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)：

```powershell
git clone https://github.com/alex-zz7/skill-hub.git
cd skill-hub
dotnet run --project windows/src/SkillHub.App
```

打自包含发布包（在 Mac 或 Windows 上都能做）：

```bash
windows/scripts/publish.sh win-x64
# 产物：dist/SkillHub-win-x64.zip
```

跑与 Mac 同一套规则的测试：

```bash
dotnet test windows/SkillHub.sln -c Release
```

---

## 它扫哪些路径

相对家目录的布局两边一样：

| 工具 | macOS | Windows |
| --- | --- | --- |
| Cursor | `~/.cursor/skills` | `%USERPROFILE%\.cursor\skills` |
| Cursor 内置（只读） | `~/.cursor/skills-cursor` | `%USERPROFILE%\.cursor\skills-cursor` |
| Claude | `~/.claude/skills` | `%USERPROFILE%\.claude\skills` |
| Codex | `~/.codex/skills` | `%USERPROFILE%\.codex\skills` |
| Agents | `~/.agents/skills` | `%USERPROFILE%\.agents\skills` |
| Proma | `~/.proma/default-skills` | `%USERPROFILE%\.proma\default-skills` |
| Codex Prompts | `~/.codex/prompts` | `%USERPROFILE%\.codex\prompts` |
| 本应用库 / 归档 | `~/.skill-hub/` | `%USERPROFILE%\.skill-hub\` |
| 项目级（可选） | `~/Projects/*/.cursor/skills` 等 | `%USERPROFILE%\Projects\*\.cursor\skills` 等 |

PowerShell 里打开 Cursor 的 skills 目录：

```powershell
explorer "$env:USERPROFILE\.cursor\skills"
```

---

## 隐私与支持

- 隐私政策：https://ai-skills-hub.zoshh.workers.dev/privacy
- 支持页：https://ai-skills-hub.zoshh.workers.dev
- 联系：rowoverz@gmail.com

本应用无网络权限、无分析 SDK、无账号、无内购。

---

## 许可证

[MIT](LICENSE)
