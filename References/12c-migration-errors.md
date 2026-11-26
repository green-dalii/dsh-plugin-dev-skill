# 12c · 版本迁移错误（破坏性变更对照表：rc.4 ~ 0.2.3-alpha.2）

> 本文件是错误自查清单的第 3/3 部分：**带版本标记的破坏性变更**——每条都写着「从哪个版本起变了」，细则见对应 References 篇目。
> 0.2.0 ~ 0.2.2-rc.3 见 `12b-migration-errors.md`；通用设计错误见 `12-mistakes.md`；升级指南原文索引见 `13-upgrade-guides.md`。
> SDK 基线：`@deepseek-ai/*` **0.2.3-alpha.2**（cordis **4.2.0-alpha.1**）。

| 错误 | 修正 |
|---|---|
| 调 `cordis_inspect_list` / `cordis_inspect_query` | 0.2.2-rc.4 起合并为 **`cordis_inspect`**：列目录 `cordis_inspect({})`，查方法 `cordis_inspect({ query: { platform, provider, method, input } })`；Client 查询要求页面已连接 |
| Loader / Include 仍按 js-yaml JSON schema 解析 | Loader `1.0.0-rc.9` / Include `1.2.0` 起解析 **YAML 1.2 core**：`0b101` 读成字符串、空 `!!js` 标量 → `undefined`；`group: true` 必须有 `config` 列表；错误定位 `file:line:column`。详见 `09-cordis-primer.md` §8 |
| 把 `applyEntryPatches` 返回值当条目列表 | 改为返回 **`{ data, index }`** 并把生成的 id 写进 `patches`；保入参传 `structuredClone(patches)`；`parseEntryYaml` 改抛 `YAMLError` |
| 调 `create_worktree` | rc.4 起删除；改 **`enter_worktree({ name?, from? })`**（有 `name` 则进入，否则从 `from` 创建，默认 HEAD），结果加 `created: boolean`；Host 新增 `ctx.worktrees.enter(agent, { name })` |
| 调 `working_directory` / 给子代理传 `cwd` | rc.4 起工具与包 `@deepseek-ai/dsh-tool-working-directory` 删除；Host 用 `ctx.subagents.start({ cwd })`；目录变更记为 `workspace-root/change`，读目录用 `Current working directory:` 上下文行 |
| 读 `ctx.profileContext.overlays` | rc.4 起改为 **`overlayPaths: readonly string[]`**（`--patch` 绝对路径）；`readProfilePatches()` 每次重读文件 |
| 仍导旧的 DeepSeek 凭据函数 | rc.4 起用 **`ctx.deepseekAuth.authorize({ consumer, accepts, destination })`**；`resolveDeepSeekApiKey` / `deepSeekApiKeyConfigured` / `normalizeApiKey` 等删除，`normalizeApiKey` / `resolveCredentialRef` / `credentialRefConfigured` 移到 `@deepseek-ai/dsh-credentials`。详见 `05-llm-adapter.md` §5.1 |
| 自定义 `DeepSeekFilePolicy` 缺字段 | rc.4 起必填 **`uploadConcurrency` / `uploadMaxRetries` / `uploadRetryDelayMs` / `uploadTimeoutMs`**；用 `resolveAdapterOptions(options).filePolicy` |
| 把 `refusal` 当 `MALFORMED_RESPONSE` | rc.4 起 LLM 错误 finish 与失败轮 `turn/end` 改报 **`CONTENT_REFUSED`** |
| DeepSeek `models` 仍写 `imageMaxBytes` | rc.5 起改 **`imageTargetBytes`**（2 MiB 默认、32 MiB 硬上限，旧键被拒）；`ImageRequestTarget.maxBytes` → `maxImageBytes`。详见 `05b-llm-errors.md` §9 |
| 手写 `PtcProgramFormat` / 默认按 function-body 写 PTC | rc.5 起 Node PTC 默认 `executionMode: persistent-in-memory` + 默认 `replScoped` → **`scoped-repl`**；顶层 `return` 被拒、末条表达式为返回值、用 `await import()`；patch `config: { executionMode: per-call }` 可回退（整份替换）。详见 `03d-ptc-runtime.md` |
| PTC 输出 / 协议仍按旧版 | `maxOutputBytes` 只截断展示不中断执行，`outputTruncated` 独立于 `error`；bootstrap 协议升 **5**；`inspect()` 识别 `PtcInspectableValue`。详见 `03d` |
| PTC 里把 MCP 图片按 base64 JSON 读 | 图片块新增 `attachment`，PTC 中变成 **`Image`**（同 `read_image` / CUA 截图），读字节用 **`image.path`** |
| 自定义循环仍消费 `systemMessages` | rc.5 起 `system/message` 是**增量 section 更新**；用 `contentIndex` / `noticeIndex` 区分正文与通知；组合须先挂 `session-projection` 再挂 `system-prompt`；循环改调 **`PromptAssembly.systemUpdates(retry)`** 并按序追加 `{ message, intent }`。详见 `11-cookbook.md` §8 |
| 调 `ctx.sessionQuery.inspectSession` | rc.5 起该 API **删除**；改 `await ctx.sessionQuery.observeSession(sessionId, { signal })` 再读 `observation.projections?.values[key]` |
| 按数组解析 `list_agents` | rc.5 起结构化结果改为 **`{ running, limit, agents }`**，遍历 `result.agents` |
| Action Card 按 `callId` 寻址 / 处理共享 `replaced` 阶段 | `propose_action` 模型工具删除，改答案内 fenced **`action-card`** 块；`cardId`（`ActionCardId`）取代 `callId`；`ActionCardKind` 去 `skill` / `invitation`，`queuedMessageLimit` 与 `ActionCardError` 删除；rc.5 起旧卡不再置 `replaced`，按 `cardId` 索引 decisions |
| 只禁用 `skill` 行、留下 `upstream-skills` | base 新增 **`upstream-skills`** 行（`@deepseek-ai/dsh-upstream-skills`），须一起禁用，否则 pending + `1 entry did not activate` |
| 仍在 profile bundles 配 `dsh-personalized-recommendations` | rc.5 起该 bundle **退役**，六行改由 `dsh-web-app` 默认挂载；覆盖用 `disabled: true` / `config.enabled: false` |
| 仍调用 `office-docx` / `office-pptx` / `office-xlsx` | rc.5 起 `@deepseek-ai/dsh-skill-office` **只注册 `office`**；`dsh-tool-office` 默认 `activationSkills` 收窄为 `[office]` |
| Node pin 旧版本 | 0.2.3-alpha.1 起 `engines.node` 提到 **`^24.22.3 || >=26.13.1`**；同步 dev / 容器 / CI |
| 以为 `workspace-write` 边界固定原项目 | rc.4 起 `ctx.sandboxPolicy.resolve({ session })` 的 `workspaceRoot` 是 **Session 当前工作目录**，随 `setWorkingDirectory` / `ctx.subagents.start({ cwd })` 移动；`WorkspaceChangesSummary.cwd` 是本轮起始目录；扩权用 `additionalWritableRoots` 或 `registerWritableRoot` |
| 写死 `web.searchProvider: deepseek-search-api` | rc.4 起 base 不再固定该键；DeepSeek 路由走 `deepseek-official` provider（追加 `web/deepseek-search-llm-request`）；env `DSH_WEB_SEARCH_PROVIDER`，UI 新增 Automatic；显式配置不受影响 |
| SDK prompt 仍报 `timeZone: unavailable` | rc.5 起改用传入的 `timeZone`（`UTC` / IANA `Area/Location`）；TS / Python / JSON-RPC 签名见 `10-spatiotemporal.md` §8 |
| 从 compaction marker 视图数据读 `summary` | rc.5 起字段移除；按 `summaryEventSeq` + Session 地址读 **`compaction/summary`** 事件 |
| 用 `seed` 之外的字段表达 fork 来源 | rc.4 起新增 **`CreateAgentOptions.parentSource: { sessionId, endSeq }`**；短父历史报 `SESSION_FORK_PREFIX_NOT_PERSISTED` |
| 进程内子代理初始任务按 `user` 来源处理 | rc.4 起 `user/message.source` → **`{ kind: 'agent-message', form: 'relay', senderSessionId }`**，`$skill` 不再加载技能；模型选择改读 `ctx.subagentModelSelection.allowedRoutes()`，错误码 `INVALID_MODEL_SELECTION_SETTINGS` / `MODEL_ROUTE_NOT_ALLOWED` |

> UI / CUA / Client-only 的变更按设计决策只进 `13-upgrade-guides.md` 与 `14-workflow-and-scope.md` 的边界摘要。
