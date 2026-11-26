# VS Code + GitDoc + GitHub 私有库：Prompt & Skills 全自动同步 Skill

把你在日常与 Gemini、GPT、Claude 等 AI 沟通中沉淀的 **Prompt** 和 **Skills** 整理进 VS Code 的本地 Markdown 知识库，并通过 **GitDoc 插件 + GitHub 私有仓库** 实现 **100% 免费、跨电脑无缝同步、改完自动保存并推送、打开自动拉取、永久保留历史版本**。

**适用环境** · Windows（提供一键 PowerShell 脚本）/ macOS / Linux · VS Code · Git · GitHub CLI (`gh`) · 兼容 Antigravity / Codex / Claude Code / Gemini CLI

---

## 核心特性

- **完全免费 & 隐私可控**：代码与文档全部存在你自己的 **GitHub Private（私有）仓库** 与本地硬盘，不绑定任何付费软件。
- **云文档级无感同步**：
  - 停手 **1 秒** → VS Code 自动保存到本地硬盘；
  - 停手 **30 秒 / 关闭窗口** → `GitDoc` 自动提交（北京时间）并安全推送（`pushMode: "push"`，防多端覆盖）；
  - 下次打开 VS Code → 自动拉取云端最新版本并恢复上次阅读的标签页。
- **三合一能力**：
  1. **新电脑一键恢复**：一键装插件、浏览器安全授权登录 GitHub、拉取已有私有库并干净打开 VS Code；
  2. **从零新建知识库**：自动生成 `prompts/01~04`、`skills/_SKILL模板`、`.vscode/settings.json` 并创建 GitHub 私有库；
  3. **零散 Prompt 归档**：自动去重清洗并按统一简洁模板（`## 序号. 标题` + `# Prompt:`）写入对应模块。
- **内置真实避坑修复**：自动清理 Windows 上部分 AI 工具注入的空值 `GIT_CONFIG_VALUE_*` 环境变量，彻底解决 VS Code 内置 Git 报 `missing config value GIT_CONFIG_VALUE_0` 导致 `GitDoc` 消失的隐蔽问题。

---

## 在另一台电脑上使用（两种方式任选）

### 方式一：喂给 AI 自动执行（最省心，推荐）

1. 在本仓库首页点击下载 **[vscode-gitdoc-prompt-vault.zip](./vscode-gitdoc-prompt-vault.zip)**（或点击 **Code → Download ZIP** 解压）。
2. 把解压得到的 **`vscode-gitdoc-prompt-vault`** 文件夹放入你常用 AI 工具的全局 Skills 目录（若目录不存在先新建）：
   - **Antigravity 2.0**：`%USERPROFILE%\.gemini\config\skills\`
   - **Codex**：`%USERPROFILE%\.codex\skills\`（或 `%USERPROFILE%\.agents\skills\`）
   - **Claude Code**：`%USERPROFILE%\.claude\skills\`
   - *(也可以直接把 `vscode-gitdoc-prompt-vault.zip` 压缩包发给任意 AI 助手让它按里面的 `SKILL.md` 执行)*
3. 打开一个新对话，复制并发送下面这句话（把路径和仓库名改成你自己的）：

   **场景 A：新电脑恢复已有私有库**
   > 使用 `$vscode-gitdoc-prompt-vault` 在这台新电脑帮我恢复我的 GitHub 私有库 `ai-prompts-and-skills` 到 `D:\AI-Prompt-Vault`，配好 VS Code 和 GitDoc 自动同步并打开。

   **场景 B：从零搭建一套新的 Prompt & Skills 同步库**
   > 使用 `$vscode-gitdoc-prompt-vault` 在 `D:\AI-Prompt-Vault` 帮我新建一套 VS Code + GitDoc + GitHub 私有库自动同步的 Prompt 和 Skills 仓库。

4. 过程中如首次登录 GitHub，AI 会给出一个 **8 位一次性验证码**，你在 Edge / Chrome 浏览器打开 `https://github.com/login/device` 粘贴确认即可（全程无需泄露密码）。

---

### 方式二：自己动手一键跑脚本（Windows）

下载并解压 [vscode-gitdoc-prompt-vault.zip](./vscode-gitdoc-prompt-vault.zip) 后，在解压目录里打开 PowerShell 执行一条命令即可：

```powershell
# 新电脑一键恢复已有私有库
powershell -ExecutionPolicy Bypass -File .\vscode-gitdoc-prompt-vault\scripts\setup_vault.ps1 `
  -Mode restore `
  -RepoName "ai-prompts-and-skills" `
  -TargetDir "D:\AI-Prompt-Vault"

# 或者：从零新建一套私有库
powershell -ExecutionPolicy Bypass -File .\vscode-gitdoc-prompt-vault\scripts\setup_vault.ps1 `
  -Mode init `
  -RepoName "ai-prompts-and-skills" `
  -TargetDir "D:\AI-Prompt-Vault"

# 仅做环境体检（排查插件、登录状态与 GIT_CONFIG 环境变量冲突）
powershell -ExecutionPolicy Bypass -File .\vscode-gitdoc-prompt-vault\scripts\setup_vault.ps1 -Mode diagnose
```

---

## 日常使用速查

- **看文件名颜色判断同步状态**：
  - **黄色 `M`**：已修改并自动保存到本地，等待 30 秒自动推送；
  - **绿色 `U`**：新建文件，等待 30 秒自动推送；
  - **白色（无字母）**：已成功同步到 GitHub 私有库。
- **确认 GitDoc 运行状态**：在 VS Code 按 **`F1`** 输入 `GitDoc`，看到 **`GitDoc: Commit`** 和 **`GitDoc: Disable`** 即表示自动同步处于开启状态（不要点 Disable）。
- **快速查找提示词**：`Ctrl + P` 搜文件名，`Ctrl + Shift + F` 全库搜关键词。

---

## 仓库文件结构

```text
.
├── README.md                                  # 本说明文档
├── vscode-gitdoc-prompt-vault.zip             # 打包好的 Skill 压缩包（可直接下载导入或喂给 AI）
└── vscode-gitdoc-prompt-vault/                # 完整 Skill 源码（可在线浏览）
    ├── SKILL.md                               # Agent 完整执行手册与工作流定义
    ├── scripts/
    │   ├── setup_vault.ps1                    # Windows 一键恢复 / 初始化 / 诊断脚本
    │   └── vault_helper.py                    # 跨平台 Python 诊断、建模板与 Prompt 格式审计工具
    ├── templates/                             # VS Code 配置与 Markdown 模板
    │   ├── settings.json
    │   ├── extensions.json
    │   ├── gitignore
    │   ├── README.template.md
    │   ├── prompt-module.template.md
    │   └── SKILL.template.md
    └── references/
        └── troubleshooting.md                 # 实战排坑手册
```

---

## 详细文档直达

- [Skill 完整执行手册（SKILL.md）](./vscode-gitdoc-prompt-vault/SKILL.md)
- [实战排坑手册（troubleshooting.md）](./vscode-gitdoc-prompt-vault/references/troubleshooting.md)
