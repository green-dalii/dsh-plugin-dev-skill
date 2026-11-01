# 03 · 工具开发完整参考（defineTool）

> 精简提炼自 develop/basic/tool、reference/cookbook/adding-a-tool、reference/subsystems/tools、reference/tool-execution-pipeline。
> API 以本地 SDK `@deepseek-ai/dsh-tools` **0.2.2-alpha.2** 为准。**0.2.1-rc.2 是一次大重构**：工具执行拆成 executor 插件、工具声明改由「步骤准入」决定——见 §7/§8/§9。逐版本变化见 `References/00-INDEX.md`。
> 生产级参考实现：`packages/shell/tool-bash`（前台 + 后台 + 沙箱）、`packages/fs/tool-fs`（diff 卡片）、`packages/web/tool-web`（web 卡片）。

## 1. 最小形态

```ts
import { readFile } from 'node:fs/promises'
import type { Context } from '@deepseek-ai/cordis'
import { defineTool } from '@deepseek-ai/dsh-tools'

export const name = 'my-tool'
export const inject = ['tools']

export function apply(ctx: Context) {
  ctx.tools.register(defineTool({
    name: 'read_file',                                  // 模型看到的工具名
    description: 'Read a file from disk.',              // 模型看到的描述
    parameters: {
      path: { type: 'string', required: true, description: 'Absolute path' },
      limit: { type: 'number' },                        // 可选（不标 required）
    },
    output: {
      schema: { type: 'string' },                       // execute 返回的规范值
      render: (_args, value) => [{ type: 'text', text: value }],
    },
    async execute(args, exec) {
      // args 由 schema 推断类型：{ path: string; limit?: number }
      return readFile(args.path, { encoding: 'utf8', signal: exec.signal })
    },
  }))
}
```

注册是 effect：dispose 插件 fiber 即注销工具；schema 自动流入系统提示词组装。

## 2. execute() 契约与定义级元数据（规则）

- **参数已为你校验**：`defineTool` 在 execute 前按 `ParameterSchemaSpec` 校验模型生成的 arguments（类型、必填键、字面量、oneOf 分支、嵌套值）。显式 object 节点必须声明 `additionalProperties: true | false`。schema DSL 表达不了的约束（非空字符串、正数、跨字段）仍要自己检查并抛错。
- **注册借用你的只读定义**：注册后不要修改 schema 或替换回调。热替换 = dispose 旧 effect + 注册替代品。
- **执行身份受保护**：注册表把 arguments 物化为无损 JSON、冻结，分配不透明 `exec.token`；`exec.signal` 是调用方持有、必填的取消信号。`args` 视为只读。额外两个运行时扩展：`exec.deferContext(msg)` 把上下文挂到**本次执行自己的结果**上（直到本工具的 `tool/result` 之后才追加，按调用序，组合工具用它转运嵌套分派上下文）；`exec.concludeTurn()` 把本次成功结果标记为当前轮次的终点。另新增 `exec.schema?: ToolSchema`：PTC 内层调用的**绑定期**工具 schema，由其生产者冻结、**永不写入日志**（`signal`/`token`/`deferContext`/`concludeTurn`/`agent` 不变）。
- **声明并返回规范 JSON 值**：`output.schema` 用 `ValueSchemaSpec`（对象/数组/标量/null 根均可）。execute 只返回推导出的值；注册表快照、校验、冻结后交给 `output.render(args, value)`。**不要返回内容块，不要逼调用方从自然语言解析 id/字段。**
- **抛异常或无效值 = `isError`**。基础设施故障抛异常；成功但结果不理想（如非零退出码）→ 返回规范值，由 render 解释。
- **遵守 `exec.signal`**：信号触发时取消进行中的工作。
- 可选 `output.presentationMeta(args, value)`：从同一规范值派生可回放的 JSON（纯函数），注册表把它持久化在 `tool/result` 的 `meta` 上并传给 `presentResult` 供回放。嵌套的 `run_code` 子分派没有卡片，会跳过该投影器。
- 可选 `agent.inject({ content, source: { kind: 'plugin', plugin: '<name>' } })`：异步追加持久化上下文（下一次模型请求可见；不是唤醒）。注意防护已 dispose 的 agent。

**定义级运行时元数据**（`defineTool` 顶层字段，除模型可见的 `deferLoading` 外都不进入模型请求——`schemas()` 只白名单 `name`/`description`/`parameters`/`deferLoading`）：

- `timeoutMs?: number`：协作式超时预算（毫秒），由 `@deepseek-ai/dsh-tool-call-timeout-policy`（一个 `tools/execute` 包装器）强制执行。声明它即承诺把 `exec.signal` 转发给能在中止时归于静止的实现。
- `isConcurrencySafe?(args): boolean`：与同批兄弟调用是否可重叠。**只有精确返回 `true` 才并行**；缺省、抛异常、返回非 `true` 一律按独占处理，独占调用构成排序屏障。选择并行即承诺不改动父级拥有的状态。
- `projectContent?(exec, result): ContentBlock[] | undefined`：把**执行期准备好的内容**（文本 + 图片）在 `tools/post-execute` **之前**装进去；回调在调用开始时捕获，对每个进入 post-execute 的归一化结果恰好运行一次，post-execute 的策略替换仍然权威；**绕过 post-execute 的流水线失败会跳过该投影**。
- `finalizeContent?(exec, result): ContentBlock[] | undefined`：最后一道**只管内容**的同步变换，位于 post-execute **之后**（**包括**绕过 `tools/post-execute` 的流水线失败），对每个归一化结果恰好调用一次，位置在无损物化之前。必须全函数、不得抛错；返回 `undefined` 保留原内容，其余字段仍归注册表所有。
- `deferLoading?: true`：唯一模型可见的顶层字段（随 `ToolSchema` 投影给模型）：声明该工具**延迟加载**，模型按需激活，而不是每次请求都下发完整声明列表。

## 3. 参数与值 schema 词汇（ValueSchemaSpec）

- 标量：`string` / `number` / `integer` / `boolean` / `null`；`enum` 与 `const` 值必须与节点类型匹配。
- 容器：`array`（可带 `items`）、`object`（`properties` + 显式 `additionalProperties`）。
- `oneOf`：恰好命中一个分支。
- `{ type: 'json' }`：不施加约束的无损 JSON（推导为 `JsonValue`）。
- 参数定义是**隐式开放对象**的逐属性映射，required 是每属性的 `required: true` 标注。

## 4. 长时间运行的工作（后台任务）

通过 producer 配置控制 `run_in_background`，注册到 `ctx.jobs`：

```ts
const jobs = ctx.get('jobs')
if (!jobs) throw new Error('background jobs unavailable: load @deepseek-ai/dsh-jobs and @deepseek-ai/dsh-tool-jobs')
return {
  kind: 'background',
  jobId: jobs.start({
    kind: 'bash',                  // 任务种类
    label: args.command,           // 展示用
    ...exec.agent ? { owner: exec.agent.id } : {},   // owner 是 SessionId（上游 cookbook 仍写 owner: exec.agent，以类型与 tool-bash 为准）
    output: sources,               // 可选：JobOutputSource[]，注册表按自己的节奏拉取
    run: (job) => {
      // 返回 { cancel, done }；done 在清理完成后 settle 且不 reject
      // 也可以推送：job.append(text, options?) / job.updateProgress(line)
    },
  }),
}
```

要点：

- 后台分支返回**类型化的规范句柄**（如 `{ kind: 'background', jobId }`），输出 schema 必须能承载它；PTC mode 绝不能解析渲染文本拿 id。
- **producer 契约已改**：`owner` 是 `SessionId`；`JobHooks` 只剩 `{ cancel(reason?), done }`（`readOutput?` 已移除）；流式输出改用 spec 上的 `output?: readonly JobOutputSource[]`（拉取）和/或 `JobHandle.append` / `updateProgress`（推送）；`run` 现在接收 handle；`JobOutcome` 的一次性返回值改名为 `result?: string`。
- 预先中止的调用（已 abort 才进入 producer）判为失败。
- 发布 jobId 后，用**任务自有的取消信号**（归 `job_kill` / owner dispose / 服务 teardown），不再用 `exec.signal`。
- 前台工作仍与 `exec.signal` 耦合。

## 5. 执行策略与观测（扩展点）

| 扩展点 | 模式 | 用途 | 返回 |
|---|---|---|---|
| `tools/pre-execute` | waterfall | allow/deny/ask 策略 | `PreToolDecision`: `{kind:'allow'}` / `{kind:'deny',reason,info?:ToolErrorInfo}`（`ToolErrorInfo` 含 `reason?`）/ `{kind:'cancel'}`（规范的前置取消结果，不呈现为策略拒绝）/ `{kind:'ask',reason?,displayReason?}` |
| `ctx.tools.guard()` | 单调守卫 | 最终拒绝（后续无法撤销） | `string | undefined`（返回 reason 即拒绝） |
| `tools/execute` | waterfall | 环绕分发：超时/重试/指标；可替换 `exec.signal` 不可移除 | `ToolExecutionResult` |
| `tools/post-execute` | waterfall | 替换内容或值、阻止结果、附加模型上下文 | `PostToolDecision`: `accept` / `block` |
| `tools/ptc-dispatch-log` | waterfall | 改写一次 `run_code` 子分派**持久日志副本**的内容（程序已拿到完整值，模型两者都看不到） | `ContentBlock[]` |
| `tools/change` | emit | 工具集变化（注册/注销/作用域限制变化）；不受作用域过滤 | — |
| `tools/result` | emit | 只读观测不可变最终结果（日志/审计） | — |

规则：

- `tools/pre-execute` 返回 `ask` 只在审批服务返回 `allowed-once` 后继续，否则拒绝；无审批通道或无 agent 时 ask 也变成拒绝。
- guard 是单调的：任何 guard 都能拒绝，但没有任何 guard 能把已被拒绝的调用改回允许。
- `tools/post-execute` 替换内容会保留规范值与元数据；替换值会重新校验并重算内容/元数据；`block` 会把纠正反馈变成 `isError`。**内容替换是展示策略而非保密策略**——要隐藏程序化值必须 `block` 或替换该值（PTC mode 程序仍能拿到 `value`）。
- PTC mode 的 `run_code` 子分派走同一条完整流水线：携带父级 token、记录 `tool/ptc-dispatch`、把拒绝呈现为有约束力的驳回，并省略 `additionalContexts` 以保持调用与结果相邻。
- **尽量不要把部署策略内建到工具中**——放钩子插件（见 `11-cookbook.md` 权限门禁示例）。

流水线顺序（不修改循环本身）：
`tools/pre-execute` → guard → `tools/execute`（环绕） → **`projectContent`（定义自有）** → `tools/post-execute` → `finalizeContent`（定义自有，快照固定） → `tools/result`（不可变最终结果）。

## 6. UI 卡片（展示，与模型内容分离）

`output.render` 产出模型可见内容；**UI 卡片是独立关注点**，通过纯展示投影 + 可选 `presentCall` / `presentResult` 声明。两者返回 `card` 标签的渲染意图：

**调用时（`presentCall(args)` → ToolCallView）**：
- `{ card: 'generic', title, kind?, rawInput?, content?, locations? }` — 默认；`locations: [{path, line?}]` 供编辑器跟随
- `{ card: 'terminal', title, description?, cwd? }` — 调用本身是 shell 命令（tool-bash）
- `{ card: 'diff', title, diffs, locations? }` — 创建/修改文件；`diffs: [{path, oldText, newText}]`（新文件 `oldText: null`）

**完成时（`presentResult(args, {content, isError, meta?})` → ToolResultView）**：
- `generic` / `terminal`（原始输出+退出元数据）/ `diff`（已应用 hunk，来自 `presentationMeta`）/ `search`（`shape:'matches'|'paths'` + `truncated`/`total`）/ `web`（`kind:'search'|'fetch'`）/ `read`（行号窗口）

硬性规则：

- **纯函数**：这些方法在实时流式输出**和**会话日志回放时都会运行——不做 I/O、不读会话状态、不用时钟/随机数。
- **UI 格式不进入模型结果**：围栏、diff、相对化路径不因服务 UI 而进入规范值或 Native 内容。
- 展示路径软校验：坏参数/旧日志 → 回退通用卡片，绝不 crash 回放。

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

> ⚠️ **0.2.1-rc.2 起执行方式改由 executor 插件决定**：`dsh-tools` 的 `mode` / `maxParallelSubCalls` 配置字段**已删除**，`ctx.tools.presentAs()` **已移除**，`DSH_TOOLS_MODE` **不再读取**。见 §9。

`ptc` 执行下，注册表只向模型暴露保留的 `run_code` 工具加一份生成的 SDK 提示词，因此 **model-direct 调用只能写 `run_code`**，写别的工具名会在策略流水线之前以 `UNKNOWN_TOOL` 拒绝；`run_code` 程序内的子分派（带 `parent` token）才能调用全部可见工具。`ptc` 要求存在带已注册 SDK 渲染器的 `ctx.ptcRuntime`（抽象服务 `@deepseek-ai/dsh-ptc-runtime`，提供方是 `@deepseek-ai/dsh-ptc-runtime-node`，另有实验性 `@deepseek-ai/dsh-experimental-ptc-runtime-python`；语言仍为 TypeScript / Python），缺失或语言无渲染器时在提示词组装阶段响亮失败（`load a ctx.ptcRuntime implementation (e.g. @deepseek-ai/dsh-ptc-runtime-node) or set tools mode to "native"`）。

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
