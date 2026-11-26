# 实战排坑手册（Troubleshooting）

本手册汇总了在 Windows 上搭建与迁移 **VS Code + GitDoc + GitHub 私有库** 过程中的真实高频问题及根治方案。

---

## 问题 1：按 `F1` 输入 `GitDoc` 找不到 `GitDoc: Disable` 或 `GitDoc: Commit`

### 现象
- `vsls-contrib.gitdoc` 扩展已安装且已激活，但命令面板中搜索 `GitDoc` 没有任何命令，左下角也没有 `main` 分支图标。
- 查看 `%APPDATA%\Code\logs\<最新会话>\window*\exthost\vscode.git\Git.log` 会看到：
  ```text
  > git rev-parse --show-toplevel
  error: missing config value GIT_CONFIG_VALUE_0
  fatal: unable to parse command-line config
  Initial repository scan completed - repositories (0)
  ```

### 根因
在 Windows 上，某些 AI 桌面工具（如 OpenAI Codex）会在其子进程环境中注入 `GIT_CONFIG_COUNT=10` 以及若干空值变量（例如 `GIT_CONFIG_VALUE_0=""`）。如果直接从这类终端运行 `code --new-window`，VS Code 会把这些环境变量继承进新窗口；而 VS Code 内置的 `vscode.git` 在派生 `git.exe` 时会丢弃空字符串环境变量，导致 `git.exe` 认为 `GIT_CONFIG_VALUE_0` 缺失并直接报错，从而无法识别任何 Git 仓库，`GitDoc` 的激活条件 `gitOpenRepositoryCount != 0` 永远为假。

### 解决方案
1. **如果正在用脚本/终端打开 VS Code**：启动 `code` 前务必先清理当前进程中的 `GIT_CONFIG_*`：
   ```powershell
   Get-ChildItem Env:GIT_CONFIG* -ErrorAction SilentlyContinue | Remove-Item
   code --new-window "<你的知识库路径>"
   ```
2. **如果窗口已经打开并中招**：直接点右上角 `×` 关掉那个受污染的 VS Code 窗口，然后从桌面/开始菜单重新打开 VS Code，点 **「文件 → 打开最近的文件」** 重新进入仓库即可恢复正常。

---

## 问题 2：打开 `https://github.com/login/device` 没看到一次性验证码框，或 Passkey 报错

### 现象
- 跳转到了 `Sign in to GitHub` 登录页，且提示 `This browser or device is reporting partial passkey support / Authentication failed`。

### 根因
点击聊天中的链接时可能默认打开了应用内置的 WebView 浏览器，里面没有登录 GitHub 且对 Passkey 支持不完整。

### 解决方案
- 复制地址 `https://github.com/login/device` 到你电脑平时常用的 **Edge 或 Chrome 浏览器**（已登录 GitHub 的浏览器）中打开，粘贴 8 位一次性验证码确认授权即可。

---

## 问题 3：多台电脑同时使用时，如何防止互相覆盖？

### 关键配置
GitDoc 插件的 `gitdoc.pushMode` 默认值是 **`"forcePush"`**（强制推送），多台电脑切换使用时存在覆盖另一台电脑提交的风险！

### 解决方案
在 `.vscode/settings.json` 中**必须显式改为安全模式**：
```json
"gitdoc.pushMode": "push",
"gitdoc.autoPull": "onPush",
"gitdoc.pullOnOpen": true
```
这样每次打开 VS Code 会先拉取远端最新内容，每次推送前也会先拉取合并，不会暴力覆盖。

---

## 问题 4：Git 提交记录或日志中中文文件名显示为 `\345\255...` 乱码

### 解决方案
开启 Git 原生 UTF-8 路径显示：
```powershell
git config --global core.quotepath false
```

---

## 问题 5：为什么修改文件后看不到标签页右上角的小白点？

因为 `.vscode/settings.json` 已设置 `"files.autoSaveDelay": 1000`（1 秒自动保存），停手 1 秒就已经自动存盘了。判断同步状态的正确方式是看**文件名颜色**：
- **黄色 + `M`**：已修改并自动保存到本地，等待 30 秒自动推送到 GitHub；
- **绿色 + `U`**：新建文件，等待 30 秒自动推送到 GitHub；
- **白色（无字母）**：已成功同步到 GitHub 私有库。

---

## 问题 6：如何验证 GitDoc 是否真的把修改推上了 GitHub？

1. 随便在任意 `.md` 文件末尾加一行测试文字，停手等 30 秒；
2. 观察文件名从 **黄色 `M`** 变回 **白色**；
3. 或在本地执行以下命令核对：
   ```powershell
   git -C "<知识库路径>" log -n 3 --oneline
   git -C "<知识库路径>" status --short --branch
   ```
   看到 `## main...origin/main`（无 `ahead` 提示）即代表远端已收到最新提交。
