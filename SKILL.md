---
name: dsh-plugin-dev-skill
description: 指导任何 Agent 正确、高效、符合规范地开发 DeepSeek Harness（DSH）插件。涵盖 Tool（defineTool）、LLM 适配器、服务与依赖、事件系统、配置、打包发布，以及 Cordis 框架的心智模型、代码模板与验证清单。
whenToUse: 当任务涉及为 DeepSeek Harness 编写/修改/调试插件（tool、LLM adapter、服务提供方、钩子、UI、协议桥等），编写或修改 cordis.yml / cordis.patch.yml / dsh.profile / dsh.bundle 配置，使用 dsh plugin 命令，或需要理解 ctx.tools、ctx.llm、ctx.agents、ctx.sessions 等服务与 tools/*、agent/*、session/event 等事件时，加载本技能。
metadata:
  version: 0.5.0
  upstream: https://github.com/green-dalii/dsh-plugin-dev-skill
  sdk-baseline: 0.1.5-rc.2
---

# DeepSeek Harness Plugin Dev Skill

> 让任何 Agent 都能正确、高效、符合规范地开发 DeepSeek Harness（DSH）插件。
> 本技能是 DSH 插件开发的操作手册：先给出心智模型与铁律，再给出可直接照抄的代码模板与分步流程，最后给出验证清单。深度背景见 `References/` 目录下的精简提炼文档。
>
> ⚠️ **载入本技能后，先执行 §0.1「检查 skill 是否最新」**：不是最新版就先更新，再开始使用本技能。
>
> **SDK 基线**：本文 API 陈述以 `@deepseek-ai/*` **0.1.5-rc.2**（cordis 4.0.2）的类型定义实测为准。上游文档偶尔领先于已发布 SDK（例如 seam 改名 `ctx.codeRuntime` → `ctx.ptcRuntime`、`dsh-experimental-auto-review`、Plugin Manager 等），这类差异在各 `References/` 文件中均已标注；升级 SDK 后请按对应文件末尾的官方链接复查。

---

## 0. 何时使用本技能

当任务涉及以下任意一项时，必须加载本技能：

- 为 DeepSeek Harness 编写、修改或调试**插件**（tool、LLM adapter、服务提供方、钩子、UI、协议桥等）
- 编写或修改 `cordis.yml` / `cordis.patch.yml` / `dsh.profile` / `dsh.bundle` 配置
- 用 `dsh plugin ...` 安装、移除、打包插件
- 理解 DSH 中 `ctx.tools`、`ctx.llm`、`ctx.agents`、`ctx.sessions` 等服务或 `tools/*`、`agent/*`、`session/event` 等事件
- 研究 DSH 的插件模型（Cordis 框架）如何工作

先读本 SKILL.md 全篇，再动手。动手前先读项目里已有的 `cordis.yml` / profile / 相关源码，确认现有约定。

### 0.1 载入后第一件事：检查 skill 是否最新（强制流程）

**本技能会随官方 DSH 演进而更新。每次载入本技能后，先确认自己用的是最新版；若不是最新版，先更新、再开始用它干活。**
理由很实际：上游有过破坏性改名（`Code Mode` → PTC mode、`CallId` → `ToolCallId`），用过期版本会写出**编译不过**的插件。

1. **读本地版本**：`VERSION` 文件与本 `SKILL.md` 同目录，内容形如 `0.5.0`（frontmatter 的 `metadata.version` 是同值副本）。
   - 若**没有** `VERSION` 文件（例如只拷贝了 `SKILL.md` 的残缺安装），视为**旧版本，直接执行第 4 步更新**。
2. **取远端版本**（一次约 5 字节的 GET，用短超时，不要拖慢主任务）：
   ```sh
   curl -fsSL --max-time 8 https://raw.githubusercontent.com/green-dalii/dsh-plugin-dev-skill/main/VERSION | tr -d '[:space:]'
   ```
   若上一步失败，退而求其次可用 `git ls-remote --tags https://github.com/green-dalii/dsh-plugin-dev-skill | tail -1`。
3. **比较（语义化版本）**：
   - 远端 **高于** 本地 → 执行第 4 步，更新完再继续。
   - 两端**相同** → 直接用。
   - 远端 **低于** 本地 → 说明本地是开发中的更新版，**不要降级**，直接用。
4. **更新到最新版**，按安装形态二选一：
   - **符号链接 / git 检出**（推荐形态）：
     ```sh
     cd "$(readlink -f <本 SKILL.md 所在目录>)" && git pull --ff-only
     ```
     若该目录不是 git 仓库（纯拷贝安装），改用下一条。
   - **普通拷贝**：
     ```sh
     git clone --depth 1 https://github.com/green-dalii/dsh-plugin-dev-skill /tmp/dsh-plugin-dev-skill-new
     rsync -a --delete --exclude .git /tmp/dsh-plugin-dev-skill-new/ <本 SKILL.md 所在目录>/
     ```
   更新后**重新读取 `SKILL.md` 与本次要用到的 `References/`**——内容可能已变（尤其是 API、术语与包名）。
5. **无法联网 / 检查失败时**：不要卡住，也不要假装检查过。明确说一句「未能检查 skill 更新（原因）」，然后基于当前本地版本继续工作，并在需要新 API 时提示用户可能存在版本差异。
6. **同一会话内**：已成功比较过且远端版本未变时，可以跳过重复检查（不必每次工具调用都发请求）；但**每次载入技能都要检查**。

> 检查成本是一个几字节的 GET，而用过期技能写出编译不过或不符合规范的插件，代价要高得多。

---

## 1. 心智模型：DSH 是构建在 Cordis 之上的插件化系统

一句话概括：**DeepSeek Harness 是一个 Agent Harness SDK，其中每一项能力——工具、LLM 适配器、文件访问、agent loop 本身——都是一个插件（component），挂载到一个共享的上下文（context）上。**

**没有特权内核**：DSH 没有「核心源码」可供打补丁——扩展方式是挂载插件，而不是修改循环。工具（`dsh-tools`）、LLM 运行时（`dsh-llm`）、文件系统（`dsh-fs`）、沙箱、持久化，乃至 **agent loop 本身**都是可替换的插件；换掉某个能力通常只是改 `cordis.yml` 里的提供方。

随发行版交付的可启动 profile：`web`、`headless`、`sdk`、`sdk-minimal`、`acp`（`desktop` 被 CLI 保留但不直接启动）。用户自有 profile 位于 `$DSH_HOME/profiles/<name>`。

**三个事件域**（动手前第一个决定就是选对事件域）：① **会话事件**——`session/event` 中持久化的 `turn/*`、`step/*`、`tool/call`、`tool/result`；② **agent 事件**——`agent/*`，围绕一次 agent 生命周期与步骤边界；③ **能力事件**——`tools/*`、`llm/*`、`fs/*` 等子系统各自的扩展点。术语：**步骤（step）= 一次模型请求及其工具调用**；**轮次（turn）= 0..n 个步骤**，以「没有待执行工具调用」结束。

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
  - `@deepseek-ai/dsh-llm` — `LlmAdapter`、`StreamChunk`、`GenerateOptions`、`ToolCallId`（注意：旧名 `CallId` 已废弃，SDK 不再导出）
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
3. **类形态**（需要对外提供服务时）：`export default class MyService extends Service { static inject = [...]; constructor(ctx) { super(ctx, 'myService') } }`

三种形态共享同一组静态元数据：`name`、`Config`、`inject`、`provide`、`intercept`；类形态用 `static inject` / `static provide`。

**带配置的形态**：`export function apply(ctx: Context, config: Config)` —— 第二个参数是校验后（已填默认值）的配置对象，见 §5。

> 在需要提供服务之前一律用函数形态。

**加载失败语义**：`Config` 校验失败时插件以 `ValidationError` 停在 `FAILED`，`apply` 永不执行——所以「配置错误要响亮」是免费的，前提是你真的声明了 schema。

**HMR 提醒**：默认只热重载**配置**；插件模块（代码）变更通常仍需重启进程（profile 层的 `patchReload` 可调整，见 `References/07-publish.md`）。

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

- **`parameters`**：参数 schema 映射，根是隐式开放对象；每属性用 `required: true` 标注必填（**只能写 `true` 或省略**——写 `required: false` 会类型报错）。支持 `string`/`number`/`integer`/`boolean`/`null`/`array`/`object`/`json`（无约束的任意 JSON 值）/`oneOf`（至少 2 个分支）。
- **嵌套 object 节点**：写 `{ type: 'object', properties: { ... }, additionalProperties: false }`——`additionalProperties` **必须显式声明**（否则会拿到意外的 JSON Schema 默认开放语义）；并且**没有 `required: [...]` 数组**，必填同样靠每个属性自己的 `required: true`。
- **`output.schema`**：声明 `execute` 返回的规范 JSON 值（对象/数组/标量/null 皆可）。这是给**程序化调用方**（PTC mode 的 `await tools.xxx()`）用的 API，要设计成直接返回句柄与字段；**面向人的解释放 `output.render`**。
- **`execute(args, exec)`**：
  - args 已经过运行时校验，但 schema DSL 表达不了的约束（非空字符串、正数、跨字段）要自己 `throw new Error(...)`。
  - 返回 `output.schema` 声明的规范值。**不要返回内容块**，不要逼调用方从自然语言里解析 id。
  - 遵守 `exec.signal`：信号触发时取消进行中的工作。
  - 基础设施故障（抛异常/无效返回值）→ 结果标记为 `isError`。**成功但结果不理想**（如非零退出码）→ 仍返回规范值，在 render 里解释。
  - 组合工具可额外用 `exec.deferContext(msg)` 把上下文延迟到本工具 `tool/result` 之后再交给循环（按调用序），或用 `exec.concludeTurn()` 标记本成功结果为当前轮次终点。
- **`output.render(args, value)`**：纯函数，把规范值转成 `ContentBlock[]`（模型看到的文本）。绝不在此做 I/O、读会话状态。
- **可选 `output.presentationMeta(args, value)`**：从规范值派生可回放的 UI 元数据（纯函数）。
- **可选 `presentCall(args)` / `presentResult(args, result)`**：声明工具在 UI 中的卡片渲染意图。`presentCall` 可用 `'generic' | 'terminal' | 'diff'`；`presentResult` 额外支持 `'search' | 'web' | 'read'`。必须**纯函数**（会在实时流和会话回放中运行），不做 I/O。
- **定义级运行时元数据**（都不进入模型请求，`schemas()` 只白名单 name/description/parameters）：`timeoutMs`（协作式超时预算，由 `@deepseek-ai/dsh-tool-call-timeout-policy` 强制）、`isConcurrencySafe(args)`（**只有精确返回 `true`** 才允许与兄弟调用并行，否则独占并构成排序屏障）、`finalizeContent(exec, result)`（对每个归一化结果恰好一次的最终内容变换，必须全函数、不抛错）。语义细节见 `References/03-tools.md` §2。
- 参数不可变：把 `args` 当只读；注册后不要改 schema 或替换回调。

### 长时间运行的任务（后台任务）

若要支持 `run_in_background`：

```ts
const jobs = ctx.get('jobs')
if (!jobs) throw new Error('background jobs unavailable: load @deepseek-ai/dsh-jobs and @deepseek-ai/dsh-tool-jobs')
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
| `tools/ptc-dispatch-log` | waterfall | 改写 `run_code` 子分派**持久日志副本**的内容（返回 `ContentBlock[]`；程序本身已收到完整值） |
| `tools/result` | emit | 只读观测不可变最终结果（日志、审计） |
| `tools/change` | emit | 工具集变化通知（不受作用域过滤；影响每个 agent 的下一次装配） |

策略不要内建进工具；把部署策略放进钩子插件（普通 Cordis 插件监听这些事件即可，如权限门禁示例见 `References/11-cookbook.md`）。

需要**同一进程内让不同 agent 用不同呈现方式**（PTC 与 native 并存）时，用 `ctx.tools.presentAs('native' | 'ptc' | 'both')` 按作用域声明，就近作用域胜出；进程级默认值走 `dsh-tools` 的 `mode` 配置。

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
- **`Config` 必须是一个 Standard Schema 对象**（用 Schemastery 构建），不能导出普通对象——Cordis 只接受 Standard Schema 接口。
- **校验必须是同步的**：schema 返回 Promise 会让 Cordis 抛 `TypeError: Async config validation is not supported`。`Config` 也可以整体省略（等于无校验、无默认值、配置原样透传）。
- 校验失败 → fiber 停在 `FAILED`，`apply` 不执行，CLI 非零退出。错误信息形如 `$.targets expected array but got not-an-array (at targets)`。
- 常用构造：`Schema.string().required()` / `.default(x)`、`Schema.number()`、`Schema.boolean()`、`Schema.array(String)`、`Schema.union(['a','b'])`、`Schema.object({...})` 嵌套。
- 支持 `!!js` 表达式在加载时求值（如 `greeting: !!js process.env.GREETING ?? 'Hello'`），在 `config` 内**递归生效**；`!!js` 仅对 `config` 与 `disabled` 字段有效。注意 `--dump-config` 原样打印 `!!js` 而不求值。
- 配置变更触发旧实例卸载（注册是 effect，自动清理）→ 新实例加载。**不要在插件外部缓存配置**。
- HMR 有前提：配置热重载靠 profile 的 `patchReload: live`（自定义 profile 默认值，由 launcher 的只监视 patch 文件的回退承担）；**源码模块热替换是按 profile 显式开启的**（base 的 `hmr` 行默认 `disabled: true`）。
- 想让配置出现在 Web「插件配置」页：用 `ctx.settings.installSection(...)`，细节见 `References/04-config.md` §7。

---

## 6. 服务与依赖（服务端开发）

### 使用服务（消费方）

```ts
export const inject = ['tools']        // 必需依赖：不满足就不加载
export function apply(ctx: Context) {
  ctx.tools.register(/* ... */)        // apply 时保证已就绪
}
```

`inject` 也支持对象形式（服务名 → 拦截配置）。**可选依赖**：不写 `inject`，使用时 `ctx.get('service')` 探测（`undefined` 表示没有可用提供方；`strict` 默认 `true`，只返回提供方 fiber 处于 `ACTIVE` 的实现）。

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

**轻量替代（无需写类）**：`ctx.provide(name, value, check?)` 直接注册服务实现（effect，卸载自动注销）。第三个参数 `check` 是可用性谓词，依赖方据此判断是否就绪——需要「已注册但暂时不可用」的中间态时用它。

其他低层 API：`ctx.set/get` 读写存储（对未提供的名字 `set` 会抛错）、`ctx.accessor` 定义计算属性、`ctx.mixin` 把服务成员挂到 ctx 上。

### 服务行为语义（理解而非背诵）

- `inject` 不是一次性启动检查：运行期间必需服务消失 → 依赖插件自动 dispose；服务恢复 → 自动重载。这保证消费方永远不会持有对已卸载服务的引用。
- 服务名共用**扁平命名空间**：`tools`、`llm` 等已被占用，自有服务名要加辨识度前缀（如 `myCap`、`metrics`）。**服务名与公开方法以子系统页面生成的 `cordis-surface` 区块和 TS 接口为准，不要自己维护静态清单。**
- **服务隔离**：`cordis.yml` 中用 group + `isolate` 让不同插件组看到同一服务名的不同实例（如两组各自配置不同 timeout 的 `shell` 提供方）；隔离后同名服务按 scope 分别解析。

---

## 7. 事件系统（插件间通信）

### 分发模式（事件名的一部分，必须选对）

| 模式 | 调用 | 语义 |
|---|---|---|
| `emit` | `ctx.emit(name, ...args)` | 同步广播，不等待、不收集返回值 |
| `parallel` | `await ctx.parallel(name, ...args)` | 所有监听器并发运行并等待（返回 `Promise<void>`） |
| `serial` | `await ctx.serial(name, ...args)` | 按序 await，首个非 null/false/undefined 返回值胜出并终止后续 |
| `bail` | `ctx.bail(name, ...args)` | serial 的**同步**版，返回首个 bail 值（不是 Promise） |
| `waterfall` | `await ctx.waterfall(name, ...args)` | 环绕中间件；**监听器**额外收到内置 `next`，包装下游返回值；返回最外层监听器的返回值 |

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

事件命名约定 `namespace/action`（如 `agent/step`、`tools/result`、`session/event`）。监听器用 `ctx.on()` 注册即自动随插件卸载清理（返回 disposer）；`ctx.once()` 只触发一次；选项支持 `{ prepend: true }`（插到现有监听器之前）与 `{ global: true }`（跳过作用域过滤）。

### 作用域过滤分发（最容易踩的坑）

Harness 中「关于某个 agent 的活动」的事件（`agent/*`、`tools/*`、`session/*`、`system-prompt/assemble`）以该 agent 的 **scope carrier** 作为 `thisArg` 分发，监听器按注册上下文的作用域标签过滤：

- 事件签名写作 `(this: Scoped<Agent>, payload)`；分发方传 carrier（`ctx.emit(scopeTarget(agent, agent), 'agent/status', payload)`）。
- 无标签监听器（普通 `ctx.on`）收到全部事件；带标签监听器（在 `agent.ctx` 上注册）只收到**本 scope 及其祖先链**的事件——事件向上流动，绝不向下。
- 注册表主体事件（如 `tools/change`）**有意不过滤**：全局变化对所有 agent 的下一次装配都成立。
- 关键区别：通过 `agent.ctx` 注册只决定 **effect 的作用域归属**；分发是否过滤始终取决于分发方是否传 carrier。

### 自己发事件时（生产方契约）

- 命名 + 在声明处标 `@mode`，只按声明的模式分发（类型系统强制方法名）。
- **隔离监听器异常**：一个抛错的订阅者不得 reject 分发 promise，也不得饿死后面的监听器——分发循环用 try/catch 包裹并记录。
- payload 视为只读且可无损 JSON 序列化；`emit` / `bail` 是同步的，不要在其中做异步工作。

### 常用 Harness 事件（开发时经常用到）

- `tools/pre-execute` / `tools/execute` / `tools/post-execute` / `tools/ptc-dispatch-log` — waterfall；`tools/result` / `tools/change` — emit（工具流水线见上表）
- `agent/request`（waterfall，替换冻结的模型调用配置）、`agent/request-error`（waterfall，单次请求失败的重试策略）、`agent/pre-step`（waterfall）、`agent/session-start`（emit）、`agent/assistant-stream`（emit，进程内实时流分片）、`agent/turn-stopping`（serial，轮次停止边界，异议者用 `agent.steer()` 继续跑）
- `session/event` — 持久化的会话事件流（`turn/*`、`step/*`、`tool/call`、`tool/result`、`assistant/chunk` 都是这里的 `event.type`，**不是**同名 Cordis 事件）；另有 `session/created` / `session/disposed`（emit）、`session/flush`（parallel）
- `approval/request` — 审批 waterfall
- `system-prompt/assemble` — 系统提示词整体装配（作用域过滤；权威返回，监听者有责任保留既有贡献）

完整签名与分发模式见各子系统页面生成的 `cordis-surface` 区块（`References/08-capability-layering.md` 有指引）；**谁派发、谁监听**查官方 `event-producer-consumer` 矩阵（该页未发布到文档站，链接见 `References/06-framework-services-events.md`）。

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
import { ToolCallId, type StreamChunk } from '@deepseek-ai/dsh-llm'

async function* chunks(): AsyncIterable<StreamChunk> {
  yield { type: 'block-start', index: 0, blockType: 'text' }
  yield { type: 'text-delta', index: 0, text: 'Hello' }
  yield { type: 'block-end', index: 0, block: { type: 'text', text: 'Hello world' } }
  // 工具调用块：
  yield { type: 'block-start', index: 1, blockType: 'tool-call' }
  yield { type: 'tool-call-delta', index: 1, id: ToolCallId('c1'), name: 'bash', argumentsDelta: '{"command":"ls"}' }
  yield { type: 'block-end', index: 1, block: { type: 'tool-call', id: ToolCallId('c1'), name: 'bash', arguments: '{"command":"ls"}' } }
  yield { type: 'usage', usage: { inputTokens: 100, outputTokens: 50 } }   // 必须在 finish 前
  yield { type: 'finish', reason: { kind: 'stop' } }                        // 必须最后
}
```

规则：每个 `block-start` 必有对应 `block-end`；`index` 从 0 递增；`tool-call` 的 `arguments` 全程是**原始 JSON 字符串**；`finish` 是最后一块；`usage` 在 `finish` 前。

### 错误与元数据

- 传输/协议故障：`throw new LlmError(msg, 'STABLE_CODE')`（带稳定 code），不要依赖普通 `Error` 自动转换。
- 提供方不支持 `GenerateOptions` 中的某个字段：`throw new LlmError(..., 'UNSUPPORTED_OPTION')`，绝不静默丢弃。
- 每个 HTTP 请求合并 `attributionHeaders()`，并传递 `options.signal`。
- 可选：覆写 `resolveModel()`（返回提供方/模型身份 + 可选 context/reasoning 元数据）与 `listModels()`（公布模型选项）。

完整教程见 `References/05-llm-adapter.md`；参考实现：`packages/llm/llm-deepseek`（OpenAI 兼容 SSE）与 `packages/llm/llm-pi-ai`。

---

## 9. 能力分层（三个角色，可替换能力的设计模式）

当一个能力需要可替换的提供方（如 Bash 执行），拆成三个角色、放入不同包：

1. **Service Definition**（如 `dsh-shell`）：定义 Cordis 服务接口 + Request/Result 类型。`abstract class MyCapService extends Service { super(ctx,'myCap'); abstract execute(req): Promise<res> }`

   > **硬约束**：Definition **必须是一个 Cordis `Service`**（抽象类或具体注册表），**绝不能是 TypeScript `interface`**——接口在运行时不存在，无法参与服务解析。术语「seam」指 Definition + Provider + Consumer 这**三个角色的整体**，不是单指接口。

2. **Service Provider**（如 `dsh-bash-local`）：实现接口。`class MyCapLocal extends MyCapService { ... }`；`apply(ctx){ ctx.plugin(MyCapLocal) }`
3. **Consumer**（如 `dsh-tool-bash`）：把能力暴露为模型工具。`inject: ['tools','myCap']`

**依赖方向**：Provider 依赖 Definition；Consumer 依赖 Definition；Provider 与 Consumer **互不依赖**。更换提供方只改 `cordis.yml` 一行，Definition 与 Consumer 不动。

> **先看有没有现成的扩展点**：只想附加策略或适配器时**不要新增 seam**——优先挂已有的事件/钩子（见 §7 与 `References/11-cookbook.md`）。完整 seam 目录见 `References/08-capability-layering.md`。

> **不要预防性拆分**：只有角色需要独立演进才拆包。简单工具插件一个包就够。

---

## 10. 打包与安装（把插件交付给用户）

### 两个概念

- **组合包（bundle）**：附带一个配置层的 npm 包，manifest 声明 `dsh.bundle`。是你编写并分发的东西。
- **profile**：位于 `$DSH_HOME/profiles/<name>` 的可启动组合，manifest 声明 `dsh.profile`（含有序 `bundles` 列表，可选 `patchReload: 'live' | 'startup'`，默认 `live`）。是用户启动的东西。

**不要手写 profile manifest**：`web` / `headless` / `sdk` / `sdk-minimal` / `acp` 首次使用时自动从随附模板初始化。要派生自定义 profile：

```sh
dsh --profile demo --from-default-profile web    # 从随附模板派生（不复制依赖与 patch）
```

目标名不能是随附模板名，也不能用保留名 `desktop`。

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
dsh plugin --profile demo add .                     # 相对 spec 按调用目录锚定 → 装当前 checkout
dsh --profile demo --dump-config                    # 先验证完整配置层（含 --patch）
dsh --profile demo --dump-default-config            # 只看组合包各层（不能与 --patch 同用）
dsh --profile demo                                  # 再启动
dsh plugin --profile demo remove dsh-hello-plugin   # 移除
```

- `add` 后 `dsh.profile.bundles` 会按依赖顺序**重算**；组合包成员变化后**需要重启 profile**；profile / `$DSH_HOME` 的 `cordis.patch.yml` 编辑在 `patchReload: live` 时热重载。
- 包只有在声明了 `dsh.bundle` 时才会作为组合包生效；`update` 后才获得声明的包会被自动激活。

### 配置层顺序（理解覆盖语义）

1. `dsh.profile.bundles` 中各组合包 patch，按列表顺序
2. profile 自己的 `cordis.patch.yml`
3. `$DSH_HOME/cordis.patch.yml`（机器级偏好）
4. 每个 `--patch <path>` overlay（按 argv 顺序）

**后应用者按行胜出，且 patch 会替换目标行整个 `config` 值（不是深合并）**。因此：覆盖别层某行时要重述该行需要的每一个键；优先给出用户大概率保留的默认值，其余交给 schema。省略的键回落到**插件 schema 的默认值**，而不是保留上一层写入的值。

⚠️ 副作用：如果你用 `!!js` 从运行时读值（如 `port: !!js ctx.webStartup.port ?? 8080`），用户用**字面量替换整个 `config`** 会把这次运行时读取一起抹掉。

### 从 git 安装的两个坑

- git 安装拉源码不跑 `build`，**作者必须提供自包含的 `prepare` 脚本**。
- pnpm ≥10 默认拒绝 git 依赖的 `prepare`，**用户需在 profile 的 `pnpm-workspace.yaml` 加 `allowBuilds: <pkg>: true`** 并重新 `add`。要诚实告知用户：这等于允许该包在安装时执行代码。
- 不想让用户授权构建 → 发布 npm，或交付**已构建的** tarball（`pnpm pack`）：tarball 与本地 checkout 安装都**不需要** `allowBuilds`。

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
4. 测试卸载/重载：改**配置**确认注册被清理、无泄漏、无残留监听（`patchReload: live` 时热重载，自定义 profile 默认生效）；**源码模块热替换需按 profile 显式启用**，否则重启进程验证。
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

本技能自身：仓库 https://github.com/green-dalii/dsh-plugin-dev-skill ，版本见同目录 `VERSION` 文件（更新检查流程见 §0.1）。

> 索引与**术语对照表**（上游重命名备忘，如 Code Mode → PTC mode、`CallId` → `ToolCallId`）见 `References/00-INDEX.md`；注意文档站只发布 `develop/**`、`reference/**` 与 `guide/quickstart`，`architecture`、`glossary`、`event-producer-consumer` 等仅存在于仓库中（相关文件内已给出 GitHub 链接）。
