# 02 · 插件基础：形态、生命周期、effect 与 HMR

> 精简提炼自 develop/basic/（第一个插件）、develop/framework/（插件与生命周期）、cordis-tutorial 第 1、2 章。

## 1. 插件是什么

在 Harness 中，**插件是一个导出 `apply` 函数的 TypeScript 模块**。框架在加载时调用 `apply(ctx, config)`，你通过 `ctx` 注册能力。

```ts
import type { Context } from '@deepseek-ai/cordis'

export const name = 'my-plugin'   // 可选，仅用于诊断显示

export function apply(ctx: Context) {
  // 在这里注册能力
}
```

## 2. 三种插件形态

1. **函数形态**（默认推荐）：`export function apply(ctx) {}`，可附带 `name`、`inject`、`Config` 导出。
2. **对象形态**：`export default { name, inject, apply(ctx) {} }`。
3. **类形态**（对外提供服务时）：`export default class MyService extends Service { constructor(ctx) { super(ctx, 'myService') } }`。

## 3. 注册与自动清理（核心机制）

**通过 `ctx` 做的任何注册，在插件卸载时都会自动撤销。** 不需要手动 `removeListener` 或 `clearInterval`。

会被自动追踪清理的操作：

- `ctx.on(event, handler)` — 事件监听
- `ctx.tools.register(tool)` — 工具注册
- `ctx.llm.registerAdapter(names, adapter)` — LLM 适配器注册
- `ctx.plugin(childPlugin)` — 子插件（随父插件递归卸载）
- `ctx.effect(() => cleanup)` — 自定义资源

```ts
export function apply(ctx: Context) {
  ctx.on('some-event', handler)               // 卸载自动移除

  ctx.effect(() => {                          // 自定义资源：返回清理函数
    const connection = createConnection()
    return () => connection.close()           // 插件卸载时运行
  })
}
```

清理顺序：disposer 按注册顺序的**逆序**启动；多个**异步** disposer 会**并发**执行。有顺序依赖的清理必须放进同一个 `ctx.effect()` 返回的 disposer 中串行等待。

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

## 6. dispose 语义

```ts
const fiber = ctx.plugin(myPlugin)
await fiber.dispose()
```

`dispose` 保证：该插件所有注册被移除；子插件递归卸载；Promise 在所有异步清理完成后兑现。

## 7. HMR（热模块替换）

加载 `@deepseek-ai/cordis-plugin-hmr` 后，修改插件源文件触发：卸载旧插件（清理所有注册）→ 重新加载新代码 → 执行新 `apply`。

- 因为注册自动清理，热替换不会残留旧实例的注册。
- 编辑 `cordis.yml` 也会触发：loader 按 `id` 对账条目，只重挂载变化的部分；**没有 `id` 的条目每次读取都视为新条目**。

## 8. 插件作者必须遵守的推论

1. 所有注册走 `ctx.*`；Cordis 不管理的资源包进 `ctx.effect()`。
2. 插件代码随时可能被卸载/重载（HMR、依赖消失、配置变更）——**不要依赖跨重载的全局可变状态**。
3. `apply` 抛异常 → fiber FAILED → 加载失败明确报错（模块无法解析是例外：经 logger 报告但不崩溃）。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **第一个 Harness 插件**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/
- **插件与生命周期**：https://deepseek-harness.github.io/deepseek-harness/develop/framework/
- **Cordis 教程 1：第一个插件**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/01-first-plugin
- **Cordis 教程 2：生命周期与 effect**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/02-lifecycle-and-effects
