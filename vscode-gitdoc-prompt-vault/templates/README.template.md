# AI Prompt & Skills 个人知识库

用于长期沉淀、修改和同步日常与 Gemini、GPT、Claude 等 AI 沟通时使用的 **Prompt** 和 **Skills**。  
已配置 VS Code 自动保存（1 秒）+ **GitDoc** 自动同步（30 秒）到 GitHub 私有仓库。

---

## 目录结构

```text
.
├── prompts/                     # 常用 Prompt 集合（按场景分类）
│   ├── 01-学术写作与润色.md
│   ├── 02-翻译与文献精读.md
│   ├── 03-科研绘图与代码.md
│   └── 04-通用高频Prompt.md
├── skills/                      # 复杂规则 / Agent Skills（标准 SKILL.md 格式）
│   └── _SKILL模板/SKILL.md      # 复制此文件夹即可新建一个 Skill
└── README.md                    # 本说明文档
```

---

## 日常使用指南

1. **直接记录**：点开左侧任意 `.md` 文件直接编写，VS Code 已开启**自动保存**，无需按 `Ctrl + S`。
2. **颜色状态速查**：
   - **黄色 `M`**：已修改并存到本地，等待 30 秒自动同步；
   - **绿色 `U`**：新建文件，等待 30 秒自动同步；
   - **白色（无字母）**：已成功同步到 GitHub 私有库。
3. **快速查找 Prompt**：
   - `Ctrl + P`：按文件名快速跳转；
   - `Ctrl + Shift + F`：全库搜索任意关键词；
   - `F1` 输入 `GitDoc`：查看同步状态（出现 `GitDoc: Disable` 表示已开启，点 `GitDoc: Commit` 可立即手动同步）。
