# 02 · 插件基础：形态、生命周期、effect 与 HMR

> 精简提炼自 develop/basic/（第一个插件）、develop/framework/（插件与生命周期）、cordis-tutorial 第 1、2 章。API 签名以本地 `@deepseek-ai/cordis` 4.0.2 为准。

## 1. 插件是什么

在 Harness 中，**插件是一个导出 `apply` 函数的 TypeScript 模块**。框架在加载时调用 `apply(ctx, config)`，你通过 `ctx` 注册能力：

```ts
import type { Context } from '@deepseek-ai/cordis'

export const name = 'my-plugin'   // 可选，用于诊断显示与 logger 名
export const inject = ['tools']   // 可选，所需服务

export function apply(ctx: Context) {
  // 在这里注册能力
}
```

模块级还可导出 `Config`（standard-schema 校验器）声明自己的配置；校验失败时插件以 `ValidationError` 停在 FAILED，`apply` 永不执行。`provide`、`intercept` 与它们属于同一组静态元数据。

## 2. 三种插件形态

Cordis 的 `Plugin` 类型是 `Function | Constructor | Object`，三者共享同一组元数据：`name`、`Config`、`inject`、`provide`、`intercept`。

1. **函数形态**（默认推荐）：`export function apply(ctx, config) {}`，可附带上述导出。
2. **对象形态**：`export default { name, inject, apply(ctx, config) {} }`。
3. **类形态**（对外提供服务时）：

```ts
import { Service, type Context } from '@deepseek-ai/cordis'

export default class MyService extends Service {
  static inject = ['tools']
  constructor(ctx: Context) {
    super(ctx, 'myService')      // 注册名；运行时会回落到类的 static provide
    // 构造函数里只做同步初始化
  }
}
```

- `super(ctx, name)` 立即注册服务并随 fiber 自动卸载；被 `Service.init` 标记的方法在构造之后运行。
- 声明式依赖也可写成 `@Inject('tools')` 装饰类或类方法（方法会延迟到服务就绪再调用）。
- 简写 `ctx.inject(['tools'], (ctx) => { ... })` 等价于 `ctx.plugin({ inject: ['tools'], apply })`：依赖变化时自动卸载并重跑。

## 3. 注册与自动清理（核心机制）

**通过 `ctx` 做的任何注册，在插件卸载时都会自动撤销。** 不需要手动 `removeListener` 或 `clearInterval`。

会被自动追踪清理的操作：

- `ctx.on(event, handler)` — 事件监听
- `ctx.tools.register(tool)` — 工具注册
- `ctx.llm.registerAdapter(names, adapter)` — LLM 适配器注册
- `ctx.plugin(childPlugin)` — 子插件（随父插件递归卸载）
- `ctx.provide(name, value?, check?)` — 直接提供一个服务（`Service` 的底层原语）
- `ctx.effect(() => cleanup, label?)` — 自定义资源

```ts
export function apply(ctx: Context) {
  ctx.on('some-event', handler)               // 卸载自动移除

  ctx.effect(() => {                          // 自定义资源：返回清理函数
    const connection = createConnection()
    return () => connection.close()           // 插件卸载时运行
  }, 'my-connection')
}
```

- `effect` 的主体可返回单个 disposer、它的 promise，或**逐个 yield disposer 的（异步）生成器**；`label` 出现在 `fiber.getEffects()` 诊断里。
- 清理顺序：disposer 按注册顺序的**逆序**启动；多个**异步** disposer 会**并发**执行（`Promise.all`），不保证逐个完成。有顺序依赖的清理必须放进同一个 `ctx.effect()` 返回的 disposer 中串行等待。
- fiber 已 dispose 后再 `ctx.effect()` 会抛 `CordisError('INACTIVE_EFFECT')`；重复调用同一个 disposer 是 no-op。

## 4. Fiber 状态机

每个已加载的插件实例拥有一个 **fiber**：

```
PENDING → LOADING → ACTIVE → UNLOADING → DISPOSED
                 ↘ FAILED
```

| 状态 | 含义 |
|---|---|
| PENDING | 已声明，但所需依赖（inject）未就绪 |
| LOADING | 依赖就绪，正在执行 `apply` |
| ACTIVE | 插件运行中 |
| FAILED | `apply` 或配置校验抛出异常 |
| UNLOADING / DISPOSED | 正在卸载 / 已完全卸载 |

**诊断提示**：插件既不执行也不报错时，多半是 PENDING —— `inject` 的服务没人提供。用 `ctx.registry` 枚举检查：

```ts
import { FiberState, type Context } from '@deepseek-ai/cordis'

export function apply(ctx: Context) {
  setTimeout(() => {
    for (const runtime of ctx.registry.values()) {
      for (const fiber of runtime.fibers) {
        if (fiber.state === FiberState.PENDING) {
          console.log(`${fiber.name} is PENDING — a required service is missing`)
        }
      }
    }
  }, 500)
}
```

## 5. 依赖驱动的加载

```ts
export const inject = ['tools', 'llm']

export function apply(ctx: Context) {
  // ctx.tools 和 ctx.llm 在此处已就绪
}
```

- `inject` 不是一次性启动检查：**运行期间必需服务消失 → 插件自动 dispose；服务恢复 → 自动重载**。
- 这就是“配置可以替换服务”的机制：卸载 `dsh-bash-local`、挂载另一个 `shell` 提供方，所有注入 `'shell'` 的插件都会自动重启并使用新实现。
- 需要同一服务的多个互不干扰实例时，用 `ctx.isolate(name, label?)` 打开 isolation realm（agent preset 靠它让每会话拿到不同实现）；`ctx.intercept(name, config)` 则给下层插件追加该服务的配置。

## 6. dispose 与重载语义

```ts
const fiber = ctx.plugin(myPlugin)
await fiber.dispose()      // 卸载
await fiber.restart()      // 用当前配置立即重载
fiber.update(newConfig)    // 校验新配置（失败抛 ValidationError）后重启
await fiber.await()        // 等待当前生命周期工作，并重抛启动错误
```

`dispose` 保证：该插件所有注册被移除；子插件递归卸载；Promise 在所有异步清理完成后兑现。

## 7. HMR（热模块替换）

加载 `@deepseek-ai/cordis-plugin-hmr`（base 里的行 `id: hmr`；上游新文档称 `dsh-hmr`）后，修改插件源文件触发：卸载旧插件（清理所有注册）→ 重新加载新代码 → 执行新 `apply`。

- 因为注册自动清理，热替换不会残留旧实例的注册。
- 默认只监视**配置**变更并热重载受影响的行；**外部插件的模块（代码）变更在当前实现中仍需重启进程**。
- 编辑 `cordis.yml` 也会触发：loader 按 `id` 对账条目，只重挂载变化的部分；**没有 `id` 的条目每次读取都视为新条目**。

## 8. 插件作者必须遵守的推论

1. 所有注册走 `ctx.*`；Cordis 不管理的资源包进 `ctx.effect()`。
2. 插件代码随时可能被卸载/重载（HMR、依赖消失、配置变更）——**不要依赖跨重载的全局可变状态**。
3. `apply` 抛异常或 `Config` 校验失败 → fiber FAILED → 加载失败明确报错（模块无法解析是例外：经 logger 报告但不崩溃）。
4. 清理必须异步等待真正停稳，而不是只发终止信号就返回，否则会留下孤儿进程与迟到事件。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **第一个 Harness 插件**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/
- **插件与生命周期**：https://deepseek-harness.github.io/deepseek-harness/develop/framework/
- **Cordis 教程 1：第一个插件**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/01-first-plugin
- **Cordis 教程 2：生命周期与 effect**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/02-lifecycle-and-effects
- **Cordis API 参考（Fiber / Context / Registry / Service）**：https://deepseek-harness.github.io/deepseek-harness/reference/cordis-api/fiber
