# Skill Hub — Mac App Store 上架手册

发版主干（照搬「appstore」Skill 的流程，每步可单独重跑，都是幂等的）：

```
python3 scripts/lint-metadata.py          # 码点+UTF-16 双计数、关键词字节、互抄、商标词、占位符
asc metadata validate --dir ./metadata    # asc 自己的字段校验
asc metadata push … --dry-run             # 看 drift：远端被手改过的字段会在这里现形
asc metadata push …                       # 推送 = 一次重推，回滚就是改本地再推一次
scripts/screenshots-review.sh             # 上传前单页 HTML 人工审批 + 打印 sha256
asc screenshots upload …                  # 上传
asc screenshots list … | jq checksum      # 上传后按 checksum 校验，不数文件
asc validate --app … --version …          # 提交前 readiness gate
asc review submit … --confirm             # 提交
```

按「审核合规 → 元数据/ASO → 截图 → 上传提交 → 多语言」的顺序。已经替你做完的部分打了 ✅，需要你本人操作（涉及 Apple 账号登录、2FA、付款）的部分标了 👤。

## 0. 现状

| 项 | 状态 |
|---|---|
| App Sandbox + Hardened Runtime + 正式签名 | ✅ `project.yml`，Debug 构建已验证 |
| 应用图标、隐私清单、`ITSAppUsesNonExemptEncryption=NO` | ✅ |
| 元数据（zh-Hans 主语言 + en-US） | ✅ `metadata/`，`asc metadata validate` 0 错误 |
| 截图 4 张 2880×1800 | ✅ `docs/app-store/screenshots/zh-Hans/` |
| 支持页 / 隐私页 | ✅ 已写进 `alexsignal-site`，**待你部署** |
| Apple Developer 账号登录 Xcode / asc | Xcode ✅ `rowoverz@gmail.com` / `8YVWX4U62Y`；asc 👤 未登录 |
| App Store Connect 里的 App 记录 | 👤 未创建 |
| Apple Distribution 证书 | 👤 未申请（Xcode 自动签名会代办） |

## 1. 审核合规审查（对照 `app-store-review` Skill）

| 指南 | 结论 | 证据 |
|---|---|---|
| 2.1 完整性 | 通过，但审核员会看到「授权主目录」引导页 | 必须在审核备注里说明（见 §5） |
| 2.3 元数据准确 | 通过 | 描述/截图均来自当前构建 |
| 2.4.5 Mac 应用要求：沙盒、无私有 API | 通过 | `codesign -d --entitlements` 只有 sandbox / user-selected / bookmarks |
| 4.2 最小功能 | 通过 | 原生工具，非套壳 |
| 2.3.7 / 5.2 关键词里的第三方商标 | 已修 | 关键词字段去掉了 `claude`、`codex`；描述里作为「兼容 Cursor、Claude Code、Codex」的互操作说明保留，这是允许的 |
| 5.1.1 隐私政策 URL | ✅ | `https://ai-skills-hub.zoshh.workers.dev/privacy` |
| 5.1.2 隐私标签 | 选「不收集数据」 | 无网络、无 SDK |
| 隐私清单 | 通过 | UserDefaults CA92.1、文件时间戳 DDA9.1 + 3B52.1 |
| 出口合规 | 免填 | `ITSAppUsesNonExemptEncryption = false` |
| 年龄分级 | 4+ | 问卷全选「无」 |

**唯一真实风险**：审核员不理解为什么一个 skill 管理器要读主目录。审核备注要写清楚（§5 已写好），并且引导页本身已经解释了要读哪几个隐藏文件夹。

## 2. 👤 登录账号（一次性，约 10 分钟）

### 2a. Xcode 登录（用于签名和归档）

Xcode 已登录 `rowoverz@gmail.com`（Team ID `8YVWX4U62Y`）。归档时 Xcode 会自动申请 Apple Distribution 和 Mac Installer Distribution 证书、生成 Mac App Store 描述文件。**不需要手动在 developer.apple.com 点任何证书。**

### 2b. asc 登录（用于命令行创建 App、传元数据、传截图）

```bash
# 网页会话（会提示输入密码和两步验证码）
asc web auth login --apple-id rowoverz@gmail.com

# 用这个会话生成一把团队 API key（只需一次；.p8 会保存在 ./keys，不要提交进 git）
mkdir -p keys && asc web api-keys create --name "skill-hub-cli" --role ADMIN --output-dir ./keys --output json
# 输出里有 keyId 和 issuerId，填进下一条：
asc auth login --name skillhub --key-id "<KEY_ID>" --issuer-id "<ISSUER_ID>" --private-key ./keys/AuthKey_<KEY_ID>.p8
asc auth status
```

`keys/` 已加进 `.gitignore`。

## 3. 👤 创建 App 记录

```bash
# 注册 Bundle ID（macOS 平台）
asc bundle-ids create --identifier dev.lucy.SkillHub --name "Skill Hub" --platform MAC_OS

# 创建 App（网页会话），主语言简体中文
asc web apps create --name "Skill Hub" --bundle-id dev.lucy.SkillHub --sku SKILLHUB-MAC-001 \
  --platform MAC_OS --primary-locale zh-Hans --apple-id rowoverz@gmail.com

# 记下 APP_ID
asc apps list --bundle-id dev.lucy.SkillHub --output table
```

如果名字 "Skill Hub" 被占用，备选：`Skill Hub – AI Skills Manager`（名称限 30 字符）。

## 4. 推送元数据和截图（我可以代跑，你只需把 APP_ID 给我）

```bash
export APP_ID=<上一步的 ID>

# 版本 1.0.0 已由第一次上传构建自动创建；没有的话：
asc versions create --app "$APP_ID" --version 1.0.0 --platform MAC_OS

# 元数据：先 dry-run 看 diff，再应用
asc metadata push --app "$APP_ID" --version 1.0.0 --platform MAC_OS --dir ./metadata --dry-run --output table
asc metadata push --app "$APP_ID" --version 1.0.0 --platform MAC_OS --dir ./metadata

# 版权（不是本地化字段）
asc versions update --version-id "$(asc versions list --app "$APP_ID" --platform MAC_OS --output json | jq -r '.data[0].id')" --copyright "2026 周诗豪"

# 截图：先本地审批，再上传，再按 checksum 核对（Mac 的展示类型是 APP_DESKTOP）
scripts/screenshots-review.sh zh-Hans
asc screenshots upload --app "$APP_ID" --version 1.0.0 --path ./docs/app-store/screenshots/zh-Hans --device-type APP_DESKTOP --dry-run
asc screenshots upload --app "$APP_ID" --version 1.0.0 --path ./docs/app-store/screenshots/zh-Hans --device-type APP_DESKTOP
asc screenshots list --app "$APP_ID" --version 1.0.0 --output json | jq -r '.data[].attributes | "\(.fileName) \(.sourceFileChecksum)"'
```

英文截图直接复用中文图并换标题（en-US 和 en-GB 共用一套）：

```bash
swift scripts/compose-screenshot.swift docs/app-store/screenshots/raw/02-skills-map.png  docs/app-store/screenshots/en/01-map.png      "Every skill, at a glance"        "Scans Cursor, Claude Code, Codex and more; clusters by name prefix" 0.62
swift scripts/compose-screenshot.swift docs/app-store/screenshots/raw/03-skill-detail.png docs/app-store/screenshots/en/02-detail.png   "Read, edit, save — in one place" "Rendered Markdown preview, edit SKILL.md in place, paths and installs in the inspector" 0.08
swift scripts/compose-screenshot.swift docs/app-store/screenshots/raw/01-overview.png     docs/app-store/screenshots/en/03-overview.png "Duplicates and broken links, gone" "Per-tool counts, health checks, one-click dedupe" 0.35
swift scripts/compose-screenshot.swift docs/app-store/screenshots/raw/04-prompt-detail.png docs/app-store/screenshots/en/04-prompts.png "Prompts, managed too"           "Embedded and standalone prompts: star, tag, save a copy" 0.78
```

网页里还要手动点三处（API 不支持）：**定价**（建议先免费）、**年龄分级问卷**（全选无）、**App 隐私 › 不收集数据**。

## 5. 审核备注（复制到 App Store Connect › App 审核信息 › 备注）

> Skill Hub 是一个本地开发者工具，用来管理 AI 编程助手（Cursor、Claude Code、Codex 等）安装在用户主目录隐藏文件夹里的 "skills"（Markdown 文件夹）。
>
> 首次启动时应用会请求一次用户主目录的访问权限（标准 NSOpenPanel + security-scoped bookmark）。这是必要的，因为这些工具把 skills 固定放在 ~/.cursor/skills、~/.claude/skills、~/.codex/skills、~/.agents/skills 等位置，用户无法更改；没有这个权限应用就没有任何内容可显示。应用只读写这些 skill 文件夹和 ~/.skill-hub，不联网，不收集任何数据。
>
> 测试建议：授权主目录后，如果测试机上没有安装任何 AI 编程工具，列表会为空；可用工具栏「新建 › 新建 Skill」创建一个示例 skill，即可体验预览、编辑、安装到其他工具、去重、归档等全部功能。
>
> 无需登录账号，无内购。

英文版：

> Skill Hub is a local developer utility for managing the "skills" (folders of Markdown files) that AI coding assistants such as Cursor, Claude Code and Codex install into hidden folders in the user's home directory.
>
> On first launch the app asks once for access to the home folder (standard NSOpenPanel with a security-scoped bookmark). This is required: the tools store skills at fixed paths such as ~/.cursor/skills, ~/.claude/skills, ~/.codex/skills and ~/.agents/skills, which the user cannot change, and without access the app has nothing to show. The app only reads and writes those skill folders and ~/.skill-hub. It has no network access and collects no data.
>
> To test: after granting access, if the test machine has no AI coding tools installed the lists will be empty. Use the toolbar "New › New Skill" to create a sample skill, which exercises preview, edit, install-to-other-tool, dedupe and archive.
>
> No account, no in-app purchases.

## 6. 支持页和隐私页

独立 Worker，源码在本仓库 `site/`，不挂在其他网站上：

- https://ai-skills-hub.zoshh.workers.dev
- https://ai-skills-hub.zoshh.workers.dev/privacy

更新页面后：`cd site && wrangler deploy`（或走 Cloudflare API）。

## 7. 归档并上传构建

Xcode 登录完成后：

```bash
scripts/archive.sh            # 归档 + 导出 build/export/Skill Hub.pkg（自动创建分发证书和描述文件）
```

上传二选一：

```bash
# A. Transporter.app（Mac App Store 免费下载），把 .pkg 拖进去
# B. 命令行，用 §2b 的 API key
xcrun altool --upload-app --type macos --file "build/export/Skill Hub.pkg" \
  --apiKey "<KEY_ID>" --apiIssuer "<ISSUER_ID>"
```

上传后 10–30 分钟处理完成，`asc builds list --app "$APP_ID" --output table` 能看到。

## 8. 提交审核

```bash
asc validate --app "$APP_ID" --version 1.0.0 --platform MAC_OS --output table   # 缺什么会直接列出来
asc review submit --app "$APP_ID" --version 1.0.0 --build "<BUILD_ID>" --dry-run --output table
asc review submit --app "$APP_ID" --version 1.0.0 --build "<BUILD_ID>" --confirm
asc submissions list --app "$APP_ID" --output table   # 之后用这条看状态
```

## 9. 多语言

已带三个 locale：`zh-Hans`（主语言）、`en-US`、`en-GB`。**en-GB 不是多余的**：它是大量非英语国家商店（欧洲、东南亚、印度、澳洲等）的英文索引位，只有 en-US 会漏掉这些地区的英文搜索。

再加语言时：先 `asc metadata pull` 拉一次远端避免 drift，复制一份 `en-US.json` 改名翻译，`python3 scripts/lint-metadata.py` 过一遍（关键词按地区重写，例如日语区 `スキル,プロンプト`，每个 locale 都要 ≤100 字节），再 `push --dry-run`。

## 10. 待你确认的事实字段

| 字段 | 当前值 | 说明 |
|---|---|---|
| 版权 | `2026 周诗豪` | 取自证书主体，可改 |
| 价格 | 免费 | 建议 v1 免费积累评分，付费另开新版本 |
| 支持邮箱 | `rowoverz@gmail.com` | 支持页和隐私页上的联系邮箱 |
| 隐私 / 支持 URL | `https://ai-skills-hub.zoshh.workers.dev` | 已上线 |
| SKU | `SKILLHUB-MAC-001` | 任意唯一字符串 |
| 主语言 | zh-Hans | 界面目前只有中文 |

## 常用重拍截图

窗口放在 MacBook 内屏（Retina），把界面切到想拍的状态，然后：

```bash
scripts/capture-screenshot.sh 05-dedupe "同一份 skill，装了三处" "一键保留实体、清掉多余链接" 0.55
```

会生成 `docs/app-store/screenshots/raw/05-dedupe.png` 和成品 `zh-Hans/05-dedupe.png`。
