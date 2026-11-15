# 09 · Cordis 入门与 ctx API 速查

> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。
>
> 精简提炼自 reference/cordis-primer、reference/cordis-api/*（context/events/fiber/registry/service/inherited）。ctx API 与分发模式已逐条对照本地 `@deepseek-ai/cordis` **4.1.0** 类型定义核实。
>
> **4.1.0 相对 4.0.6-alpha.1 的变化（本次基线）**：`src/*.ts` 有 6 个文件变动（`context.ts` / `events.ts` / `fiber.ts` / `logger.ts` / `reflect.ts` / `utils.ts`），公开 API 层面要注意三点：
> - **`Fiber.update()` 返回类型 `void` → `Awaitable<void>`**：loaded 路径会 `return fiber.restart()` / `task`，所以**可以直接 `await fiber.update(cfg)`**（见 §7）。
> - **`LoggerLevel` 数值重排**：`ERROR=0` / **`WARN=1`** / **`INFO=2`** / `DEBUG=3`（4.0.x 是 `INFO=1` / `WARN=2`）。按数字下标比大小的 exporter 会静默错位——请用枚举名比较。
> - **`internal/update` 监听器签名收窄**：`(config, noSave, next)` → **`(config, next)`**；`noSave` 仍是 `Fiber.update()` 的第二个实参，但不再传给监听器。
>
> 其余为内部重构（`symbols.caller` 新增；reflect 条目由 `fiber` 改为 `ctx` 并新增 `dependents` / `release` / `isolate`；hook 表改用无原型对象；`Context.baseUrl` 类型放宽为 `string | undefined`），普通插件无需改代码。
>
> **4.0.6 相对 4.0.5-alpha.1 的变化极小**：`src/*.ts` 中**只有 `fiber.ts` 变动**（`context.ts` / `registry.ts` / `service.ts` / `reflect.ts` / `utils.ts` / `events.ts` / `index.ts` 逐字节未变）。新增三处公开能力（**非破坏**）：
> - `fiber.rawConfig`（getter/setter）—— 读取或保留**原始**配置输入，不做表达式求值也不做校验；取代直接读 `fiber._config`。
> - `fiber.effectiveConfig`（getter）—— 读取现有激活 / update 生命周期**发布**的配置对象（不克隆、不重新解析）；取代直接读 `fiber.config`。
> - `fiber.resolveConfig(config)` —— 公开的配置求值入口：按本 fiber 的 `internal/config` hooks 与运行时 schema 求值并校验候选配置，**但不发布结果、不替换原始输入、不提交易失引用**。原先的私有 `_resolveConfig` 已移除。
>
> **4.0.4 相对 4.0.2 的公开 API 差异也很小**：新增类型导出 `Volatile` / `VolatileSnapshot`；`Fiber.update()` 在该版改为返回 `void`（**4.1.0 又改回 `Awaitable<void>`**，见上）；`'internal/update'` 监听器签名在该版收窄为 `next: () => void`（同步）。
>
> **拆分说明**：`## 4. ctx API 速查（框架继承面 + 常用）` 已独立为同目录的 `09b-cordis-ctx-api.md`；本文件保留原编号（§1–§3、§5–§9），内容未改动。

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
- `fiber.update(config, noSave?)` — 更新配置并重启（先跑 `internal/update` waterfall，可能被否决或替换）。**4.1.0 起返回 `Awaitable<void>`**：loaded 路径会 `return fiber.restart()` / `task`，所以直接 `await fiber.update(cfg)` 即可等到重启完成（4.0.4~4.0.6 返回 `void`，那时才需要 `await fiber.await()`）；只有 `ValidationError` 会同步传播。
- **配置读写三入口**（4.0.6 起推荐）：
  - `fiber.effectiveConfig` —— 已发布的、经校验的配置对象（不克隆、不重新解析）；激活前是 `undefined`，卸载后仍可读；要活实例就查 `state`。
  - `fiber.rawConfig` —— 原始输入（未求值、未校验）；可读取也可写入（写入**不改变运行中配置、不触发 update**），用于「保留原始输入以便下次激活时重新解析」。
  - `fiber.resolveConfig(candidate)` —— 用本 fiber 的 `internal/config` hooks 与运行时 schema 求值并校验候选；**不发布结果、不替换原始输入、不提交易失引用**；schema 拒绝时抛 `ValidationError`，hook 错误直接传播。用它做「先验证再提交」。
- 处置器按注册逆序**开始**调用，但多个异步处置器并发执行；有顺序依赖的清理必须放进同一个 effect 的处置器里串行等待。

## 8. Loader 配置细节

- `@deepseek-ai/cordis-plugin-include` 将 `!!js` 解析为表达式节点。
- **volatile config**：`Schema.<field>().volatile()` 得到稳定引用，用 `.get()` 读取；此类字段提交时**不重挂载**插件、不经过 `internal/update`，只发出 `loader/volatile-update`（变更路径数组）。典型用途是运行中可调、但不应触发重启的参数。
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
