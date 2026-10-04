# 参考资料索引（References）

本目录是 **DeepSeek Harness（DSH）插件开发**的人机可读精简提炼资料，由官方文档站
（https://deepseek-harness.github.io/deepseek-harness/ ）与仓库源码（https://github.com/deepseek-ai/deepseek-harness ）
提炼而成，**不是官方文档的照搬**，而是面向“开发插件”这一目标的高信号浓缩。

使用方式：先读项目根目录的 `SKILL.md`（操作手册），需要深度背景时按需查阅本目录对应文件。

**SDK 基线**：所有 API 陈述以 `@deepseek-ai/*` **0.2.1-alpha.1**（cordis **4.0.5-alpha.1**）的类型定义实测为准。0.2.1-alpha.1 对 tool / LLM / service 插件的公共 API 0 破坏；主要 web 体验改善、HMR 增强与 `invariant` 诊断路径清理。官方文档站发布 `develop/**`、`guide/**`、`reference/**` 与部分 `subsystems/{ptc-runtime, schedule, approval, claude-code-mods, …}`；而 `docs/glossary`、`docs/event-producer-consumer`、`docs/defensive-patterns` 与多数 `docs/subsystems/*`（`deliverables`、`mcp`、`ssh`、`browser-use`、`computer-use`、`otel`、`product-telemetry`、`boot`、`voice-input`、`office-to-pdf` 等）**仅存在于仓库**，相关链接指向 GitHub blob。

| 文件 | 主题 | 官方对应章节 |
|---|---|---|
| `01-dsh-architecture.md` | DSH 架构总览：CLI、profile、bundle、配置层、插件加载 | guide + develop/basic + 架构（仓库） |
| `02-plugin-basics.md` | 第一个插件、三种形态、inject、effect、生命周期、HMR | develop/basic/、develop/framework/、cordis-tutorial 1-2 |
| `03-tools.md` | 工具开发完整参考：defineTool、执行流水线、后台任务、UI 卡片 | develop/basic/tool、cookbook/adding-a-tool、subsystems/tools、tool-execution-pipeline |
| `04-config.md` | 插件配置与 Schemastery schema、设置页 | develop/basic/config、cordis-tutorial 5、cookbook/adding-a-settings-card |
| `05-llm-adapter.md` | LLM 适配器完整指南：LlmAdapter、StreamChunk、GenerateOptions | develop/practice/llm-adapter、cookbook/adding-an-llm-adapter、subsystems/llm-streaming |
| `06-framework-services-events.md` | 服务与依赖、事件系统、作用域过滤分发、生产方契约 | develop/framework/、cordis-tutorial 3-4、cordis-api/* |
| `07-publish.md` | 打包、安装、profile、配置层顺序、运行时依赖归属 | develop/basic/publish + CLI 参考 |
| `08-capability-layering.md` | 三种角色能力设计 + 能力 seam 目录 | develop/practice/、reference/capability-seams |
| `09-cordis-primer.md` | Cordis 入门：核心概念、分发模式、ctx API 速查 | reference/cordis-primer、cordis-api/* |
| `10-spatiotemporal.md` | 论文《A Programming Paradigm for Spatiotemporal Composability》解读 | [arXiv:2608.25512](https://arxiv.org/abs/2608.25512) |
| `11-cookbook.md` | 扩展模式：权限门禁、UI 插件、协议桥、功能→机制映射 | reference/cookbook/extension-cookbook、subsystems/conversation |

原始材料：

- 官方文档站（中文/英文双语）：`develop/basic/`、`develop/framework/`、`develop/practice/`、`develop/cordis-tutorial/`、`reference/`
- 仓库：https://github.com/deepseek-ai/deepseek-harness
- 论文：《A Programming Paradigm for Spatiotemporal Composability》（DeepSeek-AI / 北京大学，Cordis 框架的学术基础，Shi / Zhang / Cui, 2026）：
  https://arxiv.org/abs/2608.25512

## 术语对照（上游重命名备忘）

| 旧 | 新 | 说明 |
|---|---|---|
| Code Mode / `code-mode` | **PTC mode** / `ptc` | `dsh-tools` 呈现模式 `native` / `ptc` / `both` |
| `CallId` | **`ToolCallId`** | `@deepseek-ai/dsh-llm` 已不再导出旧名 |
| `ctx.codeRuntime` | **`ctx.ptcRuntime`** | **0.2.0 已落地**：包 `dsh-code-runtime`→`dsh-ptc-runtime`，提供方 `dsh-code-runtime-worker-thread`→`dsh-ptc-runtime-node` |
| `agent/session-start` | **`agent/created`** | 0.2.0 合并进 `agent/created`，且分发模式由 `emit` 改为 **`serial`** |
| profile `patchReload` | **（字段已删除）** | HMR 改由 YAML 组合里 `dsh-hmr` 行的 `disabled` / `root` 决定 |
| `e2b` / `fs-e2b` / `subprocess-e2b` / `ctx.e2b` | **SSH 家族** | 0.2.0 移除 E2B，远程能力改由 `ssh` / `fs-ssh` / `subprocess-ssh` / `sandbox-ssh` 承担 |
| `cordis-plugin-hmr` | **`dsh-hmr`** | 插件包改名；`ctx.hmr` 仍可用 |
| `preset/agent-presets` | **`preset/agent-preset` + `preset/agent-preset-registry`** | 0.2.0 拆包 |
