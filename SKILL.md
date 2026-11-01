---
name: dsh-plugin-dev-skill
description: 指导任何 Agent 正确、高效、符合规范地开发 DeepSeek Harness（DSH）插件。涵盖 Tool（defineTool）、LLM 适配器、服务与依赖、事件系统、配置、打包发布，以及 Cordis 框架的心智模型、代码模板与验证清单。
whenToUse: 当任务涉及为 DeepSeek Harness 编写/修改/调试插件（tool、LLM adapter、服务提供方、钩子、UI、协议桥等），编写或修改 cordis.yml / cordis.patch.yml / dsh.profile / dsh.bundle 配置，使用 dsh plugin 命令，或需要理解 ctx.tools、ctx.llm、ctx.agents、ctx.sessions 等服务与 tools/*、agent/*、session/event 等事件时，加载本技能。
metadata:
  version: 0.7.0
  upstream: https://github.com/green-dalii/dsh-plugin-dev-skill
  sdk-baseline: 0.2.2-alpha.2
---

# DeepSeek Harness Plugin Dev Skill

> 让任何 Agent 都能正确、高效、符合规范地开发 DeepSeek Harness（DSH）插件。
> 本技能是 DSH 插件开发的操作手册：先给出心智模型与铁律，再给出可直接照抄的代码模板与分步流程，最后给出验证清单。深度背景见 `References/` 目录下的精简提炼文档。
>
> ⚠️ **载入本技能后，先执行 §0.1「检查 skill 是否最新」**：不是最新版就先更新，再开始使用本技能。
>
> **SDK 基线**：本文 API 陈述以 `@deepseek-ai/*` **0.2.2-alpha.2**（cordis **4.0.6-alpha.1**）的类型定义实测为准。0.2.0 把过去几处「文档领先于 SDK」的项正式落地了：PTC 运行时 seam 定名 **`ctx.ptcRuntime`**（原 `ctx.codeRuntime`，包 `dsh-ptc-runtime` / 提供方 `dsh-ptc-runtime-node`）、**Plugin Manager**（`plugin_manager`）随发行版交付、E2B 系提供方移除并由 SSH 家族接管远程能力。0.2.1-alpha.1 主要是 Web 体验与若干 bug 修复（**对 tool / LLM / service 插件的公共 API 0 破坏**），并继续清理了上游诊断路径：`@deepseek-ai/dsh-invariants` 与 `<pkg>/invariant` 子路径发布已删除（详见 §12）。0.2.1-alpha.2 ~ alpha.4 是这一脉的稳定小步：**0.2.1-alpha.3 起 `engines.dsh` 优先于 DSH peerDependencies**（`IncompatiblePlugin` / `PluginCompatibility` 的字段由 `peers` 改名为 `requirements`）；**0.2.1-alpha.2 起在 HMR profile 下 `pluginManager.installBundle(spec)` 重装已安装包返回 `already-installed`**（须先 `removeBundle`）；同时新增与 `plugin_manager` 配套的 **`plugin_market`** agent 工具（列索引、按 bundle 名查版本）。
>
> **0.2.1-rc.1 ~ 0.2.2-alpha.2 是一次大重构**（跨越 43 篇上游升级指南，其中 25 篇对插件开发有实质影响），**对 tool / LLM / service 插件的公共 API 破坏**。三处最需要注意的：① **工具执行模式拆成独立 executor 插件**——`dsh-tools` 的 `mode` / `maxParallelSubCalls` 配置字段已删除、`ctx.tools.presentAs()` 已移除，Native/PTC 执行改由 `@deepseek-ai/dsh-tool-executor-native` / `@deepseek-ai/dsh-tool-executor-ptc` 承担；② **工具声明改由「步骤准入」决定**——`ctx.tools.register(def, { when })` 新增条件注册，`system-prompt/assemble` 不再携带工具数组；③ **`agent/request` 事件不再公开**（降级为未声明事件）。其余（session 投影改异步 handle、`purpose` 改声明式、PTC 新增 `script` 格式与 `ABORTED` 取消码、bundle 清单迁包等）见 §12 错误表与 §10。升级 SDK 后请按各 `References/` 文件末尾的官方链接复查。

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
理由很实际：上游有过破坏性改名（`Code Mode` → PTC mode、`CallId` → `ToolCallId`、`ctx.codeRuntime` → `ctx.ptcRuntime`、profile manifest 删除 `patchReload`），用过期版本会写出**编译不过或行为不对**的插件。

1. **读本地版本**：`VERSION` 文件与本 `SKILL.md` 同目录，内容形如 `0.6.0`（frontmatter 的 `metadata.version` 是同值副本）。
   - 若**没有** `VERSION` 文件（例如只拷贝了 `SKILL.md` 的残缺安装），视为**旧版本，直接执行第 4 步更新**。
2. **取远端版本**（一次约 5 字节的 GET，用短超时，不要拖慢主任务）—— 为了抗 `raw.githubusercontent.com` 的 CDN 缓存延迟（曾观测到刚 `git push` 后 5+ 分钟内 `main` 分支 raw URL 仍返回旧文件），**优先读 tag-pinned URL**（tag 不会被新提交覆盖，永远指向同一个发布）：
   ```sh
   # 1) 先问最新 tag（成本几乎为零）
   TAG=$(git ls-remote --tags --sort=-v:refname https://github.com/green-dalii/dsh-plugin-dev-skill.git | awk -F/ '/refs\/tags\/v/ {print $3; exit}')
   # 2) 用 tag 钉住的 raw URL 读 VERSION —— 这一份保证是「最新发布」而非「main 分支的 CDN 缓存」
   curl -fsSL --max-time 8 "https://raw.githubusercontent.com/green-dalii/dsh-plugin-dev-skill/${TAG}/VERSION" | tr -d '[:space:]'
   ```
   把拿到的远端版本记为 `REMOTE`。再读 `main` 分支 raw URL 拿到的版本记为 `MAIN`：如果两者**不一致**（CDN 延迟，main 落后于 tag），**以 tag-pinned 的 `REMOTE` 为准**—— `MAIN` 是「远端最终会稳定到的值」。若 `git ls-remote` 也失败，退而求其次：
   ```sh
   curl -fsSL --max-time 8 https://raw.githubusercontent.com/green-dalii/dsh-plugin-dev-skill/main/VERSION | tr -d '[:space:]'
   ```
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
7. **怀疑基线漂移时**：跑 `bash scripts/verify.sh`（在仓库根目录）做一次完整复核——版本三处一致、SKILL.md frontmatter 合法、官方链接全部 200。CI 也会跑它。

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
| **Fiber（组件实例）** | 每个已加载的插件实例是一个 fiber，有生命周期状态机（cordis 4.0.4 起：`PENDING` → `LOADING` → `ACTIVE` → `UNLOADING` → `DISPOSED`，`apply` 抛错则进入 **`FAILED`**） | `await fiber.dispose()` 卸载；`fiber.update(config, noSave?)` 重启（**返回 `void`，要等完成调 `await fiber.await()`**） |

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

**HMR 提醒**：默认只热重载**配置**；插件模块（代码）变更通常仍需重启进程（要开源码热替换，用 profile patch 改 `dsh-hmr` 行的 `root`，见 `References/07-publish.md`）。

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
  - `exec.schema`（0.2.0 新增）是 PTC 内层调用在**绑定时刻**冻结的工具 schema，永不写入日志。
- **`output.render(args, value)`**：纯函数，把规范值转成 `ContentBlock[]`（模型看到的文本）。绝不在此做 I/O、读会话状态。
- **可选 `output.presentationMeta(args, value)`**：从规范值派生可回放的 UI 元数据（纯函数）。
- **可选 `presentCall(args)` / `presentResult(args, result)`**：声明工具在 UI 中的卡片渲染意图。`presentCall` 可用 `'generic' | 'terminal' | 'diff'`；`presentResult` 额外支持 `'search' | 'web' | 'read'`。必须**纯函数**（会在实时流和会话回放中运行），不做 I/O。
- **定义级运行时元数据与内容变换**：`timeoutMs`（协作式超时预算，由 `@deepseek-ai/dsh-tool-call-timeout-policy` 强制）、`isConcurrencySafe(args)`（**只有精确返回 `true`** 才允许与兄弟调用并行，否则独占并构成排序屏障）、**`projectContent(exec, result)`**（0.2.0 新增：把执行期准备好的文本/图片在 `tools/post-execute` **之前**装进去，可被后续策略覆盖）、**`finalizeContent(exec, result)`**（`tools/post-execute` **之后**的最后一道内容变换，对每个归一化结果恰好一次——**包括**绕过 post-execute 的流水线失败——必须全函数、不抛错）。后两者返回 `ContentBlock[] | undefined`。
- **模型可见字段**：`name` / `description` / `parameters`，以及 0.2.0 新增的 **`deferLoading?: true`**（该工具延迟加载，模型按需激活，而不是每次请求都下发完整声明列表）。上面这些运行时字段与回调**都不会进入模型请求**。语义细节见 `References/03-tools.md` §2。
- 参数不可变：把 `args` 当只读；注册后不要改 schema 或替换回调。

### 条件注册与「步骤准入」（0.2.1-rc.2 起）

**工具能否被调用不再由「谁在 `system-prompt/assemble` 里改数组」决定，而是由注册项上的 `when` 条件决定。** AgentLoop 在每一步开始时解析一次条件，得到该步的 `ResolvedToolSet`，并用它统一驱动工具声明、Native 分派、PTC 绑定与嵌套调用。

```ts
ctx.tools.register(defineTool({ /* ... */ }), {
  when: ({ agent, modelSelection, signal }) => agent.isEnabledFor(modelSelection.model),
})
```

- `when` 可以是同步或异步；返回 `false` → 该工具在这一步**从声明与分派中同时消失**；**抛错 → 整轮以 `TOOL_ACTIVATION_FAILED` 结束**。
- `when` 收到的 `ToolActivationContext` 含 `{ agent, modelSelection, signal }`；`modelSelection` 是本步捕获的 `{ provider, model, reasoningEffort? }`。
- **`system-prompt/assemble` 不再携带工具数组**：它的输入是 sections / contexts / variables（`PromptPresentation`），返回的 `tools` 字段被**忽略**；读 `assembly.tools` 会拿到 `undefined` 并在运行时失败。**想增删工具声明，只能用 `when`。**
- 条件随作用域生效：`ctx.tools.get(name, scope?, toolSet?)` / `ctx.tools.schemas(scope?, toolSet?)` / `ctx.tools.executable(name, scope?, toolSet?)` 都接受本步的 `toolSet`；没有 `toolSet` 时看到的是「注册了什么」，不是「这一步能用什么」。
- 程序化调用条件工具要自己解析并释放：

```ts
const toolSet = await ctx.tools.resolve({ agent, modelSelection, signal })
try {
  await ctx.tools.execute({ calls, toolSet, /* ... */ })
} finally {
  toolSet.dispose()   // 批次 settle 后必须 dispose
}
```

- `exit_plan_mode` 只在 Session **首次进入 plan mode 之后**才被声明；从未进入 plan mode 的 Session 不再列出它。
- 步内热重载（MCP 重连、skill 重载）会替换注册，导致该步尚未开始的调用返回 `UNKNOWN_TOOL`。

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
    ...exec.agent ? { owner: exec.agent.id } : {},   // ⚠️ 0.2.0：owner 是 SessionId，不再是 agent 对象
    output: processSources,                          // 可选：注册表拉取式输出源
    run: (job) => {                                  // ⚠️ 0.2.0：run 接收 JobHandle
      job.append('progress line\n')                  // 也可用 job.updateProgress(line)
      return { cancel: (reason) => { /* ... */ }, done }   // ⚠️ 0.2.0：JobHooks 已无 readOutput
    },
  }),
}
```

要点：发布 jobId 之后用任务自己的取消信号（归 `job_kill` / owner dispose 管），不再用 `exec.signal`；成功输出 schema 要能承载 `{ kind: 'background', jobId }` 这种规范句柄；任务结果用 `JobOutcome.result`（旧名 `output` 已改）。参考 `References/03-tools.md` 与 `@deepseek-ai/dsh-tool-bash` 实现。

### 工具的执行策略（扩展点，按需用）

| 扩展点 | 模式 | 用途 |
|---|---|---|
| `tools/pre-execute` | waterfall | 允许/拒绝/取消/询问策略（权限门禁）；返回 `{kind:'allow'}` / `{kind:'deny', reason, info?}` / `{kind:'cancel'}` / `{kind:'ask', reason?, displayReason?}` |
| `ctx.tools.guard()` | 单调守卫 | 最终拒绝，后续监听器无法撤销（返回 reason 即拒绝） |
| `tools/execute` | waterfall | 包裹分发：超时/重试/指标；可替换 `exec.signal` 但不可移除 |
| `tools/post-execute` | waterfall | 替换内容/值、阻止结果、附加模型上下文 |
| `tools/ptc-dispatch-log` | waterfall | 改写 `run_code` 子分派**持久日志副本**的内容（返回 `ContentBlock[]`；程序本身已收到完整值） |
| `tools/result` | emit | 只读观测不可变最终结果（日志、审计） |
| `tools/change` | emit | 工具集变化通知（不受作用域过滤；影响每个 agent 的下一次装配） |

策略不要内建进工具；把部署策略放进钩子插件（普通 Cordis 插件监听这些事件即可，如权限门禁示例见 `References/11-cookbook.md`）。

### 工具执行：executor 插件（0.2.1-rc.2 起，取代旧的 `mode` 配置）

> ⚠️ **这一段是破坏性变更**：旧写法全部失效。

| 旧写法（0.2.1-alpha.4 及以前） | 现状 |
|---|---|
| `dsh-tools` 行的 `mode: 'native' \| 'ptc' \| 'both'` 配置 | **已删除**，加载时直接拒绝 |
| `dsh-tools` 行的 `maxParallelSubCalls` 配置 | **已删除**，迁到 PTC executor 的配置 |
| `ctx.tools.presentAs('native' \| 'ptc' \| 'both')` | **已移除**（`ctx.tools` 上不再有这个方法） |
| 环境变量 `DSH_TOOLS_MODE` | **不再读取**（Web / headless / SDK 全部继承 native） |
| `dsh-agent-tool-presentation` 选择器 | 仍可用但**已弃用** |

**现在**：`@deepseek-ai/dsh-tools` 只负责**工具注册与 executor 选择**；真正的执行由独立的 executor 插件承担：

- `@deepseek-ai/dsh-tool-executor-native` —— 原生执行
- `@deepseek-ai/dsh-tool-executor-ptc` —— PTC 执行（需要挂 `ctx.ptcRuntime` 提供方）

**部署必须显式挂 executor**：随附 profile 都挂了；**自定义组合必须自己加**。`tool-executor-native` / `tool-executor-ptc` 两行在启动时必须处于启用状态，**配置无效会直接让启动失败**。

```yaml
# 切到 PTC 执行（native 执行不需要 overlay）
- id: tool-executor-native
  disabled: true

- id: tool-executor-ptc
  disabled: false
```

```sh
dsh --profile headless --patch ./ptc.yml "task"
```

自定义 executor 实现 `ToolExecutor` 接口的 `describe(tools)` 与 `execute(input)`（`input` 含原始 `calls`、`signal`、可选 `agent` 与 `log: { turn, step }`；从 `results` 读单次调用结果）。**程序化调用方传原始 `calls` 和 `signal`**，不要自己造结构。

配套的新导出：

- `@deepseek-ai/dsh-tools/pipeline` —— `ToolExecutionPipeline` 与 `executeToolBatch`（完整批次，包括单次调用，都走批次）；自定义调度器可直接调 `prepare` / `dispatch` / `complete`。**工具注册表入口不导出这两个符号。**
- `@deepseek-ai/dsh-tool-testkit` —— 工具 fixture（**开发依赖**，不从注册表导出）。
- `@deepseek-ai/dsh-tool-executor-ptc` —— PTC SDK 渲染器与 `CodeRunFailedError` 从这里导入。
- `@deepseek-ai/dsh-tool-executor-ptc/types` —— 共享 dispatch 事件与 `ptc-mode` message-source 声明；Host 侧策略扩展用 `import type { PtcDispatchLog } from '@deepseek-ai/dsh-tool-executor-ptc'`。

`maxParallelSubCalls` 现在在 PTC executor 配置里；`agent-loop.maxParallelToolCalls`（默认 `10`）仍在原处，**实时编辑只影响下一批**（不再是下一个 tool group）。

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
- HMR 现在由 **YAML 组合**决定（0.2.0 起 profile manifest 的 `patchReload` 字段已删除，残留该键无任何效果）：`dsh-base` 默认挂 `@deepseek-ai/dsh-hmr` 且 `root: []`，故 base 系 profile（含 `web`）**配置热重载默认开、源码模块热替换仍需 opt-in**（用 profile patch 把 `root` 改成 `["."]`）；`headless`/`sdk`/`acp` 显式 `disabled: true`（仅启动时加载），`sdk-minimal` 没有 hmr 行。**0.2.1 起**：开启 dev directory 监听后，HMR 还能在源码变更时刷新**包入口与依赖映射**，并正确重载仍在运行的原入口——配置层以外的二次重启通常不再需要。
- 想让配置出现在 Web「插件配置」页：用 `ctx.settings.installSection(...)`，细节见 `References/04-config.md` §7。
- **`dsh-tools` 行的执行配置字段已被删除**（0.2.1-rc.2 起）：`mode` 与 `maxParallelSubCalls` 在加载时会被**直接拒绝**。执行方式改由 executor 插件行决定，见 §4「工具执行：executor 插件」。
- **配置层的顺序依赖现在是硬要求**（不只是建议）：
  - `@deepseek-ai/dsh-user-approval` **必须排在 `@deepseek-ai/dsh-session-projection` 之后** —— `ApprovalService` 依赖 `sessionProjections`，缺失或未就绪时激活会**失败**（不再退化为回读事件日志）。
  - 工具 executor 行（`tool-executor-native` / `tool-executor-ptc`）**必须启用**，否则启动失败。
  - `@deepseek-ai/dsh-tool-subagent/model-selection-settings`（若需要多模型路由）**必须排在创建 Agent 之前**，并提供 `sessions` 与 `sessionProjections` 服务。

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
| `waterfall` | `await ctx.waterfall(name, ...args, next)` | 环绕中间件；**调用方必须把「最内层延续（默认行为）」作为最后一个实参传入**，分发器取出后为每个**监听器**替换成链式 `next`；返回最外层监听器的返回值 |

**waterfall 铁律：只观察/标注的监听器必须调用 `next()`；不调用 `next()` 直接返回 = 有意短路（否决/拦截）。** 忘记调用 `next()` 会静默吞掉下游默认行为；而**调用方漏传最后一个 `next` 实参**，则会让最后一个真实参数被当作默认行为而抛 `TypeError`（两侧都容易出错，务必区分）。

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
- `agent/request-error`（waterfall，单次请求失败的重试策略）、`agent/pre-step`（waterfall）、`agent/created`（**serial**；0.2.0 起 `agent/session-start` 已删除并合并进它，创建 resolve 前被 await，抛错会失败创建）、`agent/assistant-stream`（emit，进程内实时流分片）、`agent/turn-stopping`（serial，轮次停止边界，异议者用 `agent.steer()` 继续跑）
- `session/event` — 持久化的会话事件流（`turn/*`、`step/*`、`tool/call`、`tool/result`、`assistant/chunk` 都是这里的 `event.type`，**不是**同名 Cordis 事件）；另有 `session/created` / `session/disposed`（emit）、`session/flush`（parallel）
- `approval/request` — 审批 waterfall
- `system-prompt/assemble` — 系统提示词整体装配（作用域过滤；权威返回，监听者有责任保留既有贡献）。**0.2.1-rc.2 起不再携带工具数组**（输入是 sections / contexts / variables；返回的 `tools` 被忽略，读 `assembly.tools` 得到 `undefined`）——工具的增删改用注册项的 `when` 条件，见 §4。
- **0.2.0 事件变动**：删除 `agent/session-start`（并入 `agent/created`）与 `settings/updated`；`agent/created` 由 emit 改 **serial**；新增 `app-boot/config-reload`、`hmr/change`、`hmr/reload`、`plugin-manager/*`、`workspace/session-activity`、`workspace/session-stop`、`deepseek-account/*`、`schedule/changed`、`permission-presets/catalog-changed`、`compaction/summary-error`、`connection/request`、`loader/volatile-update`
- **0.2.1-rc.1 ~ 0.2.2-alpha.2 事件变动**：**`agent/request` 不再是公开事件**（降级为未声明事件，监听它不再可靠）；新增 `llm/models-updated`（emit，模型列表刷新）、`plugin-manager/operation`（parallel）、`plugin-manager/update-state`（emit）、`schedule/resolve-agent`（waterfall）、`forge/providers-changed`（parallel）。`session/attachment` 的载荷由 `{ sessionId, attachmentId }` 改为 `{ sessionId, attachment }`，`attachment` 是含 `attachmentId` / `mediaType` / `bytes` / `width` / `height` 的完整引用。

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

- 传输/协议故障：`throw new LlmError(msg, '<CODE>', { status?, providerRetryAfterMs?, requestId?, offloadImages? })`，不要依赖普通 `Error` 自动转换。`code` 是**自由字符串**（SDK 不提供错误码联合类型），核心导出的规范常量有 `CONTEXT_WINDOW_EXCEEDED`、`QUOTA`、`ACCOUNT_QUOTA`、`EMPTY_RESPONSE`、`INVALID_CREDENTIAL`、`IMAGE_OFFLOAD_REQUIRED`。
- 提供方不支持 `GenerateOptions` 中的某个字段：`throw new LlmError(..., 'UNSUPPORTED_OPTION')`（该 code 是**适配器自有**约定，核心不导出），绝不静默丢弃。
- 每个 HTTP 请求合并 `attributionHeaders()`，并传递 `options.signal`。
- 可选：覆写 `resolveModel()`（返回提供方/模型身份 + 可选 `context`、`reasoning`、`systemPromptUpdate`、`toolUpdate` 与 **`inputModalities`**——未声明图片能力时运行时会主动把图片投影掉）与 `listModels()`（公布模型选项）。
- 可选：覆写 `prepareCall(provider, model, signal?)`，把连接事实绑定到**本次生成**，避免「能力解析」与「派发」之间配置变化导致混用两代配置（动态端点的适配器应覆写它）。
- **`GenerateOptions.purpose` 是声明式的**（0.2.2-alpha.2 起）：`purpose` 的取值类型从 `@deepseek-ai/dsh-llm/types` 导出的可声明合并接口 `LlmRequestPurposeMap` 派生。**共享包不再预先声明固定用途**（`compaction`、`session-title` 等由各自的生产方包声明）。构造辅助请求（摘要、标题等）时：加载生产方声明（`@deepseek-ai/dsh-compaction-basic`、`@deepseek-ai/dsh-session-title-llm`），或在自己的类型入口 `declare module '@deepseek-ai/dsh-llm/types' { interface LlmRequestPurposeMap { 'my-purpose': true } }` 扩充。**未声明的 purpose 无法通过类型检查。**
- **pi-ai 适配器已升到 pi-ai 1.3.0**（0.2.1-rc.2 起）：`kimi-coding` 改用 `openai-completions` 协议（`https://api.kimi.com/coding/v1`），`opencode` / `opencode-go` 端点由 `/zen` 改为 `/inference`；多个 provider 的模型 ID 被移除（`opencode-go` 的 `deepseek-v4-flash`、`openrouter` 的 `anthropic/claude-sonnet-4`、`google-vertex` 的 `gemini-flash-latest` 等，**无自动替代**），过期的 `providers.<provider>.modelOverrides.<id>` 会报缺失目录诊断且新覆盖被拒绝；部分模型的 `contextWindow` / `maxTokens` 下调。自建 provider 或预设引用这些模型 ID 时必须逐个替换。

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
- **profile**：位于 `$DSH_HOME/profiles/<name>` 的可启动组合，manifest 声明 `dsh.profile`（只含有序 `bundles` 列表；**0.2.0 起 `patchReload` 字段已删除**，写了也不生效）。是用户启动的东西。

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
  "dsh": { "bundle": { "patch": "./cordis.patch.yml" } }   // patch 也可给数组：按序作为同一层应用
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
dsh --profile demo --dump-config-schema             # 新增：输出组合条目与 patch 层的 JSON Schema（2020-12）
dsh demo                                            # 简写：等价于 dsh --profile demo
dsh --profile demo                                  # 再启动
dsh plugin --profile demo remove dsh-hello-plugin   # 移除
```

- `add` 后 `dsh.profile.bundles` 会按依赖顺序**重算**；组合包成员变化后**需要重启 profile**；profile / `$DSH_HOME` 的 `cordis.patch.yml` 编辑在 base 系 profile（含 `web`）下**默认热重载**。
- **`dsh plugin` 有三个自管子命令**（不转发给 pnpm）：`version-exemptions`、`allow-version <pkg@version> --dsh-version <exact> --accept-risk`、`revoke-version …`，豁免记在 profile 的 `compatibility.json`。`add`/`install` 具名包会**先做兼容检查**，被拒时会打印确切的 `allow-version` 命令。`--profile` 必填；没有 `build`/`pack`/`publish` 子命令。
- **加载失败不致命**：无法解析、不可读、没声明 `dsh.bundle`、或 DSH peer 不兼容且未豁免的 bundle 会被**跳过**，仍留在 `bundles` 列表里并进 `skippedBundles`，每次启动打印一次；其余 bundle 保持顺序。profile manifest 与用户 patch 的错误仍会让启动失败。
- **HMR profile 下重装已装包返回 `already-installed`**（0.2.1-alpha.2 起）：`dsh plugin --profile demo add <已装包名>` 不再"先重装再 `restart-required`"，而是直接 `application: 'failed'` + `error.code: 'already-installed'`，不会改写任何 profile 文件。要升级或换路径先 `dsh plugin --profile demo remove <name>` 再 `add`。不带 HMR 的 profile（`headless` / `sdk` / `acp`）仍走旧的 `restart-required` 路径。Web 上对 Official 插件的 Update 按钮会自己 remove + install。bundle 自我依赖（如 bundle 自带 plugin management）因此不能再 install over：处理 `ManagementError['code']` 时加一个分支。
- 包只有在声明了 `dsh.bundle` 时才会作为组合包生效；`update` 后才获得声明的包会被自动激活。

### 配置层顺序（理解覆盖语义）

1. `dsh.profile.bundles` 中各组合包 patch，按列表顺序
2. profile 自己的 `cordis.patch.yml`
3. `$DSH_HOME/cordis.patch.yml`（机器级偏好）
4. 每个 `--patch <path>` overlay（按 argv 顺序）

**后应用者按行胜出，且 patch 会替换目标行整个 `config` 值（不是深合并）**。因此：覆盖别层某行时要重述该行需要的每一个键；优先给出用户大概率保留的默认值，其余交给 schema。省略的键回落到**插件 schema 的默认值**，而不是保留上一层写入的值。

⚠️ 副作用：如果你用 `!!js` 从运行时读值（如 `port: !!js ctx.webStartup.port ?? 8080`），用户用**字面量替换整个 `config`** 会把这次运行时读取一起抹掉。

> 另有 launcher 自行追加的一层（用户不可编写，仅供解释）：当环境变量 `DSH_TELEMETRY_DISABLED` 为非空值且组合里存在该行时，追加 `{ id: 'session-telemetry-otel', disabled: true }`。

### 从 git 安装的两个坑

- git 安装拉源码不跑 `build`，**作者必须提供自包含的 `prepare` 脚本**。
- pnpm ≥10 默认拒绝 git 依赖的 `prepare`，**用户需在 profile 的 `pnpm-workspace.yaml` 加 `allowBuilds: <pkg>: true`** 并重新 `add`。要诚实告知用户：这等于允许该包在安装时执行代码。
- 不想让用户授权构建 → 发布 npm，或交付**已构建的** tarball（`pnpm pack`）：tarball 与本地 checkout 安装都**不需要** `allowBuilds`。

### 组合包作者要注意的五件事（0.2.0+，截至 0.2.2-alpha.2）

1. **DSH 版本契约 —— `engines.dsh` 优先于 peerDependencies（0.2.1-alpha.3 起）**：兼容检查现在**先看 `engines.dsh`**，看它一个 range 就决定；DSH 的 `@deepseek-ai/dsh` / `@deepseek-ai/dsh-*` peer 规则仅在**没有 `engines.dsh`** 时才生效。一旦声明了 `engines.dsh`，你必须让它的范围覆盖你支持的所有 DSH 版本（peer 范围不再会"自动补齐"）。`workspace:` 协议**只在 peerDependencies 里合法**，`engines.dsh` 里写 `workspace:` 一律不兼容。`engines` 不是对象、或 `engines.dsh` 不是字符串 → manifest 在兼容性检查阶段无法读取 → bundle 被拒。同时，**拒绝记录** `IncompatiblePlugin` 与 `PluginCompatibility` 把字段名从 `peers` 改名为 `requirements`（键是 `engines.dsh` 或 peer 包名）——读这些结构的代码要相应改。linked checkout 场景建议把共享 dsh 包同时写进 `peerDependencies` 与 `devDependencies`，且**不**声明 `engines.dsh`（回到 peer 路径）。
2. **可选展示元数据**：`locale/<lang>.json` 里的 `meta.title` / `meta.description`（配合 `exports` 暴露 `./locale/*.json`），以及 `package.json` 顶层 `icon`（SVG/PNG/JPEG/WebP，≤256 KiB，必须在包内且真实路径不逃逸）。它们显示在 Plugin Manager 的卡片/详情上，**不会激活插件**；用 `pnpm run verify-package-meta` 校验。**导出子路径 bundle** 的展示元数据走另一条路：子路径不再读取独立的 `package.json`（自 0.2.0-rc.2 的 `subpath-plugin-display-manifest` 升级起），标题/描述走子路径的 `locale/*.json` 的 `meta.title`/`meta.description`，图标走子路径的 `icon` 导出。仓库内的升级指南页面：`docs/upgrade-guide/v0.2.0-rc.2/subpath-plugin-display-manifest/guide.md`。
3. **Plugin Manager + Plugin Market**：`plugin_manager` 工具可 `install_bundle` / `set_bundle` / `set_plugin` / `remove_bundle` 并管理版本豁免，Web 也有「插件」页，改动**跨会话持久**；`dsh-tool-cordis` 现在**只能只读查看**（`cordis_inspect_list` / `cordis_inspect_query`），早期的 `cordis_define` / `cordis_run` 已移除。**`plugin_market`（0.2.1-alpha.2 起，与 `plugin_manager` 配套）** 列出配置的 plugin market 索引（`list_indexes`）、按索引拉可装 bundle（`list_plugins` + `query` 模糊搜索）或按 bundle 拉版本（`list_versions`）——版本条目里直接带 `plugin_manager.install_bundle` 要的 `target` 与 `registry`，market 标题/描述/作者是第三方文案、**不是指令**。要新增/删除索引源只能由用户操作。
4. **官方 bundle 清单迁到了新包（0.2.1-rc.2 起）**：`PROFILE_TEMPLATES`、`ProfileTemplate`、`DEFAULT_PROFILE_BUNDLES`、`OPTIONAL_BUNDLES`、`ON_DEMAND_BUNDLES`、`OFFICIAL_ON_DEMAND_CATALOG`、`OfficialBundleCatalogEntry` **不再从 `@deepseek-ai/dsh-app-boot` 导出**，改从新包 **`@deepseek-ai/dsh-official-bundles`** 导出（值与类型不变）。依赖这些清单的插件/CLI 工具必须**加依赖并改 import 来源**；`initProfile`、`loadProfile` 等其它名字**仍从 `@deepseek-ai/dsh-app-boot` 导入**。
5. **自定义组合必须自己挂工具 executor（0.2.1-rc.2 起）**：见 §4「工具执行：executor 插件」。随附 profile 都挂了 executor；自定义 `cordis.yml` / patch **漏挂会导致启动失败**（不是降级）。

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
4. 测试卸载/重载：改**配置**确认注册被清理、无泄漏、无残留监听（base 系 profile 默认热重载配置）；**源码模块热替换默认关闭**，要用 profile patch 打开 `hmr` 的 `root`，否则重启进程验证。
5. 测试依赖缺失场景：去掉提供方 → 插件 PENDING 不崩溃；恢复 → 自动加载。
6. 测试错误配置：传非法 config → 明确报错。

### 阶段 D：交付
1. 按第 10 节打包（`dsh.bundle` + patch + 自包含 prepare 脚本，或发布 npm/tarball）。
2. 写包 README：服务 API / 配置 / 事件 / 扩展点 / 设计说明。
3. 遵循仓库测试策略补测试与组装覆盖。

### 覆盖范围边界

本技能**专注于**：plugin 模型心智模型、`tool` / `llm` / `service`（含 provider + consumer）/ `event` / `bundle`（含 profile + manifest + Plugin Manager）——这五类能力足以覆盖绝大多数 Agent 插件需求。

本技能**不覆盖**（需要直接查官方仓库的子系统页面）：

- **Host plugin / UI 扩展**（Web 客户端组件、composer 输入区、统计面板装饰器等）：0.2.1 把 `composer-stats` 扩展点拆为 `activity` 与 `usage` 两个独立 ID，覆盖旧 `stats` 整行的插件要更新注册 ID。**0.2.1-rc.2 ~ 0.2.2-alpha.2 期间 UI 层还有一批破坏性改名**（按影响面汇总，逐条细则见上游 `docs/upgrade-guide/`）：右键菜单注入名 `ctx.menus` → `ctx.contextMenus`，类型 `MenuTargetMap` → `ContextMenuTargetMap`（**无兼容别名**），Slot 贡献路径 `sidebar.workspaces.session.menu.item` / `sidebar.right.tab.menu.item` → `contextMenu.content`，菜单项图标 prop `symbol` → `icon?: ReactNode`；`MenuTarget` → `ContextMenuTarget`，注入名 `menuTarget` / `useMenuTarget` → `contextMenuTarget` / `useContextMenuTarget`，动作图标改走 `contextMenu.icon` Slot；图片视图与 `MarkdownDelegate.fileImages` 新增必需的 `fileDrag` 注入成员（新增 `@deepseek-ai/dsh-client-ui-file-drag` 包）；Web 端文件保存改为 `save(source, 'download')`（`canSaveAs` 恒为 `false`，`savedFile` / `reveal` 已移除）；推理 Slot 的 `conversation.chat.reasoning.body` 新增 `rawText`（模型原始输出），原 `text` 改为 Chat 预处理后的展示文本。**自定义 Client composition 还必须补挂 `@deepseek-ai/dsh-client-ui-context-menu` 与 `@deepseek-ai/dsh-client-ui-file-actions` 两行**。详见 `docs/subsystems/` 下对应文档（仅仓库内，未发布到文档站）。
- **Schedule / 自动化任务扩展**：0.2.1 起自动化任务改为 Web 内置能力，`schedule_*` 工具按模式提供（标准、创造、PTC 模式可用；极简模式与子代理不可用），并新增 `subagent_session` 错误码。**0.2.2-alpha.2 起工具名与 API 整体重构**：`schedule_create` / `schedule_list` / `schedule_view` / `schedule_edit` 取代旧工具，`schedule_create` 收 `title` / `prompt` / `rrule` / `target`（不再接受时间选择器），`schedule_edit` 用 `action: "update" | "delete"` 取代 `schedule_update` / `schedule_delete`；原生调用改为 `create({ title, prompt, timing, target? })` 与 `edit(request)`（远端为 `schedule/create`、`schedule/edit`），Session 绑定的 `delete` / `update` 已移除；定时类型改用判别式（`{ kind: "cron", cron }` / `{ kind: "rrule", rrule }`），状态用 `paused` / `ended` 取代 `inactive`。子系统页面：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/schedule 。
- **MCP / SSH / browser-use / computer-use / otel / product-telemetry / boot / voice-input / office-to-pdf** 等 0.2.0 新增的子系统，文档均只存在于上游仓库 `docs/subsystems/`，相关文件内已给链接。
- **Claude Code Mods 兼容层**（0.2.1-alpha.1 引入的实验性 bridge）：仅仓库 `docs/subsystems/claude-code-mods.md`，文档站尚未发布。
- **子代理编排细节**：`@deepseek-ai/dsh-tool-subagent` 的 `modelSelectionSettings` 已改名为 `modelSelection`、新增 `modelDiscovery`（每工具域一个实例，默认 `false`），`/list-models` 导出已移除；`@deepseek-ai/dsh-tool-subagent-control` 合并注册 `send_message` / `interrupt_agent` / `list_agents` 三个工具，`/list-agents` 导出已移除（禁用该行会同时禁掉三个工具）。详见 §10 与上游指南。

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
| 仍在用 `ctx.codeRuntime` / `dsh-code-runtime` | 0.2.0 已改名：`ctx.ptcRuntime` / `dsh-ptc-runtime`（提供方 `dsh-ptc-runtime-node`） |
| 在 profile manifest 里写 `patchReload` | 该字段已删除；HMR 由 YAML 组合里 `dsh-hmr` 行的 `disabled`/`root` 决定 |
| 后台任务写 `owner: exec.agent` 或 `readOutput` | `owner` 要传 `exec.agent.id`；`readOutput` 已移除，改用 `spec.output` / `job.append()`，结果用 `JobOutcome.result` |
| 导入 `@deepseek-ai/dsh-invariants` 或 `<pkg>/invariant` | 0.2.1-alpha.1 已删除：`InvariantRegistry`、`InvariantInstaller`、`InvariantFailure`、`InvariantError` 不再导出；`sdk-minimal` 中的五个 `*-invariant` id 已清理。诊断失败改用自己的通道上报 |
| 声明了 `engines.dsh` 但范围太窄 / 想跟 peer 走 | 0.2.1-alpha.3 起 `engines.dsh` 优先于 DSH peer：声明它一个 range 就决定兼容性，peer 不再补齐；要么放宽范围，要么删掉回到 peer 路径 |
| 在 `engines.dsh` 里写 `workspace:` | 不允许；`workspace:` 只在 peerDependencies 里合法 |
| 读 `IncompatiblePlugin` / `PluginCompatibility` 的 `peers` 字段 | 0.2.1-alpha.3 起改名为 `requirements`（键是 `engines.dsh` 或 peer 包名） |
| HMR profile 下用 `dsh plugin ... add <已装包名>` 想升级 | 0.2.1-alpha.2 起返回 `already-installed`，不改 profile 文件；须先 `remove` 再 `add`。处理 `ManagementError['code']` 时加分支 |
| **在 `dsh-tools` 行写 `mode` / `maxParallelSubCalls`** | 0.2.1-rc.2 起这两个配置字段**已删除**，加载时直接拒绝。执行方式改由 executor 插件行决定（§4） |
| **调用 `ctx.tools.presentAs('native' \| 'ptc' \| 'both')`** | 0.2.1-rc.2 起该方法**已移除**；同一进程内 PTC / native 并存改由挂不同的 executor 插件实现 |
| **在 `system-prompt/assemble` 里增删工具声明 / 读 `assembly.tools`** | 0.2.1-rc.2 起该 waterfall **不携带工具数组**，`assembly.tools` 是 `undefined`（读到就崩）。改用注册项的 `when` 条件（§4） |
| **程序化调用条件工具时不带 `toolSet`** | 0.2.1-rc.2 起模型调用只走该步的准入集合；无 `toolSet` 的调用返回 `UNKNOWN_TOOL`。先 `await ctx.tools.resolve({ agent, modelSelection, signal })`，用完 `toolSet.dispose()` |
| **`when` 条件抛错** | 整轮以 `TOOL_ACTIVATION_FAILED` 结束；条件应返回布尔而不是抛异常 |
| **监听 `agent/request` 事件** | 0.2.1-rc.1 起该事件**不再公开**（降级为未声明事件）；改用 `agent/request-error` 或 `llm/stream` |
| **`ctx.sessionProjections.register(def)` 不 await** | 0.2.1-rc.2 起返回的是 **thenable 的 `Promise<ProjectionHandle<S>>`**（不是原生 Promise，`instanceof Promise` 为 `false`）；必须 await 并持有 handle，状态读取用 `handle.stateOf(session)`；`stateOf(session, key)` 已废弃 |
| **在 `session/created` 监听器里写 Session 或做 Agent 相关工作** | 0.2.1-rc.2 起 `Session.append()` 在实例进入 `SessionStore` 且 `session/created` 同步派发完成前**拒绝写入**；且该期间 `ctx.agents.get(session.id)` 返回 `undefined`。把写操作移到 setup 或 `agent/created`；自建 Session 用 `ctx.sessions.create()` |
| **构造辅助 LLM 请求时用未声明的 `purpose`** | 0.2.2-alpha.2 起 `purpose` 由可声明合并的 `LlmRequestPurposeMap` 派生；未声明的 purpose **类型检查不过**。加载生产方声明包，或 `declare module '@deepseek-ai/dsh-llm/types'` 扩充 |
| **手写 `PtcRuntime.programFormat` 联合类型** | 0.2.1-rc.2 起该类型扩展出 `'script'`；从 `@deepseek-ai/dsh-ptc-runtime` 导入 `PtcProgramFormat`，别手写 |
| **用 `programFormat === 'repl'` 判断是否保留内存** | 0.2.1-rc.2 起改用 `runtime.retainsState`（基类返回 `false`）；保留内存的自定义 provider 必须覆写它并继续实现 `release(owner)` |
| **把 PTC 取消当成 `CODE_RUN_FAILED`** | 0.2.1-rc.3 起**调用方取消**改用 `AbortError` / `ABORTED`（结果内容 `Error: tool call aborted`），原因在 `turn/end` 的 `data.reason.reason`；运行时自身失败（超时/清理）仍是 `CODE_RUN_FAILED` |
| **从 `@deepseek-ai/dsh-app-boot` 导入 `PROFILE_TEMPLATES` 等** | 0.2.1-rc.2 起这些 bundle 清单迁到新包 `@deepseek-ai/dsh-official-bundles`；`initProfile` / `loadProfile` 等仍从 `dsh-app-boot` 导入 |
| **`ctx.webServer.renderIndex(html)` 少传参数** | 0.2.1-rc.2 起必须传 Peer：`renderIndex(html, peer)` / `collectIndexInjections(peer)`；`webserver/index-inject` 事件的第二个参数也是该 Peer |
| **`new HttpFetchProvider(limits, resolveAddresses)`** | 0.2.1-rc.2 起构造函数只接受 `HttpFetchLimits`，`HttpFetchResolver` 不再导出；`web_fetch` 现在**可访问内网与云元数据端点**，需限制就自建 `tools/pre-execute` 策略 |
| **自定义组合没挂工具 executor** | 0.2.1-rc.2 起 executor 行必须启用，否则**启动失败**（§4） |
| **`@deepseek-ai/dsh-user-approval` 排在 `dsh-session-projection` 前面** | 0.2.1-rc.2 起 `ApprovalService` 依赖 `sessionProjections`，缺失时**激活失败**（不再回退到读事件日志）；配置层必须把 projection 排在前面 |
| **读 `dsh-tool-subagent` 的 `modelSelectionSettings`** | 0.2.1-rc.1 起改名为 `modelSelection`；模型发现另需 `modelDiscovery: true`（每工具域一个实例） |
| waterfall 调用方忘传最后一个 `next` 实参 | 调用方传最内层延续：`ctx.waterfall(name, ...args, next)`（与「监听器必须调 `next()`」是两件事） |
| 怀疑 SKILL.md 与官方 DSH 不一致 | 跑 `bash scripts/verify.sh`：版本三处一致 + frontmatter 合法 + 官方链接 200（CI 也会跑） |

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
| `References/10-spatiotemporal.md` | 论文《A Programming Paradigm for Spatiotemporal Composability》解读（[arXiv:2608.25512](https://arxiv.org/abs/2608.25512)） |
| `References/11-cookbook.md` | 扩展模式：权限门禁、UI 插件、协议桥、功能→机制映射表 |

官方文档入口：
- 开发者第一步：https://deepseek-harness.github.io/deepseek-harness/develop/basic/ （中文）/ `/en/develop/basic/`（英文）
- 服务与 seam 全局视图：https://deepseek-harness.github.io/deepseek-harness/reference/capability-seams
- 0.2.0-rc.2 升级指南（含 `remove-runtime-invariants`、`subpath-plugin-display-manifest`、`schedule-bundle-retired`、`account-sign-in-errors`）：仓库内 `docs/upgrade-guide/v0.2.0-rc.2/`（文档站尚未发布索引页）。
- 0.2.1-alpha.2 ~ alpha.4 升级指南（**12 篇**；推荐关注的与插件开发相关的：`plugin-engines-dsh` / `plugin-install-over-installed` / `sdk-minimal-image-compaction` / `stored-credentials-precedence` / `pi-ai-model-discovery`；其余如 Azure route、DeepSeek 账户、Desktop 快捷键、AccountBonusNotification 不影响插件开发）：https://github.com/deepseek-ai/deepseek-harness/tree/master/docs/upgrade-guide （按子目录 `v0.2.1-alpha.{2,3,4}/<name>/guide.md` 打开）。每篇的关键改动已经并入本 SKILL.md §10/§12 与对应 References。
- **0.2.1-rc.1 ~ 0.2.2-alpha.2 升级指南（**45 篇**，本轮基线的主要来源）**：同样在 `docs/upgrade-guide/` 下，按子目录 `v0.2.1-rc.{1,2,3,4}/` 与 `v0.2.2-alpha.2/` 打开。**与插件开发直接相关的 25 篇**：`conditional-tools` / `tool-executor-plugins` / `subagent-control-tools` / `session-projection-handles` / `session-store-writes` / `attachment-read-access` / `llm-request-purpose-declarations` / `schedule-agent-tools` / `schedule-remote-host-tasks` / `ptc-script-format` / `ptc-caller-cancellation` / `web-fetch-private-destinations` / `webserver-index-peer` / `official-bundle-lists` / `approval-projection-dependency` / `independent-session-forks` / `pi-ai-protocol-replay` / `pi-ai-model-catalog` / `context-menu-services` / `context-menu-target` / `file-drag-callbacks` / `web-file-downloads` / `model-listing-refresh` / `reasoning-body-props` / `model-badge-package-removal`。这些的关键改动已经并入本 SKILL.md §4/§5/§7/§8/§10/§11/§12 与对应 References。
- PTC 运行时子系统（自 0.2.1-alpha.1 起从 `code-runtime` 改名）与 Claude Code Mods 兼容层（0.2.1-alpha.1 新增的实验性 bridge，**仅仓库**）：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/ptc-runtime 与 https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/claude-code-mods.md 。
源码仓库：https://github.com/deepseek-ai/deepseek-harness

本技能自身：仓库 https://github.com/green-dalii/dsh-plugin-dev-skill ，版本见同目录 `VERSION` 文件（更新检查流程见 §0.1）。

> 索引与**术语对照表**（上游重命名备忘，如 Code Mode → PTC mode、`CallId` → `ToolCallId`、`ctx.codeRuntime` → `ctx.ptcRuntime`）见 `References/00-INDEX.md`；注意文档站发布的是 `develop/**`、`guide/**`、`reference/**` 与已发布的部分 `reference/subsystems/*`（已确认的有 `ptc-runtime`、`schedule`、`approval` 等），而 `glossary`、`event-producer-consumer`、`defensive-patterns` 以及多数 `subsystems/**` 页面（`deliverables`、`mcp`、`ssh`、`browser-use`、`computer-use`、`otel`、`product-telemetry`、`boot`、`voice-input`、`office-to-pdf` 以及 0.2.1 新增的 `claude-code-mods` 等）**仅存在于仓库**，相关文件内已给出 GitHub 链接。
