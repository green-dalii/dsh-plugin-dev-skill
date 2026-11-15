# 08b · 能力 Seam 目录（一）：核心服务

> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。

> 本篇承接 `08-capability-layering.md` 的 `## 5.` 能力 Seam 目录，是其中的前半张表（核心服务部分）。
> 平台、UI 与演进部分见 `08c-seams-platform.md`；分层设计概念与设计要点见 `08-capability-layering.md`。

harness 的核心服务（`ctx.<key>` → 角色 → 说明）：

| ctx 键 | 角色 | 说明 |
|---|---|---|
| `ctx.llm` | seam | LLM 流服务；适配器（`llm-deepseek`/`llm-pi-ai`，测试用 `llm-replay`）注册提供方实现 |
| `ctx.deepseekLlmApiExtensions` | seam | 插件准备彼此独立的顶层请求字段，官方适配器合并后再提交交付状态 |
| `ctx.tools` | core | 工具注册表 + 步骤准入 + 执行器选择；`dsh-tool-*` 系列消费。**0.2.1-rc.2 起**：只负责注册与选择执行器，执行由 `@deepseek-ai/dsh-tool-executor-native` / `-ptc` 承担（旧的 `mode` 配置与 `ctx.tools.presentAs()` 已删除 / 移除）；工具声明由注册项的 `when` 条件决定（`system-prompt/assemble` 不再携带工具数组） |
| `ctx.agents` | core | 实时 Agent 注册表、创建/恢复工厂 seam、发起者传播 |
| `ctx.sessions` | core | 仅追加 Session 实例，发出持久会话事件流 |
| `ctx.systemPrompt` | core | 每步收集提示词段落与模型可见工具 schema |
| `ctx.sessionTitle` | seam | 会话标题：确定性回退 + 唯一可选异步提供方（`session-title-*-llm`） |
| `ctx.sessionProjections` | core | 各领域注册状态驱动的折叠单元。**0.2.1-rc.2 起**：`register(def)` 返回 **`Promise<ProjectionHandle<S>>`**（thenable，`instanceof Promise` 为 `false`），必须 await 并持有 handle；状态读取用属主服务方法或 `handle.stateOf(session)`，旧的 `stateOf(session, key)` 已废弃、`SessionProjectionStateMap` 已移除 |
| `ctx.shell` | seam | Bash 执行能力；`bash-local`/`bash-sandbox`/`pwsh-local` 提供 |
| `ctx.shellEnv` | core | 插件声明 effect 作用域的 `DSH_*` 事实；每个 shell 工具执行时收集可信快照 |
| `ctx.subprocess` | seam | 进程 spawn 坐标与生命周期；`subprocess-local`/`subprocess-ssh` 等 |
| `ctx.ssh` | core | 一条已认证 OpenSSH 连接；`fs-ssh`/`subprocess-ssh`/`sandbox-ssh` 据此把 fs、进程与沙箱整体搬到远端 |
| `ctx.fs` | seam | 文件系统；`fs-local`/`fs-sandbox`/`fs-ssh`；`fs-observation-policy` 经 `fs/*` 事件门禁 |
| `ctx.web` | seam | 搜索与抓取提供方注册。**0.2.2-rc.1 起**默认用 DeepSeek Search API（`web-search-deepseek`）与 `web-fetch-http`；旧的 `web-search-exa` / `web-search-perplexity` 包**已删除**，搜索与抓取可**分别**选计费账号或 API Key，旧的 provider 认证字段被「有序凭据来源」取代 |
| `ctx.mcpResources` | seam | 连接所有者在调用 agent 的作用域内提供共享 MCP 资源工具；`mcp-client` 侧提供 |
| `ctx.jobs` | seam | 后台任务注册表；`jobs-local` 提供，`tool-jobs` 面向模型控制 |
| `ctx.subagents` | seam | 子代理传输；`subagent-spawn-in-process`/`-fork-in-process`/`-acp`/`-codex`/`-claude-code`/`-dsh-sdk` |
| `ctx.approval` | seam | 一次性权限决策（`approval/request` waterfall）；Definition 与实现同包在 `dsh-user-approval` |
| `ctx.permissionPresets` | core | 面向用户的预设表：把沙箱模式与审批选项组合成 `workspace-write`/`danger-full-access` |
| `ctx.sandbox` / `ctx.sandboxPolicy` | seam/core | 沙箱执行后端 / 统一部署默认模式与工作区根；`sandbox-local`/`sandbox-ssh` 提供 |
| `ctx.credentials` | seam | 凭据引用与解析；`credentials-local` 提供 |
| `ctx.authorization` | seam | 取得某份凭据的 flow 注册；seam 拥有「每个键同时只跑一次尝试」的生命周期 |
| `ctx.settings` | core | 分层设置；由活跃 profile 条目生成各插件的 Config 表单（插件以 `.volatile()` 声明字段），校验后的编辑交给 `boot/config-editor` 落成 profile patch 并对账 Loader 条目 |
| `ctx.sessionPersistence` | seam | 会话持久化；`session-persistence-jsonl` 等 |
| `ctx.sessionQuery` | seam | 会话查询；`session-query-sqlite` |
| `ctx.sessionTelemetry` | seam | 捕获会话记录、脱敏后交给单一后端（`session-telemetry-otel`） |
| `ctx.storage` / `ctx.storageDomain` | seam/core | KV 存储后端 / 领域化类型化持久状态；`storage-json`/`storage-sqlite` |
| `ctx.skills` | seam | 分层（宿主 + scope）合并 provider 的 skill 目录；`skill-filesystem`/`skill-badge`/`skill-office`/`sandbox-windows-acl` 提供，`tool-skill` 消费。发现根按 rank：`<project>/.dsh/skills`(100)、`<project>/.agents/skills`(200)、`customSkillDirs`(300)、`$DSH_HOME/skills`(400)、`$DSH_AGENTS_HOME/skills`(500)、bundled(600)；名称须为 kebab-case，接受 `<name>/SKILL.md` 或 `<name>.md`（不递归），frontmatter 必填 `name`/`description`，可选 `whenToUse`/`disable-model-invocation`/`user-invocable` |
| `ctx.fileReferences` | seam | 返回 Agent cwd 内仅含路径的补全候选（不读内容）；`file-reference-local` 提供 |
| `ctx.spillStore` | seam | 过大工具文本溢出存储；`spill-local` 提供，`spill-policy` 决定何时 spill |
| `ctx.compaction` | seam | 上下文压缩；`compaction-basic` 提供 |
| `ctx.tokenMeter` | core | token 计量 |

> 本主题的官方文档链接见 `08-capability-layering.md` 末尾。
