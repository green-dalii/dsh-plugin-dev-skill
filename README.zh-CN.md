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

## 资料来源

- 官方文档站（中文/英文）：https://deepseek-harness.github.io/deepseek-harness/develop/basic/
- 源码仓库：https://github.com/deepseek-ai/deepseek-harness
- 论文：《A Programming Paradigm for Spatiotemporal Composability》（Cordis 框架的学术基础）：https://github.com/cordiverse/paper/blob/main/paper.pdf

所有参考文档均为**精简提炼**（不是官方文档照搬），以“开发出正确、高效、符合规范的插件”为目标组织。

## 贡献

欢迎提交 Issue 与 PR！请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全相关问题见 [SECURITY.md](SECURITY.md)。

## 许可

[MIT](LICENSE) © 2026 green-dalii
