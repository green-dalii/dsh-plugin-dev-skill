# 06 · 服务与依赖、事件系统

> 精简提炼自 develop/framework/service、develop/framework/events、cordis-tutorial 第 3、4 章。

## 1. 服务是什么

服务是插件向其他插件公开的**具名能力**，挂在 `ctx` 上：`ctx.tools`、`ctx.llm`、`ctx.agents` 都是服务。任何插件都可以提供服务，供其他插件使用。消费方只指定能力名（如 `'tools'`），不导入提供方 → 配置可以替换提供方而不改消费方。

## 2. 使用服务（消费方）

```ts
export const inject = ['tools']          // 必需依赖

export function apply(ctx: Context) {
  ctx.tools.register(/* ... */)          // apply 时保证就绪
}
```

框架保证：`apply` 执行时，`inject` 声明的服务全部就绪；否则插件等待（PENDING）。

**可选依赖**：不写 `inject`，使用时 `ctx.get('service')` 探测：

```ts
export function apply(ctx: Context) {
  const metrics = ctx.get('metrics')
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
    super(ctx, 'metrics')                // 'metrics' 即服务名
  }

  record(event: string, value: number) { /* ... */ }
}
```

### 类型声明（声明合并）

```ts
declare module '@deepseek-ai/cordis' {
  interface Context {
    metrics: MetricsService
  }
}
```

运行时：`super(ctx, 'metrics')` 以名称注册实例（effect，卸载提供方即移除服务）；编译时：声明合并让 `ctx.metrics` 有类型（不生成代码，仅类型安全）。

### 加载服务

`Service` 子类本身就是插件（类形态），用 `ctx.plugin(MyService)` 挂载。

## 4. 依赖的行为语义

1. **必需 vs 可选**：`inject` = 硬依赖；缺失时插件保持 PENDING（合法状态，不崩溃、不半运行）。
2. **依赖跟踪是持续性的**：运行期间必需服务消失 → 依赖插件自动 dispose；服务恢复 → 自动重载。防止消费方持有对不可用服务的引用。
3. **命名空间**：服务名共用扁平空间；`tools`、`llm` 已被占用，自有服务名加辨识度前缀（如 `metrics`、`myCap`）。完整占用名单见子系统页面的 `cordis-surface` 区块。

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

## 6. 事件系统

### 分发模式（5 种）

| 模式 | 调用 | 语义 |
|---|---|---|
| emit | `ctx.emit(name, ...args)` | 同步广播；不等待、不收集返回值 |
| parallel | `await ctx.parallel(name, ...args)` | 所有监听器并发运行并等待 |
| serial | `await ctx.serial(name, ...args)` | 按序运行等待；第一个非 null/false/undefined 返回值胜出并停止后续 |
| bail | `ctx.bail(name, ...args)` | serial 的同步版 |
| waterfall | `await ctx.waterfall(name, ...args, next)` | 环绕中间件；见下 |

### 监听与触发

```ts
ctx.on('event-name', (payload) => { /* ... */ })     // 监听（effect，卸载自动移除）
ctx.emit('event-name', payload)                      // 触发
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

事件命名约定 `namespace/action`。

### 事件类型注册方式

- 从包引入声明合并即可获得事件类型：`import type {} from '@deepseek-ai/dsh-tools'` 让 `'tools/result'` 及其 payload 有类型（不产生运行时导入）。

## 7. Harness 常用事件速览

| 事件 | 模式 | 用途 |
|---|---|---|
| `tools/pre-execute` / `tools/execute` / `tools/post-execute` / `tools/result` | waterfall/emit | 工具执行策略与观测（见 `03-tools.md`） |
| `agent/request` | waterfall | 插件可替换模型调用配置 |
| `agent/pre-step` | waterfall | 每步前拦截/注入上下文 |
| `agent/session-start` | emit | 会话启动钩子 |
| `agent/turn-stopping` | serial | 轮次停止策略（steering） |
| `approval/request` | waterfall | 审批决策（策略可代替用户作答） |
| `session/event` | emit | 持久化会话事件流：`turn/*`、`step/*`、`tool/call`、`tool/result`、`assistant/chunk` 都是这里的 `event.type` |

> **区分**：`turn/*`、`step/*`、`tool/call`、`tool/result`、`compaction/*` 是**持久化的会话事件类型**，不是同名 Cordis 事件。要观察它们时监听 `session/event` 并检查 `event.type`。完整签名与触发模式以子系统页面生成的 `cordis-surface` 区块为准。

## 8. 实践规则

- 拦截和策略优先用事件；直接能力调用优先用服务方法。
- 每个注册都应有对应 disposer：`ctx.effect()` 返回一个，或使用 Cordis 自动处理的 API。
- 事件监听器也是 effect：`ctx.on()` 注册的监听器随插件卸载自动移除。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **服务与依赖**：https://deepseek-harness.github.io/deepseek-harness/develop/framework/service
- **事件系统**：https://deepseek-harness.github.io/deepseek-harness/develop/framework/events
- **Cordis 教程 3：服务**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/03-services
- **Cordis 教程 4：事件**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/04-events
