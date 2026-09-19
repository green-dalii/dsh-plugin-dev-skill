# 06 · 服务与依赖、事件系统

> 精简提炼自 develop/framework/service、develop/framework/events、reference/event-producer-consumer、reference/cordis-primer、reference/defensive-patterns。API 与分发模式以本地 SDK 类型（cordis 4.0.2 + dsh 0.1.5-rc.2）为准。

## 1. 服务是什么

服务是插件向其他插件公开的**具名能力**，挂在 `ctx` 上：`ctx.tools`、`ctx.llm`、`ctx.agents` 都是服务。任何插件都可以提供服务，供其他插件使用。消费方只指定能力名（如 `'tools'`），不导入提供方 → 配置可以替换提供方而不改消费方。

> 服务名、公开方法和源码位置由仓库自动生成到各子系统页面的 `cordis-surface` 区块；不要另维护一份静态清单。

## 2. 使用服务（消费方）

```ts
export const inject = ['tools']          // 必需依赖；也支持 { tools: 拦截配置 } 对象形式

export function apply(ctx: Context) {
  ctx.tools.register(/* ... */)          // apply 时保证就绪
}
```

框架保证：`apply` 执行时，`inject` 声明的服务全部就绪；否则插件等待（PENDING，合法状态）。

**可选依赖**：不写 `inject`，使用时 `ctx.get('service')` 探测：

```ts
export function apply(ctx: Context) {
  const metrics = ctx.get('metrics')     // strict 默认 true：只返回提供方 fiber ACTIVE 的实现
  metrics?.record('plugin_loaded', 1)    // undefined 时插件仍运行
}
```

## 3. 提供服务（提供方）

### 用 Service 基类

```ts
import { Service, type Context } from '@deepseek-ai/cordis'

export default class MetricsService extends Service {
  static inject = ['llm']                // 服务也可以依赖其他服务

  constructor(ctx: Context) {
    super(ctx, 'metrics')                // 'metrics' 即服务名；构造即注册
  }

  record(event: string, value: number) { /* ... */ }
}
```

### 轻量替代：`ctx.provide`

不需要类时可直接注册（第三个参数是可用性谓词，依赖方据此判断是否就绪）：

```ts
ctx.provide('metrics', { record: (e: string, v: number) => { /* ... */ } }, () => ready)
```

### 类型声明（声明合并）

```ts
declare module '@deepseek-ai/cordis' {
  interface Context {
    metrics: MetricsService
  }
}
```

运行时：`super(ctx, 'metrics')` 以名称注册实例（`ctx.reflect.provide()` 的 effect，卸载提供方即移除服务）；编译时：声明合并让 `ctx.metrics` 有类型（不生成代码，仅类型安全）。

### 加载服务

`Service` 子类本身就是插件（类形态，`Plugin.Constructor`），用 `ctx.plugin(MyService)` 挂载。可选的 `static provide` 声明服务名，供 loader 与工具链读取。

## 4. 依赖的行为语义

1. **必需 vs 可选**：`inject` = 硬依赖；缺失时插件保持 PENDING（合法状态，不崩溃、不半运行）。
2. **依赖跟踪是持续性的**：运行期间必需服务消失 → 依赖插件自动 dispose；服务恢复 → 自动重载。防止消费方持有对不可用服务的引用。
3. **命名空间**：服务名共用扁平空间；`tools`、`llm` 已被占用，自有服务名加辨识度前缀（如 `metrics`、`myCap`）。服务隔离（§5）后同名服务按 scope 分别解析。

## 5. 服务隔离

同一服务名可有多个实例，不同插件组看到不同实例：

```yaml
- id: group-a
  name: '@deepseek-ai/cordis-plugin-group'
  group: true
  isolate:
    shell: true
  config:
    - name: '@deepseek-ai/dsh-bash-local'
      config: { timeoutMs: 5000 }
    - name: './src/plugin-a.ts'
- id: group-b
  name: '@deepseek-ai/cordis-plugin-group'
  group: true
  isolate:
    shell: true
  config:
    - name: '@deepseek-ai/dsh-bash-local'
      config: { timeoutMs: 60000 }
    - name: './src/plugin-b.ts'
```

代码中对应 `ctx.isolate(name, label?)`：`label` 是不透明 symbol，同 label 两次调用加入同一 scope；不传则新建独立 scope。

## 6. 事件系统

### 分发模式（5 种，模式是事件公开约定的一部分）

| 模式 | 调用 | 语义 |
|---|---|---|
| emit | `ctx.emit(name, ...args)` | 同步广播；不等待、忽略返回值 |
| parallel | `await ctx.parallel(name, ...args)` | 所有监听器并发运行并等待（返回 `Promise<void>`） |
| serial | `await ctx.serial(name, ...args)` | 按注册顺序 await；首个非 null/false/undefined 返回值胜出并终止后续 |
| bail | `ctx.bail(name, ...args)` | serial 的**同步**版，返回首个 bail 值（同步返回值，不是 promise） |
| waterfall | `ctx.waterfall(name, ...args)` | 环绕中间件；**监听器**额外收到内置 `next`，返回最外层监听器的返回值 |

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
```

**纪律：只观察/标注的 waterfall 监听器必须调用 `next()`**；不调用直接返回 = 有意短路（否决）。忘记 `next()` 会静默吞掉下游默认行为。

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

- 新增事件用 `namespace/action` 命名，并在声明处标 `@mode`；只按声明的模式分发（类型系统强制方法名）。
- **在分发器中隔离回调异常**：一个抛错的订阅者不得 reject 分发 promise，也不得饿死排在它后面的监听器——用 try/catch 包裹分发循环并记录日志。
- payload 视为只读：观察型事件不要把可变内部状态直接交出去；需要持久化/跨进程的 payload 必须可无损 JSON 序列化。`emit` / `bail` 是同步的，不要在其中做异步工作（返回的 promise 被忽略，异常也不会被合理捕获）。

## 7. Harness 常用事件速览

| 事件 | 模式 | 用途 |
|---|---|---|
| `tools/pre-execute` / `tools/execute` / `tools/post-execute` | waterfall | 工具执行策略：前置决策 / 环绕分派（如超时） / 后置决策（见 `03-tools.md`） |
| `tools/result` | emit | 观测不可变、可无损 JSON 表示的最终结果 |
| `tools/ptc-dispatch-log` | waterfall | PTC mode 桥接子调用的持久化内容副本 |
| `agent/created` / `agent/disposed` / `agent/status` | emit | agent 生命周期与状态观测 |
| `agent/session-start` | emit | 会话启动钩子（通知，非否决） |
| `agent/pre-step` | waterfall | 每步前拦截或替换进入该步的消息 |
| `agent/request` | waterfall | 替换冻结的模型调用配置 |
| `agent/request-error` | waterfall | 单次请求失败的重试策略（返回 `{ kind: 'retry' }` 或委托 `next()`） |
| `agent/assistant-stream` | emit | 进程内 assistant 流分片 |
| `agent/turn-stopping` | serial | 轮次停止边界；异议者用 `agent.steer()` 继续跑（数据决定结果，顺序无关） |
| `approval/request` | waterfall | 审批决策（策略可代替用户作答） |
| `llm/stream` | waterfall | 模型流分发 |
| `system-prompt/assemble` | waterfall | 系统提示词整体装配（作用域过滤；返回值权威） |
| `session/created` / `session/disposed` | emit | 会话创建 / 销毁 |
| `session/event` | emit | 持久化会话事件流：`turn/*`、`step/*`、`tool/call`、`tool/result`、`assistant/chunk` 都是这里的 `event.type` |
| `session/flush` | parallel | 落盘与遥测的并发刷新 |

> **区分与会查**：`turn/*`、`step/*`、`tool/call`、`tool/result`、`compaction/*` 是**持久化的会话事件类型**，不是同名 Cordis 事件——要观察它们时监听 `session/event` 并检查 `event.type`。谁派发、谁监听、用什么方法派发，查官方 `reference/event-producer-consumer` 矩阵（由 TS Program 生成）；完整签名与触发模式以子系统页面的 `cordis-surface` 区块为准。

## 8. 实践规则

- 拦截和策略优先用事件；直接能力调用优先用服务方法。
- 每个注册都应有对应 disposer：`ctx.effect()` 返回一个，或使用 Cordis 自动处理的 API。
- 事件监听器也是 effect：`ctx.on()` 注册的监听器随插件卸载自动移除。
- 清理只发信号不等待会留下孤儿进程：dispose 必须**达到完全停稳**（await 到工作真正结束），而不是只请求停止。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **服务与依赖**：https://deepseek-harness.github.io/deepseek-harness/develop/framework/service
- **事件系统**：https://deepseek-harness.github.io/deepseek-harness/develop/framework/events
- **事件生产方与消费方矩阵**（仓库文档，未发布到文档站）：https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/event-producer-consumer.zh.md
- **Cordis API：Events**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-api/events
- **Cordis API：Service**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-api/service
- **防御性模式**（仓库文档，未发布到文档站）：https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/defensive-patterns.zh.md
- **Cordis 教程 3：服务**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/03-services
- **Cordis 教程 4：事件**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/04-events
