# 08 · 能力分层设计（三个角色）与能力 Seam 目录

> 精简提炼自 develop/practice/（能力的三层拆分）、reference/capability-seams。

## 1. 概念：Service Definition / Provider / Consumer

当一项能力足够通用、需要支持可替换的提供方时（如 Bash 执行），harness 区分三种角色：

| 角色 | 职责 | 例子（Bash） |
|---|---|---|
| **Service Definition** | 定义 Cordis 服务接口 + Request/Result 类型 | `dsh-shell` |
| **Service Provider** | 实现该接口（某机制/环境/厂商） | `dsh-bash-local`（本地执行） |
| **Consumer** | 把能力暴露为模型可调用的工具 | `dsh-tool-bash` |

```
┌─────────────┐    ┌──────────────────┐    ┌──────────────┐
│ dsh-shell    │───▶│ dsh-bash-local   │    │ dsh-tool-bash│
│ (definition) │    │ (provider)       │    │ (consumer)   │
└─────────────┘    └──────────────────┘    └──────────────┘
       ▲                                         │
       └───────────── inject: ['shell'] ─────────┘
```

- **依赖方向**：Provider 依赖 Definition；Consumer 依赖 Definition；Provider 与 Consumer **互不依赖**。
- 角色需要独立演进或替换时拆到不同包；否则一个包可承担多角色。**完整能力 = 整个 seam，任何单一角色都不是 seam。**

## 2. 拆分的好处

1. **提供方可替换**：同一 Service Definition 可有多个提供方（`dsh-bash-local`、`dsh-bash-sandbox`、`dsh-pwsh-local`…），`cordis.yml` 换一行即可，Definition 和 Consumer 不动。
2. **独立演进**：Definition 稳定；Provider 可独立优化性能/安全；Consumer 可调整向模型呈现的方式。
3. **依赖解耦**：换提供方不会碰 Consumer。

## 3. 三步实现（以自定义能力 myCap 为例）

### 第一步：Service Definition（定义包）

```ts
// packages/my-cap/my-cap/src/index.ts
import { Service, type Context } from '@deepseek-ai/cordis'

declare module '@deepseek-ai/cordis' {
  interface Context { myCap: MyCapService }
}

export abstract class MyCapService extends Service {
  constructor(ctx: Context) { super(ctx, 'myCap') }
  abstract execute(request: MyCapRequest): Promise<MyCapResult>
}

export interface MyCapRequest { input: string }
export interface MyCapResult { output: string }
```

### 第二步：Service Provider（实现包）

```ts
// packages/my-cap/my-cap-local/src/index.ts
import type { Context } from '@deepseek-ai/cordis'
import { MyCapService, type MyCapRequest, type MyCapResult } from '@deepseek-ai/dsh-my-cap'

class MyCapLocal extends MyCapService {
  async execute(request: MyCapRequest): Promise<MyCapResult> {
    return { output: request.input.toUpperCase() }
  }
}

export const name = 'my-cap-local'
export function apply(ctx: Context) { ctx.plugin(MyCapLocal) }
```

### 第三步：Consumer（工具包）

```ts
// packages/my-cap/tool-my-cap/src/index.ts
import type { Context } from '@deepseek-ai/cordis'
import { defineTool } from '@deepseek-ai/dsh-tools'

export const name = 'tool-my-cap'
export const inject = ['tools', 'myCap']

export function apply(ctx: Context) {
  ctx.tools.register(defineTool({
    name: 'my_cap',
    description: 'Execute my capability.',
    parameters: { input: { type: 'string', required: true } },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: value }],
    },
    async execute(args) {
      const result = await ctx.myCap.execute({ input: args.input })
      return result.output
    },
  }))
}
```

### 组合

```yaml
- name: '@deepseek-ai/dsh-my-cap-local'
- name: '@deepseek-ai/dsh-tool-my-cap'
```

## 4. 设计要点

- **不要预防性拆分**：只有角色需要独立演进才拆包；简单工具插件无需拆分。
- **Service Definition 拥有 Request/Result 类型**：Provider 和 Consumer 只依赖 Definition 包。
- **显式优于隐式**：实现应通过显式 `resolve(request): Spec` 步骤处理默认值，而不是在 `run()` 里藏 `?? default`。
- 服务命名：单数 `ctx` key 用于 engine/runtime/policy/controller/resolver/store；复数 key 用于 registry 或拥有多个具名成员的服务；角色名与 key 单复数一致（`Controller`、`Store`、`Registry`、`Runtime`、`Resolver`、`Executor`、`Provider`、`Backend`、`Handle` 等各有适用条件，见仓库 `cookbook/adding-a-package`）。

## 5. 能力 Seam 目录（核心服务速查）

harness 的核心服务（`ctx.<key>` → 角色 → 定义包 → 实现包）：

| ctx 键 | 角色 | 说明 |
|---|---|---|
| `ctx.llm` | seam | LLM 流服务；适配器（`llm-deepseek`/`llm-pi-ai`）注册提供方实现 |
| `ctx.tools` | core | 工具注册表 + 执行流水线；`dsh-tool-*` 系列消费 |
| `ctx.agents` | core | 实时 Agent 注册表、创建/恢复工厂 seam、发起者传播 |
| `ctx.sessions` | core | 仅追加 Session 实例，发出持久会话事件流 |
| `ctx.systemPrompt` | core | 每步收集提示词段落与模型可见工具 schema |
| `ctx.shell` | seam | Bash 执行能力；`bash-local`/`bash-sandbox`/`pwsh-local` 提供 |
| `ctx.subprocess` | seam | 进程 spawn 坐标与生命周期；`subprocess-local`/`subprocess-e2b` 等 |
| `ctx.fs` | seam | 文件系统；`fs-local`/`fs-sandbox`/`fs-e2b` |
| `ctx.web` | seam | 搜索与抓取；`web-search-exa`/`web-search-perplexity`/`web-search-deepseek`/`web-fetch-http` |
| `ctx.jobs` | seam | 后台任务注册表；`jobs-local` 提供，`tool-jobs` 面向模型控制 |
| `ctx.subagents` | seam | 子代理传输；`subagent-spawn-in-process`/`-fork`/`-acp`/`-codex`/`-claude-code`/`-dsh-sdk` |
| `ctx.approval` | seam | 一次性权限决策（`approval/request` waterfall） |
| `ctx.sandbox` / `ctx.sandboxPolicy` | seam/core | 沙箱执行后端 / 统一部署默认模式与工作区根 |
| `ctx.credentials` | seam | 凭据引用与解析；`credentials-local` |
| `ctx.settings` | seam | 分层设置；`settings-file` |
| `ctx.sessionPersistence` | seam | 会话持久化；`session-persistence-jsonl`/`-sqlite` |
| `ctx.sessionQuery` | seam | 会话查询；`session-query-sqlite` |
| `ctx.storage` / `ctx.storageDomain` | seam/core | KV 存储后端 / 领域化类型化持久状态 |
| `ctx.skills` | seam | skill 目录合并；`skill-filesystem`/`skill-badge` 提供 |
| `ctx.spillStore` | seam | 过大工具文本溢出存储 |
| `ctx.compaction` | seam | 上下文压缩 |
| `ctx.tokenMeter` | core | token 计量 |
| `ctx.codeRuntime` | seam | Code Mode 程序运行 |
| `ctx.terminals` | seam | PTY 会话 |
| `ctx.lsp` | seam | LSP 导航 |
| `ctx.workflowEngine` | seam | 工作流引擎 |
| `ctx.goals` | core | 目标状态折叠与延续 |
| `ctx.commands` | core | 面向人的命令注册 |
| `ctx.planMode` | core | 计划模式 |
| `ctx.webServer` | core | HTTP 载体 |
| `ctx.clientModules` | core | 浏览器模块图 |

> 完整列表（含直接消费方/配套插件）以官方 capability-seams 页面为准；开发时以各服务 TypeScript 接口和子系统页面的 `cordis-surface` 区块为权威，不要维护静态清单。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **能力的三种角色设计**：https://deepseek-harness.github.io/deepseek-harness/develop/practice/
- **能力 Seams 与核心服务**：https://deepseek-harness.github.io/deepseek-harness/reference/capability-seams
