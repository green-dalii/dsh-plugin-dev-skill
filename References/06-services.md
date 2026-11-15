# 06 · 服务与依赖

> 精简提炼自 develop/framework/service、develop/framework/events、reference/event-producer-consumer、reference/cordis-primer、reference/defensive-patterns。API 与分发模式以本地 SDK 类型（cordis **4.1.0** + `@deepseek-ai/*` **0.2.2-rc.3**）为准。逐版本变化见 `References/00-INDEX.md`。

本文覆盖服务与依赖模型（§1-§5）与实践规则（§8）。事件系统与 Harness 常用事件速览见 06b-events.md。

> 本文件保留拆分前的章节编号：§6「事件系统」与 §7「Harness 常用事件速览」在 `06b-events.md`，故本文件从 §5 直接跳到 §8「实践规则」。

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

不需要类时可直接注册（`ctx.provide` 的 public 重载只有 `(name, value?)`，第三个参数 `check` 只在运行时存在）：

```ts
// 可用性谓词是「已注册但暂时不可用」的中间态；它不在 ctx.provide 的类型重载里，走 ctx.reflect.provide
ctx.reflect.provide('metrics', { record: (e: string, v: number) => { /* ... */ } }, () => ready)
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
- **防御性模式**（仓库文档目录，未发布到文档站）：https://github.com/deepseek-ai/deepseek-harness/tree/master/docs/defensive-patterns
- **Cordis 教程 3：服务**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/03-services
- **Cordis 教程 4：事件**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/04-events
