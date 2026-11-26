# 参考资料索引（References）

> 本目录是 DSH 插件开发的**操作手册正文**，由官方文档站（https://deepseek-harness.github.io/deepseek-harness/ ）与仓库源码
> 提炼而成——**不是官方文档的照搬**，而是面向「开发插件」这一目标的高信号浓缩。仓库根的 `SKILL.md` 是**索引与铁律**（≤ 8192 字符）。
> SDK 基线：`@deepseek-ai/*` **0.2.3-alpha.2**（cordis **4.2.0-alpha.1**）。

**为什么每篇都要 ≤ 8192 字符**：DSH 的 `compaction-tool-result-pruner` 配置为 `thresholdChars: 8192` / `headChars: 4096` / `tailChars: 1024`（`standard` / `ptc` / `cordis` 三个 preset 相同），超过阈值的 tool result 在压缩时**只保留首尾**。技能正文是通过 tool result 送达模型的，所以任何一篇超过 8192 字符，长会话里就会被砍掉中间——这不是风格问题，是「读不到」问题。`scripts/verify.sh` 会强制守住这条线。

## 文件总览

| 文件 | 主题 | 上游对应 |
|---|---|---|
| `00-INDEX.md` | 本文件：文件总览、SDK 基线、术语对照 | — |
| `01-dsh-architecture.md` | DSH 架构总览：CLI、profile/bundle、配置层、插件加载、内核主干、事件域 | guide + develop/basic + docs/architecture（仓库） |
| `02-plugin-basics.md` | 插件是什么、运行时与包地图、三种形态、inject/effect、Fiber 状态机、HMR | develop/basic/、develop/framework/、cordis-tutorial 1-2 |
| `03-tools.md` | 工具基础：最小形态、execute 契约、定义级元数据、ValueSchemaSpec | develop/basic/tool、cookbook/adding-a-tool |
| `03b-tools-advanced.md` | 工具进阶：后台任务、执行策略与观测、UI 卡片 | subsystems/tools、tool-execution-pipeline |
| `03c-tools-pipeline.md` | 工具流水线：作用域与「步骤准入」、executor 插件 | reference/subsystems/tools、executor 包源码 |
| `03d-ptc-runtime.md` | PTC 运行时：程序格式、scoped REPL、截断、检查 | docs/upgrade-guide/* |
| `04-config.md` | 插件配置与 Schemastery：Config 导出、严格校验、`!!js`、设置页 | develop/basic/config、cordis-tutorial 5、cookbook/adding-a-settings-card |
| `05-llm-adapter.md` | LLM 适配器：LlmAdapter、StreamChunk 协议、GenerateOptions、注册 | develop/practice/llm-adapter、cookbook/adding-an-llm-adapter |
| `05b-llm-errors.md` | LLM 错误：LLM_FAILURE_CODES、retryChoice、fromFailure、HarnessError、pi-ai 1.3.0 | subsystems/llm-streaming、`dsh-llm` 类型定义 |
| `06-services.md` | 服务与依赖：消费方/提供方、服务隔离、依赖行为语义 | develop/framework/、cordis-tutorial 3-4 |
| `06b-events.md` | 事件系统：分发模式、类型安全、作用域过滤、常用 Harness 事件速览 | develop/framework/、cordis-api/*、event-producer-consumer（仓库） |
| `07-publish.md` | 打包与安装：bundle/profile、安装移除、配置层顺序 | develop/basic/publish、`apps/cli` 参考 |
| `07b-publish-advanced.md` | 发布进阶：git 安装坑、表层组合包、组合包作者六件事、重装已安装包 | CLI 参考 + docs/upgrade-guide/* |
| `08-capability-layering.md` | 能力分层：Service Definition / Provider / Consumer 与三步实现 | develop/practice/、reference/capability-seams |
| `08b-seams-core.md` | 能力 Seam 目录（一）：核心服务（llm…tokenMeter，32 条） | reference/capability-seams |
| `08c-seams-platform.md` | 能力 Seam 目录（二）：平台与 UI（ptcRuntime…pluginRecommendations，34 条） | reference/capability-seams |
| `09-cordis-primer.md` | Cordis 入门：五个核心概念、分发模式、waterfall、Service、Fiber、Loader | reference/cordis-primer、cordis-tutorial |
| `09b-cordis-ctx-api.md` | Cordis ctx API 速查：框架继承面 + 常用成员 | cordis-api/*、`vendor/cordis` 源码 |
| `10-spatiotemporal.md` | 论文《A Programming Paradigm for Spatiotemporal Composability》解读 | [arXiv:2608.25512](https://arxiv.org/abs/2608.25512) |
| `11-cookbook.md` | 扩展模式：权限门禁、UI 插件、协议桥、功能→机制映射 | reference/cookbook/extension-cookbook、subsystems/conversation |
| `12-mistakes.md` | 通用错误与修正（与版本无关的设计 / 实现错误） | docs/defensive-patterns（仓库） |
| `12b-migration-errors.md` | 版本迁移错误（至 rc.3）：带版本标记的破坏性变更对照表 | docs/upgrade-guide/* |
| `12c-migration-errors.md` | 版本迁移错误（rc.4 ~ 0.2.3-alpha.2） | docs/upgrade-guide/* |
| `13-upgrade-guides.md` | 升级指南原文索引、官方链接、⚠️ master 陷阱、与 `dsh-doc` 的分工 | docs/upgrade-guide/README.md、`dsh-doc` skill 源码 |
| `14-workflow-and-scope.md` | 开发流程四阶段 + 覆盖范围边界（UI / Schedule / 子代理 / Web 搜索） | docs/upgrade-guide（宿主侧篇目） |
| `15-self-update.md` | 本技能的自我更新流程（载入后必跑的完整版） | 本仓库 |

原始材料：

- 官方文档站（中英双语）：`develop/basic/`、`develop/framework/`、`develop/practice/`、`develop/cordis-tutorial/`、`reference/`
- 仓库：https://github.com/deepseek-ai/deepseek-harness
- 论文：《A Programming Paradigm for Spatiotemporal Composability》（DeepSeek-AI / 北京大学，Cordis 框架的学术基础，Shi / Zhang / Cui, 2026）：https://arxiv.org/abs/2608.25512

## 术语对照（上游重命名备忘）

| 旧 | 新 | 说明 |
|---|---|---|
| Code Mode / `code-mode` | **PTC mode** / `ptc` | **0.2.1-rc.2 起**：呈现模式改由 `@deepseek-ai/dsh-tool-executor-native` / `-ptc` 两个 executor 插件承担（旧的 `dsh-tools` `mode` 配置与 `ctx.tools.presentAs()` 已删除 / 移除） |
| `CallId` | **`ToolCallId`** | `@deepseek-ai/dsh-llm` 已不再导出旧名 |
| `ctx.codeRuntime` | **`ctx.ptcRuntime`** | **0.2.0 已落地**：包 `dsh-code-runtime`→`dsh-ptc-runtime`，提供方 `dsh-code-runtime-worker-thread`→`dsh-ptc-runtime-node` |
| `agent/session-start` | **`agent/created`** | 0.2.0 合并进 `agent/created`，且分发模式由 `emit` 改为 **`serial`** |
| profile `patchReload` | **（字段已删除）** | HMR 改由 YAML 组合里 `dsh-hmr` 行的 `disabled` / `root` 决定 |
| `e2b` / `fs-e2b` / `subprocess-e2b` / `ctx.e2b` | **SSH 家族** | 0.2.0 移除 E2B，远程能力改由 `ssh` / `fs-ssh` / `subprocess-ssh` / `sandbox-ssh` 承担 |
| `cordis-plugin-hmr` | **`dsh-hmr`** | 插件包改名；`ctx.hmr` 仍可用 |
| `preset/agent-presets` | **`preset/agent-preset` + `preset/agent-preset-registry`** | 0.2.0 拆包 |
| `dsh-tools` 的 `mode` 配置 / `ctx.tools.presentAs()` | **executor 插件** | 0.2.1-rc.2 删除 / 移除；改挂 `@deepseek-ai/dsh-tool-executor-native` 或 `-ptc` |
| `system-prompt/assemble` 里的工具数组 | **注册项的 `when` 条件** | 0.2.1-rc.2 起 assemble 不携带工具数组 |
| `ctx.sessionProjections.register(def)` 返回 disposer | **`Promise<ProjectionHandle<S>>`** | 0.2.1-rc.2 起返回 thenable（`instanceof Promise` 为 `false`），须 await 并持有 handle |
| `@deepseek-ai/dsh-app-boot` 的 bundle 清单导出 | **`@deepseek-ai/dsh-official-bundles`** | 0.2.1-rc.2 迁包（`initProfile` / `loadProfile` 仍在 `dsh-app-boot`） |
| `dsh-tool-subagent` 的 `modelSelectionSettings` | **`modelSelection`** | 0.2.1-rc.1 改名；模型发现另需 `modelDiscovery: true` |
| `ctx.officeToPdf` / `dsh-office-to-pdf` | **`ctx.officeKit` / `dsh-office-kit`** | 0.2.2-alpha.3 改名；行 id `office-kit`、Remote `officeKit/*`、类型 `OfficeKit*` |
| `send_message({ agent_id })` / `interrupt_agent({ agent_id })` | **`{ agent }`** | 0.2.2-alpha.3 起按名寻址（名字或 Session id）；旧参数校验失败 |
| `list_agents` 行 `{ kind, id, label, parent, depth, reason }` | **`{ name, status, description? }`** | 0.2.2-alpha.3 起；Team 任务 `ownerId` → `owner` |
| `AgentCreateOptions.parentAgent` / `ctx.agents.enter(agent, parent)` | **（已移除）** | 0.2.2-alpha.3 起创建者关系由 `subagent/catalog` 表达（名字路径，根是 `lead`） |
| `BundleInfo.updatable: boolean` | **`BundleInfo.update?: 'registry' \| 'git'`** | 0.2.2-rc.1 起；`ManagementError` 另增 `unexpected-package` |
| `LlmError` 构造的 `code: string` | **`code: BuiltinLlmFailureCode`** | 0.2.2-rc.3 起；自有码改用 `LlmError.fromFailure(failure)` |
| `@deepseek-ai/dsh-llm` 的 `HarnessError` | **`@deepseek-ai/dsh-error`** | 0.2.2-rc.3 起单独成包，`dsh-llm` 再导出同一个类 |
| `Session.append(type, data)` | **另加数组重载** `append([[type, data], ...])` | 0.2.2-rc.3 起；wrapper / 测试替身须实现两个重载 |
| `LoggerLevel` 的 `INFO=1` / `WARN=2` | **`WARN=1` / `INFO=2`** | cordis 4.1.0 数值重排；按枚举名比较，勿按下标 |
| `Fiber.update()` 返回 `void` | **返回 `Awaitable<void>`** | cordis 4.1.0 起可直接 `await fiber.update(config)`；4.2.0-alpha.1 仍成立 |
| `cordis_inspect_list` / `cordis_inspect_query` | **`cordis_inspect({ query })`** | 0.2.2-rc.4 起合并；`platform`/`provider`/`method` 放进 `query` |
| `create_worktree` / `working_directory` 工具 | **`enter_worktree`** / 删除 | 0.2.2-rc.4 起；Host 新增 `ctx.worktrees.enter`，`cwd` 改由 `ctx.subagents.start({ cwd })` 传 |
| `ctx.profileContext.overlays` | **`overlayPaths`** | 0.2.2-rc.4 起改为 `readonly string[]` |
| `resolveDeepSeekApiKey` / `normalizeApiKey` 等 | **`ctx.deepseekAuth.authorize(...)`** | 0.2.2-rc.4 起；凭据工具移到 `@deepseek-ai/dsh-credentials` |
| DeepSeek `imageMaxBytes` | **`imageTargetBytes`** | 0.2.2-rc.5 起；`ImageRequestTarget.maxBytes` → `maxImageBytes` |
| PTC 默认 `per-call` | **`persistent-in-memory`（`scoped-repl`）** | 0.2.2-rc.5 起；顶层 `return` 被拒，末条表达式为返回值 |
| `list_agents` 返回数组 | **`{ running, limit, agents }`** | 0.2.2-rc.5 起；遍历 `result.agents` |
| Action Card `callId` / `propose_action` | **`cardId`** / fenced `action-card` 块 | 0.2.2-rc.3~rc.4 起；`ActionCardKind` 去 `skill` / `invitation` |
| `ctx.sessionQuery.inspectSession` | **`observeSession`** | 0.2.2-rc.5 起；读 `observation.projections?.values[key]` |
| `systemMessages` / 完整 `system/message` | **`PromptAssembly.systemUpdates(retry)`** / 增量 section | 0.2.2-rc.5 起；组合须先挂 `session-projection` |
| `dsh-personalized-recommendations` | **（退役）** | 0.2.2-rc.5 起六行由 `dsh-web-app` 默认挂载 |
| `engines.node` 旧范围 | **`^24.22.3 || >=26.13.1`** | 0.2.3-alpha.1 起 |

