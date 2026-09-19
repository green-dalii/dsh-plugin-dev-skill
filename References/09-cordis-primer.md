# 09 · Cordis 入门与 ctx API 速查

> 精简提炼自 reference/cordis-primer、reference/cordis-api/*（context/events/fiber/registry/service/inherited）。ctx API 与分发模式已逐条对照本地 `@deepseek-ai/cordis` 4.0.2 类型定义核实。

## 1. 五个核心概念

1. **插件是实现 Service 的对象**：函数（带可选 `inject` 与 `apply(ctx)`）或 `Service` 子类，生命周期由 Cordis 挂载到当前上下文。
2. **上下文是服务的容器**：一个服务占据稳定的 `ctx.<key>`（如 `ctx.tools`、`ctx.llm`、`ctx.sessions`）；插件按 key 查找服务，不导入具体实现。
3. **通过 `inject` 声明服务依赖**：声明后等待服务就绪才启动；加载顺序由依赖表达，不手动编排。
4. **类型化事件用于通信**：服务通过声明合并注册事件名，以 `emit`/`waterfall`/`parallel`/`serial`/`bail` 分发。
5. **注册是可逆的副作用**：提示词片段、工具 schema、适配器、提供方、监听器通过 `ctx.effect()`/`ctx.on()` 安装，reload/teardown 时自动撤销。

## 2. 分发模式

| 模式 | 是否 await | 分发顺序 | 有返回值？ |
|---|---|---|---|
| `emit` | 否 | 按注册顺序观察 | 否 |
| `waterfall` | 否（Cordis 不 await，调用方自行 await） | 按注册顺序观察（环绕） | 是（最外层监听器的返回值） |
| `parallel` | 是 | 全部并行 | 否（`Promise<void>`） |
| `serial` | 是 | 按注册顺序 | 是（首个 bail 值） |
| `bail` | 否（同步） | 按注册顺序，直到首个 bail 值 | 是（首个 bail 值） |

bail 值 = 非 `null`、非 `false`、非 `undefined` 的返回值（`isBailed()` 的定义）。分发模式是事件公开约定的一部分：Harness 事件用 `@mode` 标签声明，生成的目录会与分发调用点交叉校验。

## 3. Cordis Waterfall 语义

`ctx.waterfall` 是环绕中间件。监听器接收 `(...args, next)`：

- 调用 `next()` → 执行下游监听器；下游返回值经 `next()` 返回当前层，可包装后向外返回。
- **不调用 `next()` 直接返回 → 短路**（否决/拦截，连内置行为一起跳过）。
- 协作式监听器通常修改共享的请求/决策对象后委托；也可以完全替换结果，下游只看到替换后的结果。
- 单决策事件中短路是设计意图：策略监听器拥有决策权时可短路；仅标注/观察的监听器必须委托。
- 需要先于普通监听器运行时用 `prepend: true`。

## 4. ctx API 速查（框架继承面 + 常用）

**事件**（混入 ctx）：
- `ctx.on(name, listener, options?)` / `ctx.once(...)` — 注册监听器（effect，卸载自动移除）；返回移除用的 disposer（`() => boolean`）；options 布尔 = `prepend` 简写，对象为 `{ prepend, global }`
- `global: true` = 跳过作用域过滤检查，始终接收事件；其余监听器默认受 scope 过滤（见 `06-framework-services-events.md` §6）
- `ctx.emit` / `ctx.parallel` / `ctx.serial` / `ctx.bail` / `ctx.waterfall` — 五种分发；每种都有 `(thisArg, name, ...args)` 重载，用于作用域过滤分发

**注册表**：
- `ctx.plugin(plugin, ...config)` — 加载插件（函数/类/对象），返回 fiber（可 await）
- `ctx.inject(deps, callback)` — `ctx.plugin({inject, apply: callback})` 的简写；必需服务变化时回调会被卸载并重跑
- `ctx.registry` — 枚举所有 runtime/fiber（诊断 PENDING 用）

**副作用**：
- `ctx.effect(callback, label?)` — 注册可逆副作用，返回可 await 的 disposer；回调可返回单个 disposer、disposer 可迭代对象（生成器，逐个登记）、promise 或 async iterable
- `ctx.fiber.getEffects()` — 取当前 fiber 的活动 effect 元数据树（含 `ctx.on("event")` 这类 label）

**服务存储（反射层）**：
- `ctx.get(name, strict?)` — 读服务（无 inject 要求）；strict 默认 true（仅返回提供方 fiber ACTIVE 的实现）
- `ctx.set(name, value)` — 覆盖已提供服务的值（仅提供方 fiber 可 set；对未提供的名字会抛错）
- `ctx.provide(name, value, check?)` — 注册归当前 fiber 所有的服务实现（effect）；`check` 是可用性谓词，依赖方据此决定是否就绪
- `ctx.accessor(name, {get, set?})` — 定义计算型上下文属性（`set` 返回 `false` 可拒绝写入）
- `ctx.mixin(name, mixins)` — 把服务成员直接挂到 ctx（如 `ctx.on` 转发到 `ctx.events.on`）

**上下文派生**（不修改父上下文）：
- `ctx.extend(meta?)` — 创建带额外元数据的子上下文
- `ctx.isolate(name, label?)` — 为某服务创建独立 scope；`label` 是不透明 symbol，同 label 两次调用加入同一 scope
- `ctx.intercept(name, config)` — 为下层插件合并服务拦截配置（近根者先应用）

**环境句柄**：
- `ctx.root`（根上下文）、`ctx.fiber`（当前 fiber）、`ctx.registry`、`ctx.reflect`、`ctx.events`、`ctx.logger`、`ctx.baseUrl?`
- `ctx.logger(name)` — 具名 logger
- `ctx.timer` + `interval/timeout/throttle/debounce` — 可清理定时器助手（timer 插件提供；`setTimeout`/`setInterval` 已废弃）
- `ctx.loader` / `ctx.hmr` — loader 与 HMR watcher（存在时）

> 作用域（agent-scope）不是 ctx 的属性：它由 `@deepseek-ai/dsh-scope` 提供的 `createScope(ctx, key)` / `scopeOf(ctx)` / `scopeTarget(base, key)` 承担，`agent.ctx` 是 agent 的带作用域上下文。

**框架继承事件**（低频，知道即可；标注的是分发模式）：
- 通知型：`internal/plugin`、`internal/status`、`internal/service`、`internal/dispatch`
- waterfall 拦截：`internal/config`（解析插件配置）、`internal/update`（配置更新，跳过 `next()` 即否决）、`internal/get` / `internal/set`（经 ctx 代理读写服务）、`loader/patch-context`
- bail：`internal/listener`（注册监听器前，非 null 结果替换注册）
- 其它：`exit(signal)`、`loader/config-update`、`loader/entry-init`、`loader/partial-dispose`、`hmr/change`、`hmr/reload`、`hmr/config-update-failed`（parallel）

## 5. Plugin 入口点类型（registry）

```ts
type Plugin<T> =
  | Plugin.Function<T>   // (ctx, config) => any
  | Plugin.Constructor<T>// new (ctx, config) => any
  | Plugin.Object<T>     // { apply(ctx, config) }

// 公共元数据
interface Plugin.Base<T> {
  name?: string                        // 诊断显示名
  Config?: StandardSchemaV1<any, T>    // config 校验器
  inject?: Inject                      // 必需服务
  provide?: string | string[]          // 本插件提供的服务名
  intercept?: Dict<boolean>            // 声明消费的拦截配置
}
```

`Inject`：数组形式 = 无拦截配置的服务列表；对象形式 = 服务名 → 拦截配置映射。`@Inject(name, config?)` 装饰器可用于类或类方法（方法形态会延迟到依赖就绪才调用）。

## 6. Service 基类

- 子类构造时 `super(ctx, name)`，立即注册为 `ctx.<name>`，随所属 fiber 自动移除。
- 静态 symbol 键（一般不用碰）：`Service.init`（构造后运行的方法）、`Service.check`（可用性谓词）、`Service.invoke`（可调用服务体，如 `ctx.logger()`）、`Service.config`（拦截配置虚类型）、`Service.extend`、`Service.tracker`、`Service.resolveConfig`。
- `declare module '@deepseek-ai/cordis' { interface Context { <name>: <Type> } }` 提供类型（不产生运行时接线）。

## 7. Fiber

- 每个已加载插件实例一个 fiber：`PENDING → LOADING → ACTIVE → UNLOADING → DISPOSED`（`LOADING`/`ACTIVE` 抛错则进入 `FAILED`）。
- `fiber.dispose()` — 等待所有清理（含异步 disposer）完成，递归卸载子插件。
- `fiber.restart()` / `fiber.await()` — 按当前配置重载 / 等到稳定态并抛出启动错误。
- `fiber.update(config, noSave?)` — 更新配置（先跑 `internal/update` waterfall，可能被否决或替换）。
- 处置器按注册逆序**开始**调用，但多个异步处置器并发执行；有顺序依赖的清理必须放进同一个 effect 的处置器里串行等待。

## 8. Loader 配置细节

- `@deepseek-ai/cordis-plugin-include` 将 `!!js` 解析为表达式节点。
- Loader 在声明的注入激活后，基于插件上下文插值条目的 `config`；在每次挂载决策时基于 loader 上下文插值 `disabled`。其余条目元数据保持字面值。
- 环境选择插件请用 overlay，不要塞 `!!js` 进 `name`。

## 9. 实践规则

- 把行为封装为插件：工具流水线归 `ctx.tools`，模型流归 `ctx.llm`，agent 协调归 `ctx.agents`。
- 拦截和策略优先事件；直接能力调用优先服务方法。
- 每个注册都有 disposer；teardown 有顺序要求时把相关工作放同一 effect。
- 观察 vs 探测：需要服务就用 `inject`，只是问「在不在」用 `ctx.get()`。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **Cordis 入门**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-primer
- **Cordis API：Context**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-api/context
- **Cordis API：Events**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-api/events
- **Cordis API：Fiber**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-api/fiber
- **Cordis API：Registry**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-api/registry
- **Cordis API：Service**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-api/service
- **Cordis API：Inherited**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-api/inherited
- **插件与生命周期**：https://deepseek-harness.github.io/deepseek-harness/develop/framework/
