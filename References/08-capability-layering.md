# 08 · 能力分层设计（三个角色）与能力 Seam 目录

> 精简提炼自 develop/practice/（能力的三层拆分）、reference/capability-seams 与 glossary。

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
- 角色需要独立演进或替换时拆到不同包；否则一个包可承担多角色（`dsh-user-approval` 同包承担 approval seam 的 Definition 与其具体实现）。**完整能力 = 整个 seam，任何单一角色都不是 seam**（seam 一词仅保留此义）。
- **Definition 必须是 Cordis `Service`**——可以是 `ShellExecutor` 这样的抽象类，也可以是 `WebRuntime` 这样的具体注册表；**绝不能是 TypeScript `interface`**。它拥有自己的 `ctx.<key>` 和词汇类型。

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
- **只想附加策略/适配器时不要新增 seam**：优先挂到已有扩展点（`ctx.tools` 的 `tools/*` 事件、`ctx.fs` 的 `fs/*` 事件、`ctx.llm` 的适配器注册）。
- 服务命名：单数 `ctx` key 用于 engine/runtime/policy/controller/resolver/store；复数 key 用于 registry 或拥有多个具名成员的服务；角色名与 key 单复数一致（`Controller`、`Store`、`Registry`、`Runtime`、`Resolver`、`Executor`、`Provider`、`Backend`、`Handle` 等各有适用条件，见仓库 `cookbook/adding-a-package`）。

## 5. 能力 Seam 目录（核心服务速查）

harness 的核心服务（`ctx.<key>` → 角色 → 说明）：

| ctx 键 | 角色 | 说明 |
|---|---|---|
| `ctx.llm` | seam | LLM 流服务；适配器（`llm-deepseek`/`llm-pi-ai`，测试用 `llm-replay`）注册提供方实现 |
| `ctx.deepseekLlmApiExtensions` | seam | 插件准备彼此独立的顶层请求字段，官方适配器合并后再提交交付状态 |
| `ctx.tools` | core | 工具注册表 + 执行流水线；`dsh-tool-*` 系列消费。同时负责 **PTC mode** 传输（保留的 `run_code` + 生成 SDK；配置 `mode: native\|ptc\|both`） |
| `ctx.agents` | core | 实时 Agent 注册表、创建/恢复工厂 seam、发起者传播 |
| `ctx.sessions` | core | 仅追加 Session 实例，发出持久会话事件流 |
| `ctx.systemPrompt` | core | 每步收集提示词段落与模型可见工具 schema |
| `ctx.sessionTitle` | seam | 会话标题：确定性回退 + 唯一可选异步提供方（`session-title-*-llm`） |
| `ctx.sessionProjections` | core | 各领域注册状态驱动的折叠单元；host 读取方经 `stateOf()`/`snapshot()` 取类型化状态 |
| `ctx.shell` | seam | Bash 执行能力；`bash-local`/`bash-sandbox`/`pwsh-local` 提供 |
| `ctx.shellEnv` | core | 插件声明 effect 作用域的 `DSH_*` 事实；每个 shell 工具执行时收集可信快照 |
| `ctx.subprocess` | seam | 进程 spawn 坐标与生命周期；`subprocess-local`/`subprocess-ssh` 等 |
| `ctx.ssh` | core | 一条已认证 OpenSSH 连接；`fs-ssh`/`subprocess-ssh`/`sandbox-ssh` 据此把 fs、进程与沙箱整体搬到远端 |
| `ctx.fs` | seam | 文件系统；`fs-local`/`fs-sandbox`/`fs-ssh`；`fs-observation-policy` 经 `fs/*` 事件门禁 |
| `ctx.web` | seam | 搜索与抓取；`web-search-exa`/`web-search-perplexity`/`web-search-deepseek`/`web-fetch-http` |
| `ctx.mcpResources` | seam | 连接所有者在调用 agent 的作用域内提供共享 MCP 资源工具；`mcp-client` 侧提供 |
| `ctx.jobs` | seam | 后台任务注册表；`jobs-local` 提供，`tool-jobs` 面向模型控制 |
| `ctx.subagents` | seam | 子代理传输；`subagent-spawn-in-process`/`-fork-in-process`/`-acp`/`-codex`/`-claude-code`/`-dsh-sdk` |
| `ctx.approval` | seam | 一次性权限决策（`approval/request` waterfall）；Definition 与实现同包在 `dsh-user-approval` |
| `ctx.permissionPresets` | core | 面向用户的预设表：把沙箱模式与审批选项组合成 `workspace-write`/`danger-full-access` |
| `ctx.sandbox` / `ctx.sandboxPolicy` | seam/core | 沙箱执行后端 / 统一部署默认模式与工作区根；`sandbox-local`/`sandbox-ssh` 提供 |
| `ctx.credentials` | seam | 凭据引用与解析；`credentials-local` 提供 |
| `ctx.authorization` | seam | 取得某份凭据的 flow 注册；seam 拥有「每个键同时只跑一次尝试」的生命周期 |
| `ctx.settings` | seam | 分层设置；`settings-file` 提供，适配器把入口配置注册为组合基础 |
| `ctx.sessionPersistence` | seam | 会话持久化；`session-persistence-jsonl` 等 |
| `ctx.sessionQuery` | seam | 会话查询；`session-query-sqlite` |
| `ctx.sessionTelemetry` | seam | 捕获会话记录、脱敏后交给单一后端（`session-telemetry-otel`） |
| `ctx.storage` / `ctx.storageDomain` | seam/core | KV 存储后端 / 领域化类型化持久状态；`storage-json`/`storage-sqlite` |
| `ctx.skills` | seam | 分层（宿主 + scope）合并 provider 的 skill 目录；`skill-filesystem`/`skill-badge`/`skill-office` 提供，`tool-skill` 消费。发现根按 rank：`<project>/.dsh/skills`(100)、`<project>/.agents/skills`(200)、`customSkillDirs`(300)、`$DSH_HOME/skills`(400)、`$DSH_AGENTS_HOME/skills`(500)、bundled(600)；名称须为 kebab-case，接受 `<name>/SKILL.md` 或 `<name>.md`（不递归），frontmatter 必填 `name`/`description`，可选 `whenToUse`/`disable-model-invocation`/`user-invocable` |
| `ctx.fileReferences` | seam | 返回 Agent cwd 内仅含路径的补全候选（不读内容）；`file-reference-local` 提供 |
| `ctx.spillStore` | seam | 过大工具文本溢出存储；`spill-local` 提供，`spill-policy` 决定何时 spill |
| `ctx.compaction` | seam | 上下文压缩；`compaction-basic` 提供 |
| `ctx.tokenMeter` | core | token 计量 |
| `ctx.ptcRuntime` | seam | **PTC mode** 程序运行（用宿主异步绑定运行模型写的程序）；`ptc-runtime-node` 等提供，`tools` 与 `workflow-ptc` 消费 |
| `ctx.terminals` | seam | PTY 会话；`terminal-bash` 提供，`tool-terminal` 面向模型 |
| `ctx.lsp` | seam | LSP 导航；`lsp-stdio` 提供，`tool-lsp` 消费（只有四种标准化查询，无协议逃生口） |
| `ctx.browserUse` | seam | 浏览器操作提供方注册；提供方（playwright-mcp / chrome-devtools-mcp / stagehand-native）自持工具与浏览器资源 |
| `ctx.computerUse` | seam | 桌面操作提供方注册（cua-driver 的 mcp / native 变体）；提供方自持模型工具 |
| `ctx.attachments` | seam | 会话事件之前提交已接受的图片；`attachment-local` 提供，Session Controller / `tool-fs` / LLM 适配器消费 |
| `ctx.officeToPdf` | core | 已授权 Office 字节在宿主上转换；未声明原生目标时用 Node WASM |
| `ctx.userQuestions` | seam | 人工回答提供方；`tool-ask-user` 在提供方无关的 `ask()` promise 上暂停 |
| `ctx.directoryPicker` | seam | 带判别标记的目录选择：native（系统选择器）/ browse（应用内浏览器） |
| `ctx.workflowEngine` | seam | 工作流引擎；每个上下文一个引擎，`workflow-ptc` 提供 |
| `ctx.goals` | core | 目标状态折叠与延续 |
| `ctx.agentPresets` | core | 在受信任根与用户创作根发现 preset 目录，并在创建期把 preset `cordis.yml` 挂到 agent 作用域下 |
| `ctx.agentTeams` | core | 实验性协作 seam：持久 roster、peer mailbox、任务 DAG（需显式启用） |
| `ctx.commands` | core | 面向人的命令注册 |
| `ctx.planMode` | core | 计划模式 |
| `ctx.invariants` | core | 运行时不变式检查注册表；各包以 `./invariant` 配套子路径按自身 npm 包名注册 |
| `ctx.typert` | core | 插件注册实时 zod 贡献；API 网关消费调用描述符与提供方 |
| `ctx.webServer` | core | HTTP 载体 |
| `ctx.clientModules` | core | 浏览器模块图 |

> 表内混合本地 `0.1.5-rc.2` 与更新上游文档：`ctx.ptcRuntime`、`ctx.browserUse`、`ctx.computerUse`、`ctx.officeToPdf`、`ctx.ssh`、`ctx.agentTeams`、`skill-office` 在本地 SDK 中尚未出现（本地对应物是 `ctx.codeRuntime` / `dsh-code-runtime`）；以本地安装为准时请先用该服务的 TypeScript 接口核对 key。
>
> 完整列表（含每个 seam 的 Definition 包、全部 Provider 与直接消费方）以官方 capability-seams 页面为准；开发时以各服务 TypeScript 接口和子系统页面的 `cordis-surface` 区块为权威，不要维护静态清单。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **能力的三种角色设计**：https://deepseek-harness.github.io/deepseek-harness/develop/practice/
- **能力 Seams 与核心服务**：https://deepseek-harness.github.io/deepseek-harness/reference/capability-seams
- **子系统参考（skills / tools / lsp / typert / invariants 等）**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/
- **术语表（capability-seam 的规范定义，源码）**：https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/glossary.zh.md
