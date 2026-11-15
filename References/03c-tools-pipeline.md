# 03c · 工具流水线：作用域、PTC mode 与执行器插件

> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。

> 本文件是工具参考的第 3/3 部分，覆盖作用域与步骤准入、PTC mode 自动触达、工具执行器插件与官方文档链接。
> 第 1 部分见 `03-tools.md`，第 2 部分见 `03b-tools-advanced.md`。

## 7. 作用域与「步骤准入」（0.2.1-rc.2 起）

- `ctx.tools.register(def, options?)` — 全局或调用方 agent 作用域注册（作用域注册遮蔽全局；保留名 `run_code` 冲突失败）。`options.when` 是**同步或异步的准入条件**（见下）。
- `ctx.tools.restrict({ allow?, deny? })` — 按 agent 作用域过滤继承的全局工具；限制取交集；作用域自身注册不受限制。
- `ctx.tools.get(name, scope?, toolSet?)` / `ctx.tools.schemas(scope?, toolSet?)` / `ctx.tools.definitions(scope?, toolSet?)` — 按作用域（可选地再按本步准入集合）查看工具/投影 schema。
- `ctx.tools.executable(name, scope?, toolSet?)` — 返回**可执行**的定义；带 `when` 的工具若本步未准入则返回 `undefined`（调用方据此报 `UNKNOWN_TOOL`）。
- `ctx.tools.resolve(context)` — 解析本步的准入集合，返回 `ResolvedToolSet`（含 `view(scope)` 与 `dispose()`）。**只有程序化调用条件工具才需要它**。
- `ctx.tools.execute(input)` — 驱动一批调用（测试/协议桥用）。**完整批次，包括单次调用，都走批次**；input 含原始 `calls`、必填 `signal`、可选 `agent` 与 `log: { turn, step }`。
- `ctx.tools.setExecutor(executor)` — 注册执行器（由 executor 插件调用，普通工具插件不碰）。
- 工具名重复：一层内重复、保留的 `run_code` 名会失败。

### `when` 条件：工具声明的唯一入口

0.2.1-rc.2 起，**工具能否被调用由注册项的 `when` 决定**，不再由 `system-prompt/assemble` 里的数组增删决定：

```ts
ctx.tools.register(defineTool({ /* ... */ }), {
  when: ({ agent, modelSelection, signal }) => someCheck(agent, modelSelection),
})
```

- AgentLoop 在**每步开始时解析一次**条件，得到该步的 `ResolvedToolSet`，用它统一驱动工具声明、Native 分派、PTC 绑定与嵌套调用；步内重试复用同一集合。
- `when` 返回 `false` → 该工具在这一步**从声明与分派中同时消失**。
- `when` **抛错** → 整轮以 **`TOOL_ACTIVATION_FAILED`** 结束。条件应返回布尔，不要抛异常。
- `ToolActivationContext` = `{ agent, modelSelection, signal }`；`modelSelection` 是本步捕获的 `{ provider, model, reasoningEffort? }`；异步条件必须观察 `signal`。
- **`system-prompt/assemble` 不再携带工具数组**：它的输入是 sections / contexts / variables（`PromptPresentation`），返回的 `tools` 字段被**忽略**；读 `assembly.tools` 得到 `undefined`。想按上下文增删工具 → 用 `when`；想在提示词里描述可用工具 → 用 section 回调并把 `context.toolSet` 传给 `ctx.tools.get()` / `ctx.tools.schemas()`。
- 模型工具调用只走**本步的准入集合**：没有已解析集合时调用条件工具、集合已 dispose 后调用、步内注册被替换（热重载 / MCP 重连 / skill 重载）后的调用，都返回 `UNKNOWN_TOOL`。
- `exit_plan_mode` 只在 Session **首次进入 plan mode 之后**才被声明。

程序化调用条件工具：

```ts
const toolSet = await ctx.tools.resolve({ agent, modelSelection, signal })
try {
  await ctx.tools.execute({ calls, toolSet, signal })
} finally {
  toolSet.dispose()   // 批次 settle 后必须 dispose
}
```

> 不走共享流水线的自定义 executor，用 `ctx.tools.executable(name, agent, toolSet)` 逐个查。

## 8. PTC mode 自动触达（原 Code Mode）

> ⚠️ **0.2.1-rc.2 起执行方式改由 executor 插件决定**：`dsh-tools` 的 `mode` / `maxParallelSubCalls` 配置字段**已删除**，`ctx.tools.presentAs()` **已移除**，`DSH_TOOLS_MODE` **不再读取**；**Web / headless / SDK 三种随附 profile 全部继承 native 执行**。见 §9。

切到 PTC 执行的完整 CLI 形态（native 执行**不需要** overlay）：

```sh
dsh --profile headless --patch ./ptc.yml "task"
```

`ptc` 执行下，注册表只向模型暴露保留的 `run_code` 工具加一份生成的 SDK 提示词，因此 **model-direct 调用只能写 `run_code`**，写别的工具名会在策略流水线之前以 `UNKNOWN_TOOL` 拒绝；`run_code` 程序内的子分派（带 `parent` token）才能调用全部可见工具。`ptc` 要求存在带已注册 SDK 渲染器的 `ctx.ptcRuntime`（抽象服务 `@deepseek-ai/dsh-ptc-runtime`，提供方是 `@deepseek-ai/dsh-ptc-runtime-node`，另有实验性 `@deepseek-ai/dsh-experimental-ptc-runtime-python`；语言仍为 TypeScript / Python（0.2.2-rc.3 起工具 executor 只接受声明 TypeScript 语言的 provider，Python 运行时包仍存在但不会被 executor 采用——见 §9），缺失或语言无渲染器时在提示词组装阶段响亮失败（`load a ctx.ptcRuntime implementation (e.g. @deepseek-ai/dsh-ptc-runtime-node) or set tools mode to "native"`）。

程序内每个可见工具都可通过 `await tools.<name>(args)` 调用，无需额外集成；成功解析为策略处理后的**最终规范 JSON 值**（不是渲染文本），失败以生成的 `ToolCallError` reject——程序只能读 `name`/`toolName`/`message`，拿不到内部错误码或失败联合。因此**把 `output.schema` 设计为实用的程序化 API**：直接返回句柄与字段；确属结果时允许标量/数组/null 根；面向人的解释放 `output.render`。

程序内中间值不被持久化，不受提示词上限与 spill 流水线约束，只有外层 `run_code` 的日志/结果受限；子调用并发上限现在在 **PTC executor 的配置**里（默认 10），仍然只对 `isConcurrencySafe` 为 `true` 的调用并行、独占调用形成屏障（设为 `1` 即严格串行）。

**PTC 程序格式与状态保留（0.2.1-rc.2 起）**：`PtcRuntime.programFormat` 从 `'function-body' | 'repl'` 扩展为含 **`'script'`**（Node 侧用 `executionMode: vm-script` 开启，接受 Script 语句与顶层 await，**无顶层 `return`**；`scriptPersistence` 独立决定跨调用记忆）。**不要手写这个联合类型**——从 `@deepseek-ai/dsh-ptc-runtime` 导入 `PtcProgramFormat`。判断 provider 是否保留 `stateOwner` 的记忆，用 **`runtime.retainsState`**（基类返回 `false`），不要再用 `programFormat === 'repl'` 推断；保留记忆的自定义 provider 必须覆写 `retainsState` 并继续实现 `release(owner)`。

**取消语义（0.2.1-rc.3 起）**：**调用方取消**正在运行的 `run_code` 时，`tool/result` 的错误由 `CodeRunFailedError` / `CODE_RUN_FAILED` 改为 **`AbortError` / `ABORTED`**，结果内容变为 `Error: tool call aborted`；具体取消原因记录在 `turn/end`（`data.reason.kind === 'aborted'` 时读 `data.reason.reason`）。运行时自身失败（超时、清理失败）与运行时本地取消仍是 `CODE_RUN_FAILED`。读取历史结果时保留 `CODE_RUN_FAILED` 分支。

## 9. 工具执行器插件（0.2.1-rc.2 起）

`@deepseek-ai/dsh-tools` 只负责**工具注册与 executor 选择**；执行本身由独立包承担：

| 包 | 作用 |
|---|---|
| `@deepseek-ai/dsh-tool-executor-native` | 原生执行 |
| `@deepseek-ai/dsh-tool-executor-ptc` | PTC 执行（需挂 `ctx.ptcRuntime` 提供方） |

- **随附 profile 都挂了 executor；自定义组合必须自己挂。** `tool-executor-native` / `tool-executor-ptc` 行在启动时必须处于启用状态，**配置无效会直接让启动失败**。
- 切换执行方式用 patch：

```yaml
- id: tool-executor-native
  disabled: true

- id: tool-executor-ptc
  disabled: false
```

- `dsh-agent-tool-presentation` 选择器仍可用但**已弃用**。
- 自定义 executor 实现 `ToolExecutor` 接口：
  - `describe(tools)` —— 描述模型可调用的工具，返回 schema 与名字（用于校验工具顺序）。
  - `execute(input)` —— 执行完整批次。`input` 含原始 `calls`、取消信号、可选并发上限、`agent` 与 `log: { turn, step }`；从 `results` 读单次调用结果（顺序与输入一致，abort 的跳过项也要占位）。**没有 `log` 时不要提交根 call/result 事件。** 内部失败以 `ToolBatchExecutionError` reject（携带已提交的部分结果），调用方必须停止依赖工作并修补缺失的 log 结果。
- 配套导出：
  - `@deepseek-ai/dsh-tools/pipeline` —— `ToolExecutionPipeline` 与 `executeToolBatch`。自定义调度器可直接调 `prepare` / `dispatch` / `complete`。**这两个符号不从工具注册表入口导出。**
  - `@deepseek-ai/dsh-tool-testkit` —— 工具 fixture（**开发依赖**）。
  - `@deepseek-ai/dsh-tool-executor-ptc` —— PTC SDK 渲染器与 `CodeRunFailedError`。
  - `@deepseek-ai/dsh-tool-executor-ptc/types` —— 共享 dispatch 事件与 `ptc-mode` message-source 声明；Host 侧策略扩展用 `import type { PtcDispatchLog } from '@deepseek-ai/dsh-tool-executor-ptc'`。
- `maxParallelSubCalls` 现在在 PTC executor 配置里；`agent-loop.maxParallelToolCalls`（默认 `10`）仍在原处，**实时编辑只影响下一批**（不再是下一个 tool group）。
- **`tool-executor-ptc` 的调用额度（0.2.2-rc.3 起）**：新增 `maxSubCallsPerMinute`（默认 **`1024`**）——按解析后的 runtime 超时折算的**每分钟子调用额度**，含失败调用，用来兜住模型写出的死循环。超限抛 `ToolCallLimitExceededError`，message 指出第几次调用未被派发并建议检查循环终止或拆分 `run_code` 调用。
- **非 TypeScript PTC provider（0.2.2-rc.3 起）**：executor 只接受声明 TypeScript 语言的 provider；用其它语言建 `/run-code` 工具或组装提示词会以 `ToolContextUnavailableError` / `TOOL_CONTEXT_UNAVAILABLE` 失败。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **开发一个 Tool（教程）**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/tool
- **工具编写参考（cookbook）**：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/adding-a-tool
- **工具子系统**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/tools
- **工具执行流水线**：https://deepseek-harness.github.io/deepseek-harness/reference/tool-execution-pipeline
- **PTC 运行时（PTC mode 的 `ctx.ptcRuntime`）**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/ptc-runtime
- **后台任务（`ctx.jobs`）**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/jobs
- **扩展模式（权限门禁等钩子插件）**：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/extension-cookbook
