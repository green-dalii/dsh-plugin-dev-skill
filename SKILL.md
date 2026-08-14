---
name: dsh-plugin-dev-skill
description: 指导任何 Agent 正确、高效、符合规范地开发 DeepSeek Harness（DSH）插件。涵盖 Tool（defineTool）、LLM 适配器、服务与依赖、事件系统、配置、打包发布，以及 Cordis 框架的心智模型、代码模板与验证清单。
whenToUse: 当任务涉及为 DeepSeek Harness 编写/修改/调试插件（tool、LLM adapter、服务提供方、钩子、UI、协议桥等），编写或修改 cordis.yml / cordis.patch.yml / dsh.profile / dsh.bundle 配置，使用 dsh plugin 命令，或需要理解 ctx.tools、ctx.llm、ctx.agents、ctx.sessions 等服务与 tools/*、agent/*、session/event 等事件时，加载本技能。
---

# DeepSeek Harness Plugin Dev Skill

> 让任何 Agent 都能正确、高效、符合规范地开发 DeepSeek Harness（DSH）插件。
> 本技能是 DSH 插件开发的操作手册：先给出心智模型与铁律，再给出可直接照抄的代码模板与分步流程，最后给出验证清单。深度背景见 `References/` 目录下的精简提炼文档。

---

## 0. 何时使用本技能

当任务涉及以下任意一项时，必须加载本技能：

- 为 DeepSeek Harness 编写、修改或调试**插件**（tool、LLM adapter、服务提供方、钩子、UI、协议桥等）
- 编写或修改 `cordis.yml` / `cordis.patch.yml` / `dsh.profile` / `dsh.bundle` 配置
- 用 `dsh plugin ...` 安装、移除、打包插件
- 理解 DSH 中 `ctx.tools`、`ctx.llm`、`ctx.agents`、`ctx.sessions` 等服务或 `tools/*`、`agent/*`、`session/event` 等事件
- 研究 DSH 的插件模型（Cordis 框架）如何工作

先读本 SKILL.md 全篇，再动手。动手前先读项目里已有的 `cordis.yml` / profile / 相关源码，确认现有约定。

---

## 1. 心智模型：DSH 是构建在 Cordis 之上的插件化系统

一句话概括：**DeepSeek Harness 是一个 Agent Harness SDK，其中每一项能力——工具、LLM 适配器、文件访问、agent loop 本身——都是一个插件（component），挂载到一个共享的上下文（context）上。**

三个核心概念（来自论文《A Programming Paradigm for Spatiotemporal Composability》，见 `References/10-spatiotemporal.md`）：

| 概念 | 含义 | 在代码中的体现 |
|---|---|---|
| **可逆效应（revertible effect）** | 组件对共享环境的每次修改都携带一个逆操作，运行时跟踪并在组件卸载时按 LIFO 顺序恢复 | `ctx.effect(() => () => cleanup)`；`ctx.on()`、`ctx.tools.register()` 等都是 effect，卸载自动撤销 |
| **反应式余效应（reactive coeffect）** | 组件声明它依赖哪些服务；服务出现/消失/换实现时，组件自动激活/停用/重载 | `export const inject = ['tools']`；依赖消失时插件自动 dispose，恢复时自动重载 |
| **Fiber（组件实例）** | 每个已加载的插件实例是一个 fiber，有生命周期状态机 | `PENDING → LOADING → ACTIVE → UNLOADING → DISPOSED`（`apply` 抛错则 `FAILED`） |

由此得到的**铁律**：

1. **所有注册都必须通过 `ctx` 完成**（`ctx.on` / `ctx.tools.register` / `ctx.effect` / `ctx.plugin` / `ctx.provide`）。凡是经过 `ctx` 的注册，卸载时自动清理，**绝不手动 removeListener / clearInterval**。
2. **凡是不经过 `ctx` 管理的资源**（网络连接、自建定时器、文件句柄、watcher），必须包在 `ctx.effect(() => { ...; return () => cleanup })` 里。
3. **依赖必须声明**（`inject`），不要用 `ctx.get()` 探测必需依赖，不要臆想加载顺序——顺序由依赖决定，不由 `cordis.yml` 行序决定。
4. **配置必须可配置**：任何不同部署取值可能不同的参数都必须成为 `Config` 字段，绝无硬编码（检验标准：能否在 `cordis.yml` 中改这个值而不改代码？）。
5. **配置错误要响亮**：用 Schemastery schema 在加载时校验，无效配置直接加载失败并给出明确错误，绝不带病运行。
6. **回调可被回放/热重载**：展示类回调（`output.render`、`presentCall`、`presentResult`）必须是纯函数；插件随时可能被 HMR 卸载重载，不要依赖跨重载的全局状态。

---

## 2. 环境与工具链

- 插件是 **TypeScript 模块**（也接受 JS），运行于 Node.js ESM 环境。
- 核心依赖包（都来自 `@deepseek-ai` 作用域）：
  - `@deepseek-ai/cordis` — 插件框架（context、fiber、事件、注册表）
  - `@deepseek-ai/schemastery` — 配置 schema 校验（Standard Schema 实现）
  - `@deepseek-ai/dsh-tools` — `defineTool` 与工具注册表服务
  - `@deepseek-ai/dsh-llm` — `LlmAdapter`、`StreamChunk`、`GenerateOptions`、`CallId`
  - 各能力 seam 包：`dsh-shell`、`dsh-session`、`dsh-agent`、`dsh-system-prompt`、`dsh-fs`、`dsh-jobs`、`dsh-credentials` 等（完整清单见 `References/08-capability-layering.md`）
- 两个开发入口（任选）：
  - **源码检出**（推荐，教程场景）：克隆 `deepseek-ai/deepseek-harness`，`pnpm install`，用 `pnpm dsh web --patch <你的cordis.yml>` 启动 Web UI，用 `node --import tsx ../../vendor/cordis/bin.js` 跑纯 Cordis 教程示例。
  - **已安装 CLI**：`dsh --profile <name> ...` 启动 profile，`dsh plugin --profile <name> <pnpm args>` 管理插件。

---

## 3. 插件的最小形态（先学会这个）

一个插件就是一个导出 `apply` 函数的模块：

```ts
import type { Context } from '@deepseek-ai/cordis'

export const name = 'my-plugin'   // 可选，仅用于诊断显示

export function apply(ctx: Context) {
  // 在这里注册能力
}
```

通过 `cordis.yml` 或 patch 挂载：

```yaml
- name: './src/my-plugin.ts'        # 相对路径（源码/开发）或 npm 包名（安装后）
  id: my-plugin                     # 稳定标识，loader 按 id 做配置对账
```

### 三种插件形态

1. **函数形态**（默认推荐）：
   ```ts
   export const name = 'greet-tool'
   export const inject = ['tools']
   export function apply(ctx: Context) { /* ... */ }
   ```
2. **对象形态**：`export default { name, inject, apply(ctx) {} }`
3. **类形态**（需要对外提供服务时）：`export default class MyService extends Service { constructor(ctx) { super(ctx, 'myService') } }`

> 在需要提供服务之前一律用函数形态。

---

## 4. 开发一个 Tool（最高频任务）

工具注册到 `ctx.tools`，用 `defineTool` 定义。**模板（可直接照抄）：**

```ts
import type { Context } from '@deepseek-ai/cordis'
import { defineTool } from '@deepseek-ai/dsh-tools'

export const name = 'my-tool'
export const inject = ['tools']

export function apply(ctx: Context) {
  ctx.tools.register(defineTool({
    name: 'my_tool',                                  // 模型看到的工具名（snake_case 惯例）
    description: 'One sentence about what it does.',  // 模型看到的功能描述，要具体、说清何时用
    parameters: {
      path: { type: 'string', required: true, description: 'What the param means' },
      limit: { type: 'number' },                      // 未标 required 即为可选
    },
    output: {
      schema: { type: 'string' },                     // 声明 execute 返回的规范 JSON 值
      render: (_args, value) => [{ type: 'text', text: value }],  // 转为模型可见内容
    },
    async execute(args, exec) {
      // args 已被 schema 校验并推断类型
      // exec.signal 是取消信号，长任务必须响应它
      return `result for ${args.path}`
    },
  }))
}
```

### defineTool 的完整契约（务必遵守）

- **`parameters`**：参数 schema 映射，根是隐式开放对象；每属性可 `required: true`。支持 `string`/`number`/`integer`/`boolean`/`null`/`array`/`object`/`oneOf`；显式 object 节点必须声明 `additionalProperties: true | false`。
- **`output.schema`**：声明 `execute` 返回的规范 JSON 值（对象/数组/标量/null 皆可）。这是给**程序化调用方**（Code Mode 的 `await tools.xxx()`）用的 API，要设计成直接返回句柄与字段；**面向人的解释放 `output.render`**。
- **`execute(args, exec)`**：
  - args 已经过运行时校验，但 schema DSL 表达不了的约束（非空字符串、正数、跨字段）要自己 `throw new Error(...)`。
  - 返回 `output.schema` 声明的规范值。**不要返回内容块**，不要逼调用方从自然语言里解析 id。
  - 遵守 `exec.signal`：信号触发时取消进行中的工作。
  - 基础设施故障（抛异常/无效返回值）→ 结果标记为 `isError`。**成功但结果不理想**（如非零退出码）→ 仍返回规范值，在 render 里解释。
- **`output.render(args, value)`**：纯函数，把规范值转成 `ContentBlock[]`（模型看到的文本）。绝不在此做 I/O、读会话状态。
- **可选 `output.presentationMeta(args, value)`**：从规范值派生可回放的 UI 元数据（纯函数）。
- **可选 `presentCall(args)` / `presentResult(args, result)`**：声明工具在 UI 中的卡片渲染意图（`card: 'generic' | 'terminal' | 'diff' | 'search' | 'web' | 'read'`）。必须**纯函数**（会在实时流和会话回放中运行），不做 I/O。
- **不要**把 `timeoutMs`、`isConcurrencySafe`、`finalizeContent` 等运行时元数据当作模型可见 schema——它们不会泄漏给模型。
- 参数不可变：把 `args` 当只读；注册后不要改 schema 或替换回调。

### 长时间运行的任务（后台任务）

若要支持 `run_in_background`：

```ts
const jobs = ctx.get('jobs')
if (!jobs) throw new Error('background jobs unavailable: load @deepseek-ai/dsh-jobs')
return {
  kind: 'background',
  jobId: jobs.start({
    kind: 'my-work',
    label: args.command,
    ...exec.agent ? { owner: exec.agent } : {},
    run: () => { /* 返回 { cancel, done, readOutput? } */ },
  }),
}
```

要点：发布 jobId 之后用任务自己的取消信号（归 `job_kill` / owner dispose 管），不再用 `exec.signal`；成功输出 schema 要能承载 `{ kind: 'background', jobId }` 这种规范句柄。参考 `References/03-tools.md` 与 `@deepseek-ai/dsh-tool-bash` 实现。

### 工具的执行策略（扩展点，按需用）

| 扩展点 | 模式 | 用途 |
|---|---|---|
| `tools/pre-execute` | waterfall | 允许/拒绝/询问策略（权限门禁）；返回 `{kind:'allow'}` / `{kind:'deny',reason}` / `{kind:'ask'}` |
| `ctx.tools.guard()` | 单调守卫 | 最终拒绝，后续监听器无法撤销（返回 reason 即拒绝） |
| `tools/execute` | waterfall | 包裹分发：超时/重试/指标；可替换 `exec.signal` 但不可移除 |
| `tools/post-execute` | waterfall | 替换内容/值、阻止结果、附加模型上下文 |
| `tools/result` | emit | 只读观测不可变最终结果（日志、审计） |

策略不要内建进工具；把部署策略放进钩子插件（普通 Cordis 插件监听这些事件即可，如权限门禁示例见 `References/11-cookbook.md`）。

---

## 5. 插件配置（Schemastery）

插件导出 `Config`（同名的 TS 接口 + Schemastery schema），Cordis 在 `apply` 前校验并填充默认值：

```ts
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'

export interface Config {
  greeting: string
  maxRetries: number
  verbose?: boolean
}

export const Config: Schema<Config> = Schema.object({
  greeting: Schema.string().default('Hello'),
  maxRetries: Schema.number().default(3),
  verbose: Schema.boolean().default(false),
})

export function apply(ctx: Context, config: Config) {
  // config 一定是完整且经过校验的
}
```

在 `cordis.yml` 中传配置：

```yaml
- name: './src/my-plugin.ts'
  config:
    greeting: 'Hi there'
    maxRetries: 5
```

要点：
- **`Config` 必须是一个 Standard Schema 对象**（用 Schemastery 构建），不能导出普通对象。
- 常用构造：`Schema.string().required()` / `.default(x)`、`Schema.number()`、`Schema.boolean()`、`Schema.array(String)`、`Schema.union(['a','b'])`、`Schema.object({...})` 嵌套。
- 支持 `!!js` 表达式在加载时求值（如 `greeting: !!js process.env.GREETING ?? 'Hello'`）；`!!js` 仅对 `config` 与 `disabled` 字段有效。
- 配置变更会触发 HMR：旧实例卸载（注册自动清理）→ 新实例加载。**不要在插件外部缓存配置**。

---

## 6. 服务与依赖（服务端开发）

### 使用服务（消费方）

```ts
export const inject = ['tools']        // 必需依赖：不满足就不加载
export function apply(ctx: Context) {
  ctx.tools.register(/* ... */)        // apply 时保证已就绪
}
```

可选依赖：不写 `inject`，使用时 `ctx.get('service')` 探测（返回 `undefined` 表示没有提供方）。

### 提供服务（提供方）

用 `Service` 子类（类形态插件）：

```ts
import { Service, type Context } from '@deepseek-ai/cordis'

declare module '@deepseek-ai/cordis' {
  interface Context {
    metrics: MetricsService     // 声明合并：让 ctx.metrics 有类型
  }
}

export default class MetricsService extends Service {
  static inject = ['llm']       // 服务也可以依赖其他服务
  constructor(ctx: Context) {
    super(ctx, 'metrics')       // 'metrics' 即服务名
  }
  record(event: string, value: number) { /* ... */ }
}

export const name = 'metrics'
export function apply(ctx: Context) {
  ctx.plugin(MetricsService)
}
```

低层 API（不常用但要知道）：`ctx.provide(name, value)` 注册服务实现（effect，卸载自动注销）、`ctx.set/get` 读写存储、`ctx.accessor` 定义计算属性、`ctx.mixin` 把服务成员挂到 ctx 上。

### 服务行为语义（理解而非背诵）

- `inject` 不是一次性启动检查：运行期间必需服务消失 → 依赖插件自动 dispose；服务恢复 → 自动重载。这保证消费方永远不会持有对已卸载服务的引用。
- 服务名是**扁平全局命名空间**：`tools`、`llm` 等已被占用；自有服务名要有辨识度前缀（如 `myCap`、`metrics`）。
- **服务隔离**：`cordis.yml` 中用 group + `isolate` 让不同插件组看到同一服务名的不同实例（如两组各自配置不同 timeout 的 `shell` 提供方）。

---

## 7. 事件系统（插件间通信）

### 分发模式（事件名的一部分，必须选对）

| 模式 | 调用 | 语义 |
|---|---|---|
| `emit` | `ctx.emit(name, ...args)` | 同步广播，不等待、不收集返回值 |
| `parallel` | `await ctx.parallel(...)` | 所有监听器并发运行并等待 |
| `serial` | `await ctx.serial(...)` | 按序执行等待，第一个非 null/false/undefined 返回值胜出并停止 |
| `bail` | `ctx.bail(...)` | serial 的同步版 |
| `waterfall` | `await ctx.waterfall(name, ...args, next)` | 环绕中间件；监听器收到 `next`，包装下游返回值 |

**waterfall 铁律：只观察/标注的监听器必须调用 `next()`；不调用 `next()` 直接返回 = 有意短路（否决/拦截）。** 忘记调用 `next()` 会静默吞掉下游默认行为。

### 类型安全的事件

```ts
declare module '@deepseek-ai/cordis' {
  interface Events {
    'my-plugin/ready': (payload: { id: string }) => void
    'my-plugin/check': (input: string) => boolean | undefined
  }
}
```

事件命名约定 `namespace/action`（如 `agent/step`、`tools/result`、`session/event`）。监听器用 `ctx.on()` 注册即自动随插件卸载清理。

### 常用 Harness 事件（开发时经常用到）

- `tools/pre-execute` / `tools/execute` / `tools/post-execute` / `tools/result` — 工具流水线（见上表）
- `agent/*`（`agent/request`、`agent/pre-step`、`agent/session-start`、`agent/turn-stopping` 等）— agent 生命周期与请求构造
- `session/event` — 持久化的会话事件流（`turn/*`、`step/*`、`tool/call`、`tool/result`、`assistant/chunk` 都是这里的 `event.type`，**不是**同名 Cordis 事件）
- `approval/request` — 审批 waterfall
- `system-prompt/assemble` — 系统提示词整体装配（权威返回，监听者有责任保留既有贡献）

完整签名/触发模式见各子系统页面生成的 `cordis-surface` 区块（`References/08-capability-layering.md` 有指引）。

---

## 8. LLM 适配器（接入新模型提供方）

适配器 = 继承 `LlmAdapter`、实现 `stream()` 的类，把 Harness 提供方无关请求转成具体 API 调用并转回 `StreamChunk` 分片。

```ts
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'
import { LlmAdapter, type GenerateOptions, type StreamChunk } from '@deepseek-ai/dsh-llm'

class MyAdapter extends LlmAdapter {
  async *stream(options: GenerateOptions): AsyncIterable<StreamChunk> {
    // 1. options.messages → 提供方格式
    // 2. 调流式 API（必须传 options.signal）
    // 3. 响应 → StreamChunk 序列
  }
}

export const name = 'my-llm-adapter'
export const inject = ['llm']
export const Config = Schema.object({
  apiKey: Schema.string().required(),
  providers: Schema.array(String).required(),
})

export function apply(ctx: Context, config: Config) {
  ctx.llm.registerAdapter(config.providers, new MyAdapter(config.apiKey))
}
```

### StreamChunk 协议（严格遵守）

```ts
async function* chunks(): AsyncIterable<StreamChunk> {
  yield { type: 'block-start', index: 0, blockType: 'text' }
  yield { type: 'text-delta', index: 0, text: 'Hello' }
  yield { type: 'block-end', index: 0, block: { type: 'text', text: 'Hello world' } }
  // 工具调用块：
  yield { type: 'block-start', index: 1, blockType: 'tool-call' }
  yield { type: 'tool-call-delta', index: 1, id: CallId('c1'), name: 'bash', argumentsDelta: '{"command":"ls"}' }
  yield { type: 'block-end', index: 1, block: { type: 'tool-call', id: CallId('c1'), name: 'bash', arguments: '{"command":"ls"}' } }
  yield { type: 'usage', usage: { inputTokens: 100, outputTokens: 50 } }   // 必须在 finish 前
  yield { type: 'finish', reason: { kind: 'stop' } }                        // 必须最后
}
```

规则：每个 `block-start` 必有对应 `block-end`；`index` 从 0 递增；`tool-call` 的 `arguments` 全程是**原始 JSON 字符串**；`finish` 是最后一块；`usage` 在 `finish` 前。

### 错误与元数据

- 传输/协议故障：`throw new LlmError(msg, 'STABLE_CODE')`（带稳定 code），不要依赖普通 `Error` 自动转换。
- 提供方不支持 `GenerateOptions` 中的某个字段：`throw new LlmError(..., 'UNSUPPORTED')`，绝不静默丢弃。
- 每个 HTTP 请求合并 `attributionHeaders()`，并传递 `options.signal`。
- 可选：覆写 `resolveModel()`（返回提供方/模型身份 + 可选 context/reasoning 元数据）与 `listModels()`（公布模型选项）。

完整教程见 `References/05-llm-adapter.md`；参考实现：`packages/llm/llm-deepseek`（OpenAI 兼容 SSE）与 `packages/llm/llm-pi-ai`。

---

## 9. 能力分层（三个角色，可替换能力的设计模式）

当一个能力需要可替换的提供方（如 Bash 执行），拆成三个角色、放入不同包：

1. **Service Definition**（如 `dsh-shell`）：定义 Cordis 服务接口 + Request/Result 类型。`abstract class MyCapService extends Service { super(ctx,'myCap'); abstract execute(req): Promise<res> }`
2. **Service Provider**（如 `dsh-bash-local`）：实现接口。`class MyCapLocal extends MyCapService { ... }`；`apply(ctx){ ctx.plugin(MyCapLocal) }`
3. **Consumer**（如 `dsh-tool-bash`）：把能力暴露为模型工具。`inject: ['tools','myCap']`

**依赖方向**：Provider 依赖 Definition；Consumer 依赖 Definition；Provider 与 Consumer **互不依赖**。更换提供方只改 `cordis.yml` 一行，Definition 与 Consumer 不动。

> **不要预防性拆分**：只有角色需要独立演进才拆包。简单工具插件一个包就够。

---

## 10. 打包与安装（把插件交付给用户）

### 两个概念

- **组合包（bundle）**：附带一个配置层的 npm 包，manifest 声明 `dsh.bundle`。是你编写并分发的东西。
- **profile**：位于 `$DSH_HOME/profiles/<name>` 的可启动组合，manifest 声明 `dsh.profile`（含有序 `bundles` 列表）。是用户启动的东西。

### 打包一个组合包

```
hello-plugin/
├── package.json       # 声明 dsh.bundle
├── cordis.patch.yml   # 层内容
└── index.js           # 插件模块
```

```jsonc
// package.json
{
  "name": "dsh-hello-plugin",
  "version": "0.1.0",
  "type": "module",
  "main": "index.js",
  "files": ["index.js", "cordis.patch.yml"],
  "dsh": { "bundle": { "patch": "./cordis.patch.yml" } }
}
```

```yaml
# cordis.patch.yml —— 与 --patch overlay 相同的格式；按包名引用
- insert:
    - id: hello
      name: dsh-hello-plugin
```

### 安装进 profile

```sh
dsh plugin --profile demo add ./hello-plugin        # 或 github:you/hello-plugin，或 npm 包名
dsh --profile demo --dump-config                    # 先验证配置层
dsh --profile demo                                  # 再启动
dsh plugin --profile demo remove dsh-hello-plugin   # 移除
```

### 配置层顺序（理解覆盖语义）

1. `dsh.profile.bundles` 中各组合包 patch，按列表顺序
2. profile 自己的 `cordis.patch.yml`
3. `$DSH_HOME/cordis.patch.yml`（机器级偏好）
4. 每个 `--patch <path>` overlay（按 argv 顺序）

**后应用者按行胜出，且 patch 会替换目标行整个 `config` 值（不是深合并）**。因此：覆盖别层某行时要重述该行需要的每一个键；优先给出用户大概率保留的默认值，其余交给 schema。

### 从 git 安装的两个坑

- git 安装拉源码不跑 `build`，**作者必须提供自包含的 `prepare` 脚本**。
- pnpm ≥10 默认拒绝 git 依赖的 `prepare`，**用户需在 profile 的 `pnpm-workspace.yaml` 加 `allowBuilds: <pkg>: true`** 并重新 `add`。要诚实告知用户：这等于允许该包在安装时执行代码。
- 不想让用户授权构建 → 发布 npm 或交付 tarball（`pnpm pack`）。

---

## 11. 开发流程（Agent 照着走）

### 阶段 A：侦察（动手前必做）
1. 读目标仓库/项目结构：`cordis.yml`（或 profile 的 `cordis.patch.yml`）、`packages/*/package.json`、现有插件源码。
2. 确认要用的服务存在且知道其 API：查 `ctx.<name>` 类型定义或子系统文档（`References/08-capability-layering.md`）。
3. 确认要监听的事件名与分发模式（`tools/*`、`agent/*`、`session/event` 等）。

### 阶段 B：实现
1. 按第 3-8 节模板写插件：`name` / `inject` / `Config` / `apply(ctx, config)`。
2. 所有副作用走 `ctx.*` API 或 `ctx.effect()`。
3. 所有可调参数进 `Config`（带默认值），无硬编码。
4. 定义完整的 `Config` schema，使错误配置在加载时响亮失败。
5. 工具：定义清晰 `description` 与参数说明、规范的 `output.schema`、纯函数 `output.render`（和可选展示器）。
6. 处理 `exec.signal` 取消；长任务用 `ctx.jobs` 后台化。

### 阶段 C：验证
1. 类型检查与构建通过（如 `pnpm run typecheck && pnpm run build`，在 DSH 仓库内）。
2. 用 `--patch` 或 `dsh plugin add` 加载，用 `--dump-config` 确认配置层。
3. 启动运行，确认：插件日志出现、工具/服务/事件按预期工作。
4. 测试卸载/重载：改配置或源码触发 HMR，确认注册被清理、无泄漏、无残留监听。
5. 测试依赖缺失场景：去掉提供方 → 插件 PENDING 不崩溃；恢复 → 自动加载。
6. 测试错误配置：传非法 config → 明确报错。

### 阶段 D：交付
1. 按第 10 节打包（`dsh.bundle` + patch + 自包含 prepare 脚本，或发布 npm/tarball）。
2. 写包 README：服务 API / 配置 / 事件 / 扩展点 / 设计说明。
3. 遵循仓库测试策略补测试与组装覆盖。

---

## 12. 常见错误与修正（对照自查）

| 错误 | 修正 |
|---|---|
| 手动 `removeListener` / `clearInterval` | 全部改为 `ctx.on` / `ctx.effect`，卸载自动清理 |
| `export const Config = { ... }`（普通对象） | 用 `Schema.object({...})` 构建 Standard Schema |
| 硬编码 timeout/路径/阈值 | 移入 `Config` 字段并给默认值 |
| 在 `output.render` / `presentCall` 里做 I/O、读文件、用时钟 | 保持纯函数；I/O 进 `execute`，持久元数据进 `presentationMeta` |
| 工具 `execute` 返回人类可读文本而不是规范值 | 返回 `output.schema` 声明的规范 JSON 值；文本归 `output.render` |
| waterfall 监听器忘调 `next()` | 观察者必须 `next()`；不调 = 有意短路 |
| 用 `ctx.get()` 探测必需依赖 | 必需依赖写 `inject` |
| 服务名撞车（`ctx.tools`、`ctx.llm` 等） | 自有服务加辨识度前缀 |
| patch 覆盖别层行只写改动的键 | 重述该行全部所需键（整 config 替换语义） |
| 未声明 `inject` 却直接用 `ctx.xxx` | 补 `inject`（或改用 `ctx.get` 做可选探测） |

---

## 13. 参考资料索引（本项目 `References/` 目录）

| 文件 | 内容 |
|---|---|
| `References/01-dsh-architecture.md` | DSH 架构总览：插件模型、CLI、profile/bundle、配置层 |
| `References/02-plugin-basics.md` | 第一个插件、三种形态、inject、effect、生命周期 |
| `References/03-tools.md` | 工具开发完整参考：defineTool、执行流水线、后台任务、UI 卡片 |
| `References/04-config.md` | 插件配置与 Schemastery |
| `References/05-llm-adapter.md` | LLM 适配器完整指南 |
| `References/06-framework-services-events.md` | 服务与依赖、事件系统、生命周期细节 |
| `References/07-publish.md` | 打包、安装、profile、配置层顺序 |
| `References/08-capability-layering.md` | 三种角色能力设计与 seam 目录 |
| `References/09-cordis-primer.md` | Cordis 入门：五个核心概念、分发模式、ctx API |
| `References/10-spatiotemporal.md` | 论文《A Programming Paradigm for Spatiotemporal Composability》解读（[原文](https://github.com/cordiverse/paper/blob/main/paper.pdf)） |
| `References/11-cookbook.md` | 扩展模式：权限门禁、UI 插件、协议桥、功能→机制映射表 |

官方文档入口：https://deepseek-harness.github.io/deepseek-harness/develop/basic/ （中文）与 `/en/develop/basic/`（英文）
源码仓库：https://github.com/deepseek-ai/deepseek-harness
