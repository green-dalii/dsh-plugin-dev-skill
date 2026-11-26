# 06b · 事件系统与常用事件

> SDK 基线：`@deepseek-ai/*` **0.2.3-alpha.2**（cordis **4.2.0-alpha.1**）。

本文覆盖 Cordis 事件系统（§6）与 Harness 常用事件速览、版本变动（§7）。服务与依赖见 06-services.md。

## 6. 事件系统

### 分发模式（5 种，模式是事件公开约定的一部分）

| 模式 | 调用 | 语义 |
|---|---|---|
| emit | `ctx.emit(name, ...args)` | 同步广播；不等待、忽略返回值 |
| parallel | `await ctx.parallel(name, ...args)` | 所有监听器并发运行并等待（返回 `Promise<void>`） |
| serial | `await ctx.serial(name, ...args)` | 按注册顺序 await；首个非 null/false/undefined 返回值胜出并终止后续 |
| bail | `ctx.bail(name, ...args)` | serial 的**同步**版，返回首个 bail 值（同步返回值，不是 promise） |
| waterfall | `ctx.waterfall(name, ...args, next)` | 环绕中间件；**调用方**把「最内层默认行为」作为最后一个实参传入，分发器再为每个监听器换成链式 `next`；返回最外层监听器的返回值 |

### 监听与触发

```ts
const off = ctx.on('event-name', (payload) => { /* ... */ })  // effect，卸载自动移除；off() 返回 boolean
ctx.once('event-name', handler)                                // 只触发一次后自注销
ctx.emit('event-name', payload)                                // 触发

ctx.on('e', h, { prepend: true })   // 排到现有监听器之前（布尔值是该选项的简写）
ctx.on('e', h, { global: true })    // 跳过作用域过滤检查，始终接收（见下）
```

### waterfall（瀑布式事件）—— 拦截/网关模式

```ts
// 监听器必须调用 next() 传给下游；不调用即短路流水线
ctx.on('my-plugin/transform', async (_input, next) => {
  const downstream = await next()      // 调用下游
  return downstream.trim()             // 包装返回值
})

// 调用方：把「最内层默认行为」作为最后一个实参传入（不传会被当成 next 而 TypeError）
await ctx.waterfall('my-plugin/transform', input, async () => input)
```

**纪律：只观察/标注的 waterfall 监听器必须调用 `next()`**；不调用直接返回 = 有意短路（否决）。忘记 `next()` 会静默吞掉下游默认行为。

**调用方契约**：最后一个实参就是 continuation。分发器实现会 `args.pop()` 取出它，然后逐个监听器替换成链式 `next` —— 所以监听器**也**始终收到 `next`；两种说法的区别只在「调用方是否要自己传」。

### 作用域过滤分发（scoped dispatch）

Harness 中「关于某个 agent 的活动」的事件（`agent/*`、`tools/*`、`session/*`、`system-prompt/assemble`）以该 agent 的 **scope carrier** 作为 `thisArg` 分发，监听器按注册上下文的作用域标签过滤：

- 事件签名写作 `(this: Scoped<Agent>, payload)`；分发方传 carrier：`ctx.emit(scopeTarget(agent, agent), 'agent/status', payload)`。
- 无标签监听器（普通 `ctx.on`）收到全部事件；带标签监听器（在 `agent.ctx` 上注册）只收到本 scope 及其祖先链的事件——**事件向上流动，绝不向下**（外层组合能观察其下每个 agent）。
- `ctx.on(name, listener, { global: true })` 跳过过滤检查。
- **注册表主体事件有意不过滤**（如 `tools/change`「工具集变化了」）：全局变化对所有 agent 的下一次装配都成立。
- 关键区别：通过 `agent.ctx` 注册只决定 **effect 的作用域归属**；分发是否过滤始终取决于分发方是否传 carrier。

scope API 由 `@deepseek-ai/dsh-scope` 提供：`createScope(ctx, key)`、`scopeOf(ctx)`、`bindScopeParent(key, parent)`、`scopeTarget(base, key)`、`isScopeCarrier(value)`。

### 类型安全事件

```ts
declare module '@deepseek-ai/cordis' {
  interface Events {
    'my-plugin/ready': (payload: { id: string }) => void
    'my-plugin/check': (input: string) => boolean | undefined
    'my-plugin/transform': (input: string, next: () => Promise<string>) => Promise<string>
  }
}
```

事件命名约定 `namespace/action`。Harness 事件在 `interface Events` 的 JSDoc 里用 `@mode` 标签声明模式，生成的目录会把声明与分发调用点做交叉校验。

### 事件类型注册方式

- 从包引入声明合并即可获得事件类型：`import type {} from '@deepseek-ai/dsh-tools'` 让 `'tools/result'` 及其 payload 有类型（不产生运行时导入）。

### 事件生产方契约（自己发事件时）

- 新增事件用 `namespace/action` 命名（如 `agent/step`、`tools/result`、`session/event`），并在声明处标 `@mode`；只按声明的模式分发（类型系统强制方法名）。
- **隔离监听器异常（Harness 约定，不是 Cordis 框架保证）**：Cordis 的 `emit` 同步传播（一个监听器抛错会中断分发、饿死后续监听器），`parallel` 会以 `AggregateError` reject。自己发事件时请照 Harness 的做法实现：用 try/catch 包裹分发循环并记录日志。
- payload 视为只读：观察型事件不要把可变内部状态直接交出去；需要持久化/跨进程的 payload 必须可无损 JSON 序列化。`emit` / `bail` 是同步的，不要在其中做异步工作（返回的 promise 被忽略，异常也不会被合理捕获）。

## 7. Harness 常用事件速览

| 事件 | 模式 | 用途 |
|---|---|---|
| `tools/pre-execute` / `tools/execute` / `tools/post-execute` | waterfall | 工具执行策略：前置决策 / 环绕分派（如超时） / 后置决策（见 `03b-tools-advanced.md` §5） |
| `tools/result` | emit | 观测不可变、可无损 JSON 表示的最终结果 |
| `tools/ptc-dispatch-log` | waterfall | PTC mode 桥接子调用的持久化内容副本 |
| `agent/created` | serial | agent 创建：按序 await 后才 resolve，抛错则创建失败并跳过后续监听器；payload 含 `source` 与可选 `signal` |
| `agent/disposed` / `agent/status` | emit | agent 生命周期与状态观测 |
| `agent/pre-step` | waterfall | 每步前拦截或替换进入该步的消息 |
| `agent/request-error` | waterfall | 单次请求失败的重试策略（返回 `{ kind: 'retry' }` 或委托 `next()`） |
| `agent/assistant-stream` | emit | 进程内 assistant 流分片 |
| `agent/turn-stopping` | serial | 轮次停止边界；异议者用 `agent.steer()` 继续跑（数据决定结果，顺序无关） |
| `approval/request` | waterfall | 审批决策（策略可代替用户作答） |
| `llm/stream` | waterfall | 模型流分发 |
| `llm/models-updated` | emit | 0.2.1-rc.4 起：模型列表后台刷新完成 |
| `system-prompt/assemble` | waterfall | 系统提示词整体装配（作用域过滤；返回值权威）。**0.2.1-rc.2 起不携带工具数组**——输入是 sections / contexts / variables，返回的 `tools` 被忽略 |
| `plugin-manager/operation` | parallel | 0.2.1-rc.4 起：插件管理操作进行中 |
| `plugin-manager/update-state` | emit | 0.2.1-rc.4 起：插件更新状态变化 |
| `schedule/resolve-agent` | waterfall | 0.2.2-alpha.2 起：定时任务解析执行 Agent |
| `forge/providers-changed` | parallel | 0.2.2-alpha.2 起：Forge 提供方集合变化 |
| `session/created` / `session/disposed` | emit | 会话创建 / 销毁 |
| `session/event` | emit | 持久化会话事件流：`turn/*`、`step/*`、`tool/call`、`tool/result`、`assistant/chunk` 都是这里的 `event.type` |
| `session/flush` | parallel | 落盘与遥测的并发刷新 |

> **区分与会查**：`turn/*`、`step/*`、`tool/call`、`tool/result`、`compaction/*` 是**持久化的会话事件类型**，不是同名 Cordis 事件——要观察它们时监听 `session/event` 并检查 `event.type`。谁派发、谁监听、用什么方法派发，查官方 `reference/event-producer-consumer` 矩阵（由 TS Program 生成）；完整签名与触发模式以子系统页面的 `cordis-surface` 区块为准。

> **0.2.2-rc.5 起 `system/message` 为「段更新」**：后续事件携带 section 更新而非完整提示词，消费方须保留全部存活 system 消息（校验按源文本/顺序比对日志状态；被拒装配不提交；无 `source.sections` 的旧消息仍可读）；细则见 `11-cookbook.md` §8。
> **compaction marker 视图**去掉 Markdown `summary` 字段（计数与非空 `summaryEventSeq` 保留）；摘要正文读 `compaction/summary` Session 事件（`summaryEventSeq` + Session 地址）。

### 0.2.0 事件变动（对照官方矩阵）

- **移除**：`agent/session-start`（payload 的 `source` 与语义并入 `agent/created`）、`settings/updated`。
- **模式变更**：`agent/created` 由 `emit` 改为 **serial**，并新增可选 `signal`。
- **新增**：`app-boot/config-reload`、`compaction/summary-error`、`connection/request`、`deepseek-account/*`、`permission-presets/catalog-changed`、`plugin-manager/*`、`schedule/changed`、`workspace/session-activity`、`workspace/session-stop`。
- **改名**：分发方包 `agent-presets` → `agent-preset-registry`。
- **仅新进入矩阵清单**（事件本身早已存在）：`hmr/change`、`hmr/reload`、`internal/config`、`internal/update`，以及模式列留空的 `loader/volatile-update`、`slots/changed`。

### 0.2.1-rc.1 ~ 0.2.2-alpha.2 事件变动（对照官方矩阵）

- **`agent/request` 不再是公开事件**（rc.1 起）：它从「已声明事件」表移入「未声明事件字符串」表，只剩 `agent-loop` 派发、`compaction-basic` 监听。**依赖它替换冻结模型调用配置的插件必须改造**——改用 `agent/request-error`（重试策略）或 `llm/stream`（模型流分发）。
- **新增**：`llm/models-updated`（emit）、`plugin-manager/operation`（parallel）、`plugin-manager/update-state`（emit）、`schedule/resolve-agent`（waterfall）、`forge/providers-changed`（parallel）。
- **`session/attachment` 载荷变更**（rc.3）：由 `{ sessionId, attachmentId }` 改为 `{ sessionId, attachment }`，`attachment` 是含 `attachmentId` / `mediaType` / `bytes` / `width` / `height` 的完整引用。客户端 `session.readAttachment()` 同样改收完整引用。处理端只校验 ID、实际格式、字节长度与宽高；`name` / `originalDimensions` 视为调用方展示信息；**不再校验图片与 Session 的归属关系**。
- **`session/event` 新增事件类型 `team/mode`**（alpha.3）：Team 模式切换会写该类型的持久事件，读 `event.type` 做穷尽分支的消费方要补上它。
- **Session 批量 append**（0.2.2-rc.3）：`Session.append()` 增加数组重载 `append([[type, data], ...])`（新类型 `SessionEventInput`）。批量提交**先提交整批再按序发布**，所以观察者看到的 `session.seq` / `session.surface` 已含完整批次，`session.currentBatchPublication` 标识当前投递成员。**包装或替换 `Session.append`（含测试替身）必须实现两个重载**，否则类型检查不过、运行时也可能只走单事件分支。
- **`internal/update` 监听器签名收窄**（cordis 4.1.0）：由 `(config, noSave, next)` 改为 **`(config, next)`**——`noSave` 仍是 `Fiber.update()` 的第二个实参，但不再传给监听器。
- **Session 写入时序收紧**（rc.2）：`Session.append()` / `appendPluginRecord()` 在实例进入 `SessionStore` 且 `session/created` 同步派发完成**之前**、以及离开之后**拒绝写入**。所有权自 `prepare()` / `enter()` 起算；`session/created` 派发期间 `ctx.agents.get(session.id)` 返回 `undefined`。**把写操作与 Agent 相关工作移出 `session/created` 监听器**，改到 setup 阶段或 `agent/created`。自建 Session 用 **`ctx.sessions.create()`**，不要在 `session/created` 监听器里手工构造或写入。

> 本主题的官方文档链接见 `06-services.md` 末尾。
