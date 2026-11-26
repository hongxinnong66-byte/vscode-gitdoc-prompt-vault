---
name: vscode-gitdoc-prompt-vault
description: >-
  Set up, restore, migrate, or organize a local-first AI Prompt and Skills
  Markdown vault in VS Code with fully automatic GitHub private-repo syncing
  via the GitDoc extension. Use when the user wants to set up a free VS Code +
  GitHub auto-sync prompt/skills repository from scratch, restore an existing
  prompt vault on a new computer in one step, organize raw prompts into
  categorized Markdown modules, or troubleshoot VS Code Git/GitDoc sync issues
  (such as GIT_CONFIG_VALUE_0 conflicts or missing GitDoc commands).
---

# VS Code + GitDoc + GitHub Prompt & Skills 自动同步知识库

把日常与 Gemini、GPT、Claude 等 AI 沟通沉淀下来的 **Prompt** 和 **Skills** 统一存放在本地 Markdown 仓库中，利用 **VS Code 自动保存 + GitDoc 插件 + GitHub 私有仓库** 实现完全免费、跨设备、像云文档一样「打开即同步、改完自动保存并推送、保留完整历史版本」的个人 AI 知识库。

---

## Overview（适用场景与三种模式）

本 Skill 支持以下三种核心模式，执行前先判断用户处于哪一种场景：

1. **Mode A：`restore`（新电脑一键恢复已有私有库，最常用）**
   - 用户已经有一个 GitHub 私有知识库（如 `ai-prompts-and-skills`），换到新电脑后希望一键装好环境、拉取仓库、开启自动同步并在 VS Code 打开。
2. **Mode B：`init`（从零搭建一套全新的 Prompt & Skills 同步库）**
   - 在用户指定的本地目录创建标准分类结构与模板、配置 `.vscode/settings.json`、安装 VS Code 插件、通过 `gh` 浏览器一次性验证码授权、自动创建 GitHub 私有仓库并首次推送。
3. **Mode C：`organize`（整理零散历史 Prompt 到对应模块）**
   - 将用户发来的零散 Prompt 文本去重、清理分隔符、替换一次性正文草稿为 `[在此粘贴...]` 占位符，按极简模板（`## 序号. 标题` + `# Prompt:` + 正文）写入 `prompts/` 下对应的 `.md` 文件并同步到 GitHub。

---

## Quick Start（新电脑一句话启动）

在另一台电脑把本 Skill 放到 Agent 技能目录（或直接将压缩包提供给 AI）后，对 AI 说：

- **恢复已有私有库**：
  > 使用 `$vscode-gitdoc-prompt-vault` 在新电脑帮我恢复我的 GitHub 私有库 `ai-prompts-and-skills` 到 `<你的本地目录>`，配好 VS Code 自动同步并打开。
- **从零新建一套**：
  > 使用 `$vscode-gitdoc-prompt-vault` 在 `<你的本地目录>` 帮我搭一套 VS Code + GitDoc + GitHub 私有库自动同步的 Prompt 和 Skills 仓库。
- **整理零散提示词**：
  > 使用 `$vscode-gitdoc-prompt-vault` 帮我把下面这些提示词整理归档到对应模块并同步到 GitHub。

---

## Utility Scripts（自带辅助脚本）

本 Skill 在 `scripts/` 下提供两个零依赖脚本（Agent 可直接调用，用户也可手动运行）：

### 1. Windows 一键配置 / 恢复脚本：[setup_vault.ps1](./scripts/setup_vault.ps1)

```powershell
# 新电脑一键恢复已有私有库（支持自动装 gh、授权、装 VS Code 插件、克隆并干净启动 VS Code）
powershell -ExecutionPolicy Bypass -File .\scripts\setup_vault.ps1 `
  -Mode restore `
  -RepoName "ai-prompts-and-skills" `
  -TargetDir "D:\AI-Prompt-Vault"

# 从零新建一套本地 + GitHub 私有库
powershell -ExecutionPolicy Bypass -File .\scripts\setup_vault.ps1 `
  -Mode init `
  -RepoName "ai-prompts-and-skills" `
  -TargetDir "D:\AI-Prompt-Vault"

# 仅诊断当前电脑环境（检查 git / gh / code / 插件 / GIT_CONFIG_* 冲突）
powershell -ExecutionPolicy Bypass -File .\scripts\setup_vault.ps1 -Mode diagnose
```

### 2. 跨平台环境诊断与模板生成 CLI：[vault_helper.py](./scripts/vault_helper.py)

纯 Python 标准库（优先用 `uv run`，若无 `uv` 可直接 `python`），默认将诊断结果输出为 JSON 文件便于 Agent 读取：

```bash
# 诊断环境并输出报告文件（检测 git/gh/code、插件状态、GIT_CONFIG_* 污染及 Git.log 报错）
uv run scripts/vault_helper.py diagnose --output diagnose_report.json

# 在指定目录生成标准目录、模板文档与 .vscode/settings.json（不会覆盖已存在文件，除非加 --force）
uv run scripts/vault_helper.py init-templates --target "<本地目录>" --output init_report.json

# 检查 prompts/*.md 是否符合「## 序号. 标题 + # Prompt:」规范并统计条目数
uv run scripts/vault_helper.py check-prompts --target "<本地目录>" --output check_report.json
```

---

## Workflow（Agent 标准执行流程）

### Step 1：环境诊断（先查再做）

先运行诊断确认本机状态：
- 检查 `git`、`code`（VS Code CLI）、`gh`（GitHub CLI）是否已安装；
- 检查 `gh auth status` 是否已登录；
- 检查已安装的 VS Code 插件是否包含 `vsls-contrib.gitdoc` 和 `yzhang.markdown-all-in-one`；
- **关键检查**：检查当前进程环境是否存在 `GIT_CONFIG_COUNT` 且包含空值项（如 `GIT_CONFIG_VALUE_0=""`），详见下文「Common Mistakes」。

### Step 2：安装必备插件与 GitHub CLI

1. **安装 VS Code 插件**：
   ```powershell
   code --install-extension vsls-contrib.gitdoc --force
   code --install-extension yzhang.markdown-all-in-one --force
   ```
2. **安装 GitHub CLI（如未安装）**：
   - Windows：`winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements --silent`
   - macOS：`brew install gh`
   - Linux：参考 [GitHub CLI 官方安装文档](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)

### Step 3：安全的 GitHub 浏览器一次性验证码授权（严禁索要密码）

如果 `gh auth status` 未登录：
1. 在后台运行 Device Flow 授权：
   ```powershell
   gh auth login --hostname github.com --git-protocol https --web --clipboard
   ```
2. 读取输出的 8 位一次性验证码（例如 `XXXX-XXXX`），告知用户在**自己平时已登录 GitHub 的常用浏览器（如 Edge / Chrome）**打开 `https://github.com/login/device` 粘贴验证码并点击 **Continue → Authorize github**。
   - **注意**：不要引导用户在不支持 Passkey 的内置 WebView 窗口里登录。
3. 授权完成后，立刻执行免密 Git 凭证绑定与真实 GitHub 身份配置：
   ```powershell
   gh auth setup-git
   ```
   并通过 `gh api user` 读取用户的 `login`、`id`、`name`、`email`（若 `email` 为空，使用隐私安全的 `<id>+<login>@users.noreply.github.com`），写入：
   ```powershell
   git config --global user.name "<name>"
   git config --global user.email "<email>"
   git config --global core.quotepath false
   ```
   > `core.quotepath false` 在 Windows 上非常关键，可避免中文文件名在 Git 日志中变成八进制乱码。

### Step 4：按模式初始化或恢复仓库

#### 若为 Mode A（`restore`：新电脑恢复已有私有库）
1. 确认目标路径不存在冲突文件后，直接克隆私有仓库：
   ```powershell
   gh repo clone <login>/<repo-name> "<TargetDir>"
   ```
2. 核对 `<TargetDir>\.vscode\settings.json` 是否存在且包含 GitDoc 自动同步配置；若缺失，从 [templates/settings.json](./templates/settings.json) 补齐。
3. 执行 `git -C "<TargetDir>" pull --ff-only` 和 `git -C "<TargetDir>" push --dry-run` 验证免密同步畅通。

#### 若为 Mode B（`init`：从零新建私有库）
1. 复制 [templates/](./templates/) 生成完整目录结构：
   ```text
   <TargetDir>/
   ├── .vscode/
   │   ├── settings.json       # 自动保存(1s) + GitDoc 自动提交(30s)/推送/打开拉取/安全push模式
   │   └── extensions.json     # 推荐插件清单
   ├── .gitignore
   ├── README.md
   ├── prompts/
   │   ├── 01-学术写作与润色.md
   │   ├── 02-翻译与文献精读.md
   │   ├── 03-科研绘图与代码.md
   │   └── 04-通用高频Prompt.md
   └── skills/
       └── _SKILL模板/
           └── SKILL.md
   ```
2. 初始化本地 Git 仓库并完成首次提交：
   ```powershell
   git -C "<TargetDir>" init -b main
   git -C "<TargetDir>" add -A
   git -C "<TargetDir>" commit -m "chore: initialize AI Prompt and Skills vault with GitDoc auto-sync"
   ```
3. 创建 **GitHub 私有仓库** 并推送（若同名仓库已存在则直接绑定 `origin` 并推送）：
   ```powershell
   gh repo create <repo-name> --private --description "Personal AI Prompts and Skills Vault (auto-synced via VS Code GitDoc)" --source="<TargetDir>" --remote=origin --push
   ```

#### 若为 Mode C（`organize`：整理零散 Prompt 写入模块）
1. 先读取现有的 `prompts/*.md`，**严格保留用户已有的自定义条目**；
2. 清洗并归类：
   - 去除 `xxxx` / `%%%%` 等零散分隔符；
   - 合并同一条 Prompt 的多次迭代草稿（保留中英双版及最终精修版）；
   - 将一次性粘贴的论文正文/图例草稿替换为可复用的 `[在此粘贴...]` 占位符；
3. 严格按照以下简洁模板写入：
   ```markdown
   ## 1. 清晰简短的标题
   # Prompt:
   这里直接放可复制使用的提示词正文……
   ```
4. 写入完成后，执行 `git add prompts/`、`git commit`、`git pull --rebase origin main`、`git push origin main` 立刻同步上云。

### Step 5：干净启动 VS Code 并验证（关键防坑步骤！）

1. **在任何 AI Agent / Codex 终端里启动 VS Code 前，必须先清除 `GIT_CONFIG_*` 环境变量**：
   ```powershell
   Get-ChildItem Env:GIT_CONFIG* -ErrorAction SilentlyContinue | Remove-Item
   code --new-window "<TargetDir>" "<TargetDir>\README.md"
   ```
2. **向用户确认以下 4 项验证结果**：
   - 若首次打开弹窗询问「是否信任此文件夹的作者」，点击 **「是，我信任此作者」**；
   - 左下角状态栏显示分支 **`main`**；
   - 按 `F1`（或 `Ctrl + Shift + P`）输入 **`GitDoc`**，下拉列表中出现 **`GitDoc: Commit`** 和 **`GitDoc: Disable`**（代表已启用）；
   - 修改任意文档等待 1 秒自动保存（文件名变黄带 `M`），停手等待 30 秒后文件名自动变回**白色**，且 VS Code 的 `Git.log` 出现 `To https://github.com/<user>/<repo>.git ... main -> main`。

---

## Key Settings Rationale（核心配置说明）

[templates/settings.json](./templates/settings.json) 中的关键参数均经过实测验证：

| 配置项 | 推荐值 | 原因 |
| :--- | :--- | :--- |
| `files.autoSave` / `autoSaveDelay` | `"afterDelay"` / `1000` | 停手 1 秒自动存盘，无需手按 `Ctrl + S` |
| `gitdoc.enabled` | `true` | 开启当前工作区自动提交与同步 |
| `gitdoc.autoCommitDelay` | `30000` | 停手 30 秒后自动提交，避免每打一个字就生成提交 |
| `gitdoc.autoPush` / `autoPull` | `"onCommit"` / `"onPush"` | 提交后立即推送，推送前自动先拉取 |
| `gitdoc.pullOnOpen` / `commitOnClose` | `true` / `true` | 打开 VS Code 自动拉取新版；关闭窗口自动兜底提交 |
| `gitdoc.pushMode` | **`"push"`** | **务必覆盖默认值 `"forcePush"`**，防止多台电脑协作时误强推覆盖另一台电脑的修改 |
| `gitdoc.commitValidationLevel` | `"none"` | 避免 Markdown 格式警告阻塞自动提交 |
| `gitdoc.timeZone` | `"Asia/Shanghai"` | 提交记录显示北京时间（可按需修改） |

---

## Common Mistakes & Troubleshooting（必看排坑清单）

遇到异常时优先查阅 [references/troubleshooting.md](./references/troubleshooting.md)，最高频的 4 个坑如下：

1. **按 `F1` 搜 `GitDoc` 看不到 `GitDoc: Disable` / `GitDoc: Commit`**
   - **最常见原因**：从 OpenAI Codex 或其他 AI 工具终端用 `code` 命令启动 VS Code 时，继承了带空值的 `GIT_CONFIG_COUNT` / `GIT_CONFIG_VALUE_0=""`，导致 VS Code 内置 Git 每次执行都报 `error: missing config value GIT_CONFIG_VALUE_0`，识别到 0 个仓库。
   - **解决**：关掉那个 VS Code 窗口，清除 `Env:GIT_CONFIG*` 后重新启动，或直接从桌面/开始菜单打开 VS Code 再通过「文件 → 打开最近的文件」进入。
2. **打开 `github.com/login/device` 没看到验证码框，或 Passkey 登录失败**
   - 内置 WebView 浏览器未登录 GitHub 且不完整支持 Passkey。请改用系统常规浏览器（Edge / Chrome）打开 `https://github.com/login/device` 粘贴 8 位验证码。
3. **GitDoc 自动提交静默失败**
   - 未配置 `git config --global user.name` / `user.email`，或工作区处于「受限模式（未点击信任作者）」。
4. **文件名颜色含义速查**
   - **黄色 `M`**：已改完并自动存到本地，等待 30 秒自动推送；
   - **绿色 `U`**：新建文件，等待 30 秒自动推送；
   - **白色（无字母）**：已成功同步到 GitHub 私有库，本地与云端一致。
