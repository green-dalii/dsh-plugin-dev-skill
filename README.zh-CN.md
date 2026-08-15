# Deepseek Harness Plugin Dev Skill

[English](README.md) | **简体中文**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Docs](https://img.shields.io/badge/Docs-DeepSeek%20Harness-blue)](https://deepseek-harness.github.io/deepseek-harness/develop/basic/)

让任何 Agent 都能正确、高效、符合规范地开发 **DeepSeek Harness（DSH）** 插件的技能包。

**核心交付物**：[`SKILL.md`](SKILL.md) —— 一份 Agent 可直接加载的操作手册，包含心智模型、代码模板、分步开发流程与验证清单；深度背景见 [`References/`](References/00-INDEX.md) 下的精简提炼资料。

## 特点

- 🧠 **基于第一性原理**：把 DSH 底层框架 Cordis 的"可逆效应 + 反应式余效应"理论落到可执行的铁律与模板
- 🧩 **覆盖全类型插件**：Tool（`defineTool`）、LLM 适配器、服务提供方/消费方、钩子、配置、打包发布
- ✅ **模板经过真实 SDK 验证**：所有示例代码通过 `tsc --strict` 类型检查，并端到端跑通真实 Cordis loader
- 🔗 **可追踪官方更新**：每篇参考文档末尾附官方文档 URL，官方更新后可对照修订

## 结构

```
dsh-plugin-dev-skill/
├── SKILL.md                     # 主技能文件：操作手册（Agent 接入后先读这个）
├── README.md                    # 英文说明（默认）
├── README.zh-CN.md              # 本文件（中文说明）
├── CHANGELOG.md                 # 变更日志
├── CONTRIBUTING.md              # 贡献指南
├── SECURITY.md                  # 安全政策
├── LICENSE                      # MIT
└── References/                  # 人机可读的精简提炼参考资料
    ├── 00-INDEX.md              # 索引
    ├── 01-dsh-architecture.md   # DSH 架构总览
    ├── 02-plugin-basics.md      # 插件基础：形态/生命周期/effect/HMR
    ├── 03-tools.md              # 工具开发完整参考（defineTool）
    ├── 04-config.md             # 插件配置与 Schemastery
    ├── 05-llm-adapter.md        # LLM 适配器指南
    ├── 06-framework-services-events.md  # 服务与依赖、事件系统
    ├── 07-publish.md            # 打包/安装/profile/配置层
    ├── 08-capability-layering.md# 三种角色能力设计与 seam 目录
    ├── 09-cordis-primer.md      # Cordis 入门与 ctx API 速查
    ├── 10-spatiotemporal.md     # 论文解读（时空可组合性）
    └── 11-cookbook.md           # 扩展模式（钩子/UI/协议桥/功能→机制）
```

## 使用方法

1. **Agent**：加载 `SKILL.md`，按其中的开发流程（侦察 → 实现 → 验证 → 交付）执行；需要深度背景时查阅 `References/` 对应文件。
2. **人类**：直接阅读 `SKILL.md` 与 `References/` 即可了解 DSH 插件开发全貌。

## 作为 DSH 技能安装（可选）

DSH 的 skill 系统接受“目录包（`<name>/SKILL.md`）”或“平铺 Markdown（`<name>.md`）”两种形态，本地发现根目录按优先级：

| 根目录 | 适用场景 |
|---|---|
| `<项目根>/.dsh/skills` | 项目级（rank 100） |
| `<项目根>/.agents/skills` | 项目级（rank 200） |
| `$DSH_HOME/skills`（即 `~/.dsh/skills`） | 用户级（rank 400） |

例如安装为用户级技能（**安装目录名必须与 SKILL.md frontmatter 中的 `name` 一致**，即 `dsh-plugin-dev-skill`）：

```sh
mkdir -p ~/.dsh/skills/dsh-plugin-dev-skill
cp SKILL.md ~/.dsh/skills/dsh-plugin-dev-skill/SKILL.md
cp -r References ~/.dsh/skills/dsh-plugin-dev-skill/References
```

技能名需符合 kebab-case（`^[a-z0-9]+(?:-[a-z0-9]+)*$`）。

## 在其他 Agent 中使用（Claude Code、Codex 等）

本技能遵循开放的 [Agent Skills 标准](https://agentskills.io)：一个包含 `SKILL.md` 与 YAML frontmatter（`name` / `description` / `whenToUse`）及配套 `References/` 目录的文件夹——与 Claude Code、Codex 及众多 Agent 宿主使用的形态一致，凡是支持 Agent Skills 的地方都可以安装。

### 方式 A：让 Agent 自己安装（推荐）

最简单的方式：**直接把仓库地址告诉你的 Agent**，让它自行克隆并安装。例如在 Claude Code 会话里粘贴：

> 请把 https://github.com/green-dalii/dsh-plugin-dev-skill 这个技能安装到 `~/.claude/skills/dsh-plugin-dev-skill/`，之后我处理 DeepSeek Harness 插件开发时加载 `SKILL.md`。

或者在 Codex CLI 会话里粘贴：

> 请把 https://github.com/green-dalii/dsh-plugin-dev-skill 这个技能安装到 `~/.agents/skills/dsh-plugin-dev-skill/`。

通用说法（适用于任何 Agent）：

> 请把 https://github.com/green-dalii/dsh-plugin-dev-skill 安装到你的技能目录（文件夹 `dsh-plugin-dev-skill`，内含 `SKILL.md` 与 `References/`），当任务涉及开发 DeepSeek Harness（DSH）插件时使用它。

### 方式 B：手动安装

| Agent / 宿主 | 安装位置 | 调用方式 |
|---|---|---|
| Claude Code（个人级） | `~/.claude/skills/dsh-plugin-dev-skill/SKILL.md` | `/dsh-plugin-dev-skill`，或描述匹配时自动加载 |
| Claude Code（项目级） | `<仓库>/.claude/skills/dsh-plugin-dev-skill/SKILL.md` | 同上 |
| Codex CLI（用户级） | `~/.agents/skills/dsh-plugin-dev-skill/SKILL.md` | `/skills` 浏览，`$dsh-plugin-dev-skill` 提及 |
| Codex CLI（仓库级） | `<仓库>/.agents/skills/dsh-plugin-dev-skill/SKILL.md` | 同上 |
| DSH | `~/.dsh/skills/dsh-plugin-dev-skill/SKILL.md` | 见上方 DSH 安装小节 |
| 任意 Agent Skills 宿主 | `<技能目录>/dsh-plugin-dev-skill/SKILL.md` | 按宿主说明 |

用 git clone 直接安装（或用符号链接——Claude Code 与 Codex 都支持 symlink，`git pull` 即可保持技能更新）：

```sh
git clone https://github.com/green-dalii/dsh-plugin-dev-skill.git ~/.claude/skills/dsh-plugin-dev-skill
# 或：
ln -s /path/to/dsh-plugin-dev-skill ~/.claude/skills/dsh-plugin-dev-skill
```

注意事项：

- 文件夹名请保持 `dsh-plugin-dev-skill`——必须与 frontmatter 中的 `name` 一致（Claude Code 会用它作为命令名）。
- 不支持的宿主会忽略 `whenToUse` 等扩展 frontmatter 字段，不影响加载。
- 技能正文目前为中文（与官方 DSH 文档一致），代码模板与语言无关。
- 彩蛋：DSH 同样读取项目级 `.agents/skills`，所以在 `<仓库>/.agents/skills/dsh-plugin-dev-skill/` 放一份，Codex 与 DSH 可以共用。

## 资料来源

- 官方文档站（中文/英文）：https://deepseek-harness.github.io/deepseek-harness/develop/basic/
- 源码仓库：https://github.com/deepseek-ai/deepseek-harness
- 论文：《A Programming Paradigm for Spatiotemporal Composability》（Cordis 框架的学术基础）：https://github.com/cordiverse/paper/blob/main/paper.pdf

所有参考文档均为**精简提炼**（不是官方文档照搬），以“开发出正确、高效、符合规范的插件”为目标组织。

## 贡献

欢迎提交 Issue 与 PR！请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全相关问题见 [SECURITY.md](SECURITY.md)。

## 许可

[MIT](LICENSE) © 2026 green-dalii
