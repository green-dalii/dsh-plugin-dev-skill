# 09 · Cordis 入门与 ctx API 速查

> 精简提炼自 reference/cordis-primer、reference/cordis-api/*（context/events/fiber/registry/service/inherited）。

## 1. 五个核心概念

1. **插件是实现 Service 的对象**：函数（带可选 `inject` 与 `apply(ctx)`）或 `Service` 子类，生命周期由 Cordis 挂载到当前上下文。
2. **上下文是服务的容器**：一个服务占据稳定的 `ctx.<key>`（如 `ctx.tools`、`ctx.llm`）；插件按 key 查找服务，不导入具体实现。
3. **通过 `inject` 声明服务依赖**：声明后等待服务就绪才启动；加载顺序由依赖表达，不手动编排。
4. **类型化事件用于通信**：服务通过声明合并注册事件名，以 `emit`/`waterfall`/`parallel`/`serial` 分发。
5. **注册是可逆的副作用**：提示词片段、工具 schema、适配器、提供方、监听器通过 `ctx.effect()`/`ctx.on()` 安装，reload/teardown 时自动撤销。

## 2. 分发模式

| 模式 | 是否 await | 分发顺序 | 有返回值？ |
|---|---|---|---|
| `emit` | 否 | 按注册顺序观察 | 否 |
| `waterfall` | 否（返回 promise 链） | 按注册顺序观察 | 是 |
| `parallel` | 是 | 全部并行 | 否 |
| `serial` | 是 | 按注册顺序 | 是（首个 bail 值） |

## 3. Cordis Waterfall 语义

`ctx.waterfall` 是环绕中间件。监听器接收 `(...args, next)`：

- 调用 `next()` → 执行下游监听器；下游返回值经 `next()` 返回当前层，可包装后向外返回。
- **不调用 `next()` 直接返回 → 短路**（否决/拦截）。
- 协作式监听器通常修改共享的请求/决策对象后委托；也可以完全替换结果。
- 单决策事件中短路是设计意图：策略监听器拥有决策权时可短路；仅标注/观察的监听器必须委托。
- 需要先于普通监听器运行时用 `prepend: true`。

## 4. ctx API 速查（框架继承面 + 常用）

**事件**（混入 ctx）：
- `ctx.on(name, listener, options?)` / `ctx.once(...)` — 注册监听器（effect，卸载自动移除）；options 布尔 = `prepend` 简写；`{ prepend, global }`
- `ctx.emit` / `ctx.parallel` / `ctx.serial` / `ctx.bail` / `ctx.waterfall` — 五种分发

**注册表**：
- `ctx.plugin(plugin, ...config)` — 加载插件（函数/类/对象），返回 fiber（可 await）
- `ctx.inject(deps, callback)` — `ctx.plugin({inject, apply: callback})` 的简写
- `ctx.registry` — 枚举所有 runtime/fiber（诊断 PENDING 用）

**副作用**：
- `ctx.effect(callback)` — 注册可逆副作用；callback 返回 disposer，卸载时运行

**服务存储（反射层）**：
- `ctx.get(name, strict?)` — 读服务（无 inject 要求）；strict 默认 true（仅返回提供方 fiber ACTIVE 的实现）
- `ctx.set(name, value)` — 覆盖已提供服务的值（仅提供方 fiber 可 set）
- `ctx.provide(name, value)` — 注册归当前 fiber 所有的服务实现（effect）
- `ctx.accessor(name, {get, set?})` — 定义计算型上下文属性
- `ctx.mixin(name, mixins)` — 把服务成员直接挂到 ctx（如 `ctx.on` 转发到 `ctx.events.on`）

**上下文派生**（不修改父上下文）：
- `ctx.extend(meta?)` — 创建带额外元数据的子上下文
- `ctx.isolate(name, label?)` — 为某服务创建独立作用域（同 label 两次调用加入同一作用域）
- `ctx.intercept(name, config)` — 为下层插件合并服务拦截配置

**环境句柄**：
- `ctx.root`（根上下文）、`ctx.scope`、`ctx.fiber`（当前 fiber）、`ctx.registry`、`ctx.reflect`、`ctx.events`、`ctx.logger`
- `ctx.logger(name)` — 具名 logger
- `ctx.timer` + `interval/timeout/throttle/debounce` — 可清理定时器助手（timer 插件提供）
- `ctx.loader` / `ctx.hmr` — loader 与 HMR watcher（存在时）

**框架继承事件**（低频，知道即可）：`internal/plugin`、`internal/status`、`internal/service`、`internal/update`、`internal/get`、`internal/set`、`internal/listener`、`internal/dispatch`、`hmr/change`、`hmr/reload`、`exit`、`loader/config-update`、`loader/entry-init`、`loader/partial-dispose`、`loader/patch-context`。

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

`Inject`：数组形式 = 无拦截配置的服务列表；对象形式 = 服务名 → 拦截配置映射。

## 6. Service 基类

- 子类构造时 `super(ctx, name)`，立即注册为 `ctx.<name>`，随所属 fiber 自动移除。
- 静态 symbol 键（一般不用碰）：`Service.init`（构造后运行的方法）、`Service.check`（可用性谓词）、`Service.invoke`（可调用服务体，如 `ctx.logger()`）、`Service.extend`、`Service.tracker`、`Service.resolveConfig`。
- `declare module '@deepseek-ai/cordis' { interface Context { <name>: <Type> } }` 提供类型（不产生运行时接线）。

## 7. Fiber

- 每个已加载插件实例一个 fiber：`PENDING → LOADING → ACTIVE → UNLOADING → DISPOSED`（`FAILED` 分支）。
- `fiber.dispose()` — 等待所有清理（含异步 disposer）完成，递归卸载子插件。
- `fiber.update(config)` — 更新配置（触发按 diff 的处理）。

## 8. Loader 配置细节

- `@deepseek-ai/cordis-plugin-include` 将 `!!js` 解析为表达式节点。
- Loader 在声明的注入激活后，基于插件上下文插值条目的 `config`；在每次挂载决策时基于 loader 上下文插值 `disabled`。
- 其余条目元数据保持字面值。环境选择插件请用 overlay，不要塞 `!!js` 进 `name`。

## 9. 实践规则

- 把行为封装为插件：工具流水线归 `ctx.tools`，模型流归 `ctx.llm`，agent 协调归 `ctx.agents`。
- 拦截和策略优先事件；直接能力调用优先服务方法。
- 每个注册都有 disposer；teardown 有顺序要求时把相关工作放同一 effect。

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
