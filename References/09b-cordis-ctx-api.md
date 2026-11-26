# 09b · Cordis ctx API 速查

> SDK 基线：`@deepseek-ai/*` **0.2.3-alpha.2**（cordis **4.2.0-alpha.1**）。

> 本文件是 Cordis 入门指南的第 2/2 部分：速查 ctx 继承面与常用 API（事件、注册表、副作用、服务存储、上下文派生、环境句柄、框架继承事件）；第 1 部分见 `09-cordis-primer.md`（核心概念、分发模式、Waterfall 语义、Plugin / Fiber / Loader / 实践规则）。

## 4. ctx API 速查（框架继承面 + 常用）

**事件**（混入 ctx）：
- `ctx.on(name, listener, options?)` / `ctx.once(...)` — 注册监听器（effect，卸载自动移除）；返回移除用的 disposer（`() => boolean`）；options 布尔 = `prepend` 简写，对象为 `{ prepend, global }`
- `global: true` = 跳过作用域过滤检查，始终接收事件；其余监听器默认受 scope 过滤（见 `06b-events.md` §6）
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
- `ctx.provide(name, value)` — 返回 disposer，注册一个由当前 fiber 拥有的服务实现（effect）；**类型重载只有两个参数**，`check` 可用性谓词不在 `Context` 的重载里
- `ctx.reflect.provide(name, value, check)` — 需要可用性谓词时走这条（`Context` 上声明了 `reflect: ReflectService`）；**`ctx.provide(name, value, check)` 传三个参数会类型报错**
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
- `ctx.loader` / `ctx.hmr` — loader 与 HMR watcher（存在时）。HMR 插件包名已由 `@deepseek-ai/cordis-plugin-hmr` 变为 **`@deepseek-ai/dsh-hmr`**（`ctx.hmr` 运行时仍可用，但已从 inherited 目录移除）

> 作用域（agent-scope）不是 ctx 的属性：它由 `@deepseek-ai/dsh-scope` 提供的 `createScope(ctx, key)` / `scopeOf(ctx)` / `scopeTarget(base, key)` 承担，`agent.ctx` 是 agent 的带作用域上下文。

**框架继承事件**（低频，知道即可；标注的是分发模式）：
- 通知型：`internal/plugin`、`internal/status`、`internal/service`、`internal/dispatch`
- waterfall 拦截：`internal/config`（解析插件配置）、`internal/update`（签名 `(this: Fiber, config: any, next: () => void): void`——cordis **4.1.0** 起 `noSave` **不再传入监听器**（它仍是 `Fiber.update()` 的第二个实参）；跳过 `next()` 即否决，且 `next` **只能同步调用**——上游 loader 的迁移就是把 `await next()` 改成 `next()`）、`internal/get` / `internal/set`（经 ctx 代理读写服务）、`loader/patch-context`（同样只同步调用）
- bail：`internal/listener`（注册监听器前，非 null 结果替换注册）
- 其它：`exit(signal)`、`loader/config-update`、`loader/entry-init`、`loader/partial-dispose`、`hmr/change`、`hmr/reload`、`hmr/config-update-failed`（parallel）

> 本主题的官方文档链接见 `13-upgrade-guides.md` §0。
