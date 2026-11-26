# 08b · 能力 Seam 目录（一）：核心服务

> SDK 基线：`@deepseek-ai/*` **0.2.3-alpha.2**（cordis **4.2.0-alpha.1**）。

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
| `ctx.subagents` | seam | 子代理传输；`subagent-spawn-in-process`/`-fork-in-process`/`-acp`/`-codex`/`-claude-code`/`-dsh-sdk`。**0.2.3-alpha.2 起**：Host 用 `ctx.subagents.start({ cwd })` 传起始目录，子代理工具不再收 `cwd`（迁移见下） |
| `ctx.subagentModelSelection` | seam | 0.2.3-alpha.2 起：子代理模型路由 seam，`allowedRoutes()` 每次调用现算，禁用时返回 `undefined`；不再注入 `sessions` / `sessionProjections`（迁移见下） |
| `ctx.approval` | seam | 一次性权限决策（`approval/request` waterfall）；Definition 与实现同包在 `dsh-user-approval` |
| `ctx.permissionPresets` | core | 面向用户的预设表：把沙箱模式与审批选项组合成 `workspace-write`/`danger-full-access` |
| `ctx.sandbox` / `ctx.sandboxPolicy` | seam/core | 沙箱执行后端 / 统一部署默认模式与工作区根；`sandbox-local`/`sandbox-ssh` 提供。**0.2.3-alpha.2 起**：`resolve({ session }).workspaceRoot` = 会话工作目录（不再是 Session 头里的原项目），随 SDK `setWorkingDirectory` / Python `set_working_directory` / `ctx.subagents.start({ cwd })` 移动（迁移见下） |
| `ctx.credentials` | seam | 凭据引用与解析；`credentials-local` 提供 |
| `ctx.authorization` | seam | 取得某份凭据的 flow 注册；seam 拥有「每个键同时只跑一次尝试」的生命周期 |
| `ctx.settings` | core | 分层设置；由活跃 profile 条目生成各插件的 Config 表单（插件以 `.volatile()` 声明字段），校验后的编辑交给 `boot/config-editor` 落成 profile patch 并对账 Loader 条目 |
| `ctx.sessionPersistence` | seam | 会话持久化；`session-persistence-jsonl` 等 |
| `ctx.sessionQuery` | seam | 会话查询；`session-query-sqlite`。**0.2.3-alpha.2 起**：`inspectSession` 已删除，改用 `observeSession` 读 `projections`（迁移见下；该移除已登记到 `12c-migration-errors.md` 迁移表） |
| `ctx.sessionTelemetry` | seam | 捕获会话记录、脱敏后交给单一后端（`session-telemetry-otel`） |
| `ctx.storage` / `ctx.storageDomain` | seam/core | KV 存储后端 / 领域化类型化持久状态；`storage-json`/`storage-sqlite` |
| `ctx.skills` | seam | 分层（宿主 + scope）合并 provider 的 skill 目录；`skill-filesystem`/`skill-badge`/`skill-office`/`sandbox-windows-acl` 提供，`tool-skill` 消费。发现根按 rank：`<project>/.dsh/skills`(100)、`<project>/.agents/skills`(200)、`customSkillDirs`(300)、`$DSH_HOME/skills`(400)、`$DSH_AGENTS_HOME/skills`(500)、bundled(600)；名称须为 kebab-case，接受 `<name>/SKILL.md` 或 `<name>.md`（不递归），frontmatter 必填 `name`/`description`，可选 `whenToUse`/`disable-model-invocation`/`user-invocable` |
| `ctx.fileReferences` | seam | 返回 Agent cwd 内仅含路径的补全候选（不读内容）；`file-reference-local` 提供 |
| `ctx.spillStore` | seam | 过大工具文本溢出存储；`spill-local` 提供，`spill-policy` 决定何时 spill |
| `ctx.compaction` | seam | 上下文压缩；`compaction-basic` 提供 |
| `ctx.tokenMeter` | core | token 计量 |

### `0.2.3-alpha.2` 迁移行（核心服务）

| 旧 | 新 |
|---|---|
| 子代理工具参数 `cwd` | 工具不再接受 `cwd`；Host `ctx.subagents.start({ cwd })` 指定起始目录 |
| `create_worktree` 模型工具 | `enter_worktree({ name?, from? })`：有 `name` 则进入已注册 worktree，否则用 `from`（默认 HEAD）创建、`name` 省略则生成名字；`from` 遇同名已占用 → `WORKTREE_ALREADY_EXISTS`；结果新增 `created: boolean`，进入既有 worktree 无 `baseCommit`，HEAD detached 时无 `branch`。新 Host 方法 `ctx.worktrees.enter(agent, { name })`，`ctx.worktrees.create` 不变；`ctx.worktrees.cleanupOf(sessionId, null)` 返回 `{ removed }`，保留策略生效（`retainOnArchive: true` 保留 checkout）时返回 `null` |
| `working_directory` 模型工具 / `@deepseek-ai/dsh-tool-working-directory` | 两者已删除，`dsh-base` / `dsh-sdk-minimal` 不再挂载该条目；读 cwd 改用上下文行 `Current working directory:`；会话目录只经 Host 操作（`enter_worktree` / `exit_worktree`、forge 面板、SDK `setWorkingDirectory` / Python `set_working_directory`、消失恢复）变更，每次记 `workspace-root/change` |
| 沙箱 `resolve(...).workspaceRoot` = 原项目 | = 会话工作目录；`WorkspaceChangesSummary.cwd` 报**回合开始**目录，原项目从 Session 头的 `cwd` 读。授权 Git 目录：在 `cordis.yml` 给 `@deepseek-ai/dsh-sandbox-policy` 的 `additionalWritableRoots` 加上，或 `ctx.sandboxPolicy.registerWritableRoot(session, directory)`（Windows 忽略 additional writable roots）；无头 Session 由策略 `workspaceRoot` 定界时把 `@deepseek-ai/dsh-working-directory` 的 `defaultDirectory` 设为同目录 |
| `ctx.sessionQuery.inspectSession(sessionId, read, signal?)` | 已删除（类型调用编译失败、无类型运行时 reject）；改用 `using observation = await ctx.sessionQuery.observeSession(sessionId, { signal })` → `observation.projections?.values[key]`，live 与冷会话都算到日志末尾、无需 attach/resume；非 wire 状态走属主服务。**12c 迁移表亦应登记此项** |
| 初始任务 `user/message.source: { kind: 'user' }` | `{ kind: 'agent-message', form: 'relay', senderSessionId: '<parent session id>' }`，内容前缀 `Agent <parent name> sent a message: `；`$skill` 不再加载 skill、Session 引用不展开；按 `agent-message` 且 `senderSessionId` == 子代理 `parentSession` 匹配并丢掉首个 content block，旧会话仍接受 `user` |
| `model-selection-settings` 在 Agent 创建时追加 `subagent/model-selection-policy` | 不再追加；模型可选 `subagent` 工具与 `list_subagent_models` 每次调用读 `ctx.subagentModelSelection.allowedRoutes()`（返回路由或禁用时 `undefined`）；非法列表 → `SubagentError` code `INVALID_MODEL_SELECTION_SETTINGS`，不允许路由 → `MODEL_ROUTE_NOT_ALLOWED`；`@deepseek-ai/dsh-tool-subagent` 不再注入 `sessionProjections`；移除导出 `subagentModelSelectionProjectionDefinition` / `subagentModelSelectionPolicy` / `SubagentModelSelectionSettings` |

> 本主题的官方文档链接见 `08-capability-layering.md` 末尾。
