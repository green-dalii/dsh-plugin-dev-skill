# 12b · 版本迁移错误（破坏性变更对照表）

> 本文件是错误自查清单的第 2/2 部分：**带版本标记的破坏性变更**——每条都写着「从哪个版本起变了」。
> 与版本无关的通用设计错误见 `12-mistakes.md`；各版本升级指南的原文索引与陷阱见 `13-upgrade-guides.md`。
> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。**下表只列到该基线为止**；更新基线时逐条复核。

| 错误 | 修正 |
|---|---|
| 仍在用 `ctx.codeRuntime` / `dsh-code-runtime` | 0.2.0 已改名：`ctx.ptcRuntime` / `dsh-ptc-runtime`（提供方 `dsh-ptc-runtime-node`） |
| 在 profile manifest 里写 `patchReload` | 该字段已删除；HMR 由 YAML 组合里 `dsh-hmr` 行的 `disabled`/`root` 决定 |
| 后台任务写 `owner: exec.agent` 或 `readOutput` | `owner` 要传 `exec.agent.id`；`readOutput` 已移除，改用 `spec.output` / `job.append()`，结果用 `JobOutcome.result` |
| 导入 `@deepseek-ai/dsh-invariants` 或 `<pkg>/invariant` | 0.2.1-alpha.1 已删除：`InvariantRegistry`、`InvariantInstaller`、`InvariantFailure`、`InvariantError` 不再导出；`sdk-minimal` 中的五个 `*-invariant` id 已清理。诊断失败改用自己的通道上报 |
| 声明了 `engines.dsh` 但范围太窄 / 想跟 peer 走 | 0.2.1-alpha.3 起 `engines.dsh` 优先于 DSH peer：声明它一个 range 就决定兼容性，peer 不再补齐；要么放宽范围，要么删掉回到 peer 路径 |
| 在 `engines.dsh` 里写 `workspace:` | 不允许；`workspace:` 只在 peerDependencies 里合法 |
| 读 `IncompatiblePlugin` / `PluginCompatibility` 的 `peers` 字段 | 0.2.1-alpha.3 起改名为 `requirements`（键是 `engines.dsh` 或 peer 包名） |
| HMR profile 下用 `dsh plugin ... add <已装包名>` 想升级 | 0.2.1-alpha.2 起返回 `already-installed`，不改 profile 文件；须先 `remove` 再 `add`。处理 `ManagementError['code']` 时加分支 |
| **在 `dsh-tools` 行写 `mode` / `maxParallelSubCalls`** | 0.2.1-rc.2 起这两个配置字段**已删除**，加载时直接拒绝。执行方式改由 executor 插件行决定（`03c-tools-pipeline.md` §9） |
| **调用 `ctx.tools.presentAs('native' \| 'ptc' \| 'both')`** | 0.2.1-rc.2 起该方法**已移除**；同一进程内 PTC / native 并存改由挂不同的 executor 插件实现 |
| **在 `system-prompt/assemble` 里增删工具声明 / 读 `assembly.tools`** | 0.2.1-rc.2 起该 waterfall **不携带工具数组**，`assembly.tools` 是 `undefined`（读到就崩）。改用注册项的 `when` 条件（`03c-tools-pipeline.md` §7） |
| **程序化调用条件工具时不带 `toolSet`** | 0.2.1-rc.2 起模型调用只走该步的准入集合；无 `toolSet` 的调用返回 `UNKNOWN_TOOL`。先 `await ctx.tools.resolve({ agent, modelSelection, signal })`，用完 `toolSet.dispose()` |
| **`when` 条件抛错** | 整轮以 `TOOL_ACTIVATION_FAILED` 结束；条件应返回布尔而不是抛异常 |
| **监听 `agent/request` 事件** | 0.2.1-rc.1 起该事件**不再公开**（降级为未声明事件）；改用 `agent/request-error` 或 `llm/stream` |
| **`ctx.sessionProjections.register(def)` 不 await** | 0.2.1-rc.2 起返回的是 **thenable 的 `Promise<ProjectionHandle<S>>`**（不是原生 Promise，`instanceof Promise` 为 `false`）；必须 await 并持有 handle，状态读取用 `handle.stateOf(session)`；`stateOf(session, key)` 已废弃 |
| **在 `session/created` 监听器里写 Session 或做 Agent 相关工作** | 0.2.1-rc.2 起 `Session.append()` 在实例进入 `SessionStore` 且 `session/created` 同步派发完成前**拒绝写入**；且该期间 `ctx.agents.get(session.id)` 返回 `undefined`。把写操作移到 setup 或 `agent/created`；自建 Session 用 `ctx.sessions.create()` |
| **构造辅助 LLM 请求时用未声明的 `purpose`** | 0.2.2-alpha.2 起 `purpose` 由可声明合并的 `LlmRequestPurposeMap` 派生；未声明的 purpose **类型检查不过**。加载生产方声明包，或 `declare module '@deepseek-ai/dsh-llm/types'` 扩充 |
| **手写 `PtcRuntime.programFormat` 联合类型** | 0.2.1-rc.2 起该类型扩展出 `'script'`；从 `@deepseek-ai/dsh-ptc-runtime` 导入 `PtcProgramFormat`，别手写 |
| **用 `programFormat === 'repl'` 判断是否保留内存** | 0.2.1-rc.2 起改用 `runtime.retainsState`（基类返回 `false`）；保留内存的自定义 provider 必须覆写它并继续实现 `release(owner)` |
| **把 PTC 取消当成 `CODE_RUN_FAILED`** | 0.2.1-rc.3 起**调用方取消**改用 `AbortError` / `ABORTED`（结果内容 `Error: tool call aborted`），原因在 `turn/end` 的 `data.reason.reason`；运行时自身失败（超时/清理）仍是 `CODE_RUN_FAILED` |
| **从 `@deepseek-ai/dsh-app-boot` 导入 `PROFILE_TEMPLATES` 等** | 0.2.1-rc.2 起这些 bundle 清单迁到新包 `@deepseek-ai/dsh-official-bundles`；`initProfile` / `loadProfile` 等仍从 `dsh-app-boot` 导入 |
| **`ctx.webServer.renderIndex(html)` 少传参数** | 0.2.1-rc.2 起必须传 Peer：`renderIndex(html, peer)` / `collectIndexInjections(peer)`；`webserver/index-inject` 事件的第二个参数也是该 Peer |
| **`new HttpFetchProvider(limits, resolveAddresses)`** | 0.2.1-rc.2 起构造函数只接受 `HttpFetchLimits`，`HttpFetchResolver` 不再导出；`web_fetch` 现在**可访问内网与云元数据端点**，需限制就自建 `tools/pre-execute` 策略 |
| **自定义组合没挂工具 executor** | 0.2.1-rc.2 起 executor 行必须启用，否则**启动失败**（`03c-tools-pipeline.md` §9） |
| **`@deepseek-ai/dsh-user-approval` 排在 `dsh-session-projection` 前面** | 0.2.1-rc.2 起 `ApprovalService` 依赖 `sessionProjections`，缺失时**激活失败**（不再回退到读事件日志）；配置层必须把 projection 排在前面 |
| **读 `dsh-tool-subagent` 的 `modelSelectionSettings`** | 0.2.1-rc.1 起改名为 `modelSelection`；模型发现另需 `modelDiscovery: true`（每工具域一个实例） |
| **等 `fiber.update()` 之后又去 `await fiber.await()`** | cordis **4.1.0** 起 `update()` 返回 `Awaitable<void>`，**直接 `await fiber.update(config)` 即可**；早期版本返回 `void` 时才需要 `fiber.await()` |
| **按下标比较 `LoggerLevel`** | cordis 4.1.0 起数值重排为 `ERROR=0` / **`WARN=1`** / **`INFO=2`** / `DEBUG=3`（旧版 `INFO=1` / `WARN=2`）；按数字大小判级别的 exporter 会静默错位，请用枚举名比较 |
| **按旧签名实现 `internal/update` 监听器** | cordis 4.1.0 起监听器签名是 `(config, next)`，**`noSave` 不再传入**（它仍是 `Fiber.update()` 的第二个实参） |
| **给 `LlmError` 构造函数传提供方自有错误码** | 0.2.2-rc.3 起构造参数类型收紧为 `BuiltinLlmFailureCode`（`LLM_FAILURE_CODES` 的键 + `HTTP_<number>`）。自有码改用 **`LlmError.fromFailure(failure, options?)`** |
| **`ctx.tools.guard()` 只返回 `string`** | 仍合法，但 0.2.2-rc.3 起可返回 `ToolGuardDenial`（`{ reason, info? }`）把结构化错误身份一并持久化 |
| **读审批拒绝结果时只看 message** | 0.2.2-rc.3 起审批拒绝带 `{ name: 'ApprovalError', code: 'APPROVAL_REJECTED' \| 'APPROVAL_CANCELLED' \| 'APPROVAL_UNAVAILABLE' }`；用 `error.code` 分支，别解析文案 |
| **工具体缺上下文时抛普通 `Error`** | 改用 **`ToolContextUnavailableError`**（code `TOOL_CONTEXT_UNAVAILABLE`），语义是"调用方无法纠正"，message 要指明缺哪个上下文 |
| **包装 / 替换 `Session.append` 只实现单事件签名** | 0.2.2-rc.3 起有两个重载（`append(type, data)` 与 `append([[type, data], ...])`）；测试替身与 wrapper 必须都支持 |
| **`send_message({ agent_id })` / `interrupt_agent({ agent_id })`** | 0.2.2-alpha.3 起参数名改为 **`agent`**（接受名字或 Session id）；仍传 `agent_id` **参数校验失败** |
| **按旧形状解析 `list_agents` 输出** | 0.2.2-alpha.3 起行是 **`{ name, status, description? }`**（不再有 `kind` / `id` / `label` / `parent` / `depth` / `reason`）；不可读分支的 `status` 为 `corrupt` / `unsupported` / `unavailable` |
| **Team 任务读 `ownerId` / 传 `owner: "unowned"`** | 0.2.2-alpha.3 起用 **`owner`**（名字）；列无主任务用 **`unowned: true`**。Host 侧 `ctx.agentTeams` 仍读 `ownerId`，展示用 `ownerName ?? ownerId` |
| **给 `AgentCreateOptions` 传 `parentAgent` / 调 `ctx.agents.enter(agent, parent)`** | 0.2.2-alpha.3 起 **`parentAgent` 已移除**，`enter(agent)` 不再收父 Agent；创建者关系改由 `subagent/catalog` 表达（名字路径，根是 `lead`） |
| **`SubagentActivation` 缺 `name`** | 0.2.2-alpha.3 起 `name` **必填**；`SubagentActivationSpec.name` 可选。catalog 写入 **payload version 3**，旧版 DSH 打不开含 v3 的 Session——多进程共用一个 Session store 时必须先全部升级 |
| **用 `ctx.officeToPdf` / `dsh-office-to-pdf`** | 0.2.2-alpha.3 起改名为 **`ctx.officeKit`** / **`dsh-office-kit`**（行 id `office-kit`，Remote `officeKit/*`，类型 `OfficeKit*`）；LibreOffice Kit 缺失不再加载失败，转换时报 `OfficeKitError` code `unavailable`，装好 Kit 无需重载 |
| **读 `BundleInfo.updatable`** | 0.2.2-rc.1 起改名为 **`update?: 'registry' \| 'git'`**；`ManagementError['code']` 新增 `unexpected-package`（`plugin_manager` 工具本身不受影响） |
| **PTC 子调用没有额度约束** | 0.2.2-rc.3 起 `tool-executor-ptc` 新增 `maxSubCallsPerMinute`（默认 `1024`，按解析后的超时折算，含失败调用）；超限抛 `ToolCallLimitExceededError` |

> 本主题的官方文档链接见 `13-upgrade-guides.md` §0。
