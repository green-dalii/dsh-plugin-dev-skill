# 11 · 扩展模式（Extension Cookbook）

> 精简提炼自 reference/cookbook/extension-cookbook 与 reference/cookbook/adding-a-conversation-node。
> 代码片段省略 import 与辅助实现，不可直接复制运行——它们是模式参考。

## 1. 工具插件

工具注册在 `ctx.tools` 上。`defineTool` 是第一方工具的类型化辅助函数（见 `03-tools.md`）；`ctx.tools.register()` 也直接接受原始 JSON Schema `ToolDefinition`（MCP 来源的工具就是这样到达的）。

## 2. 钩子插件（以权限门禁为例）

钩子插件 = 在拦截点上运行的普通 Cordis 插件，不需要外部协议。“原生钩子”模式：

```ts
import type { Context } from '@deepseek-ai/cordis'
import type { PreToolDecision, ToolExecution } from '@deepseek-ai/dsh-tools'

declare function isAllowed(exec: ToolExecution): Promise<boolean>

export const name = 'permission-gate'

export function apply(ctx: Context) {
  ctx.on('tools/pre-execute', async (exec, next): Promise<PreToolDecision> => {
    if (!(await isAllowed(exec))) {
      return { kind: 'deny', reason: 'Denied by policy.' }
    }
    return next()   // 委托默认（allow）
  })
}
```

扩展点选择规则：

- 可重排的策略层 → `tools/pre-execute`（waterfall）
- 需要单调最终拒绝的不变式 → `ctx.tools.guard()`
- 包裹实际分发生命周期（超时/重试/指标；仅 `exec.signal` 可替换）→ `tools/execute`
- 显式结果变换 → `tools/post-execute`
- 对不可变最终结果的受限观察 → `tools/result`

## 3. UI 插件

UI 插件从 `session/event` 事件流渲染（助手 token 流以 `assistant/chunk` 到达，加上轮次/步骤边界与工具活动），并通过 `agent.followup()` / `agent.steer()` 把输入驱动回去：

```ts
export const name = 'my-ui'
export const inject = ['agents']

export function apply(ctx: Context) {
  ctx.on('session/event', (_session, event) => {
    if (event.type === 'assistant/chunk' && event.data.chunk.type === 'text-delta') {
      render(event.data.chunk.text)
    }
  })
  onUserInput(text => ctx.agents.get(SessionId('client-session'))?.followup(createUserMessage({
    content: [{ type: 'text', text }],
    source: { kind: 'user' },
  })))
}
```

浏览器插件要向内置 Web Client 贡献业务行：注册 `ConversationNodeDefinition` 与 keyed Chat renderer（见第 5 节）。

## 4. 外部协议驱动

*协议驱动*把协议对端接入 `ctx.agents`（服务 UI 或自动化客户端）：

- stdio 驱动拥有 stdout，通过工厂 `create()`/`resume()` agent，把协议请求映射为 `followup()` 或 `cancel()`。
- 底层提示词请求返回**持久入队回执**；它不通过关联 `MessageId` 与 `turn/end` 获得结果。
- 整个 agent 状态单独发布；自动化可从回执等到下一次 idle 并概括这一区间；UI 持续观察开放式事件流。
- 拆除：`AgentHandle.dispose()` 使 dispose 完全停稳。

参考实现：`packages/acp/acp`（ACP JSON-RPC stdio，全新文本会话，发出已提交助手文本，注册一次性机器权限应答器）。

## 5. Conversation Node（向内置 Web Client 添加业务行）

步骤（详见官方 `adding-a-conversation-node` 页面）：

1. 声明 `ConversationNodeDefinition`：节点类型（`chat`）、keyed renderer、schema/元数据。
2. 在 `conversation/chat` 渲染注册表中注册 renderer。
3. 插件注册为 client 侧包（`dsh.client` manifest + `./client` 导出 + tsdown client preset——见 `cookbook/adding-a-package`）。

## 6. 可运行的组装示例

- 产品 `dsh` 启动器负责 Web 与一次性 headless 执行。
- ACP 叶子：`@deepseek-ai/dsh-acp-demo`；JSON-RPC 叶子：`@deepseek-ai/dsh-sdk-jsonrpc-demo`。
- headless 快照叶子：显式挂载 `@deepseek-ai/dsh-agent-spine-demo` + JSONL 持久化，通过示例自有测试 fixture 驱动。

## 7. 功能 → 机制映射（微内核宣言）

**每个产品功能都映射到一个文档化扩展点上的监听器；没有任何一行修改循环本身。** 常用映射：

| 产品功能 | 插件机制 |
|---|---|
| 钩子系统（用户级+项目级） | `agent/session-start`、`agent/pre-step`、`agent/request`、`tools/pre-execute`、`tools/post-execute`、`agent/turn-stopping` 上的监听器 |
| /goal | `ctx.goals` 管理持久状态 + round driver 调度 + 命令/工具生产方 |
| 动态工作流 | `ctx.workflowEngine` + worker-thread 引擎 + workflow 工具 |
| 排队消息 + steering | `Agent.followup()` / `Agent.steer()` |
| 上下文压缩 | `ctx.compaction` seam + `dsh-compaction-basic`（压力检查在 `agent/pre-step`，溢出恢复在 `agent/request-error`） |
| 系统提示词可配置性 | `ctx.systemPrompt.section()`（排序 + 作用域局部覆盖） |
| 内置工具 | `ctx.tools.register()`；schema 自动流入组装 |
| ToolSearch/渐进式披露 | 可见集变化时替换作用域化的 `ctx.tools.restrict()` 注册 |
| 工具截止时间/重试/指标 | `tools/execute` 环绕分发 |
| 最终工具结果指标/审计 | `tools/result` 观测不可变权威结果 |
| 子进程沙箱 | `ctx.sandbox` 后端（landlock/sandbox-exec）；能力级拒绝用 `tools/pre-execute` |
| 权限系统/AskUserQuestion | `tools/pre-execute` 返回 `ask` + `ctx.approval` 应答 |
| Plan mode | `@deepseek-ai/dsh-plan-mode`：`plan/mode` 状态、`plan:policy` 段、`/plan`、`exit_plan_mode` |
| subagent 委派 | `ctx.subagents` 提供方注册表 + `dsh-tool-subagent` |
| MCP | 每服务器一个插件：发现工具 → `ctx.tools.register()` |
| skill | section + 工具注册；调用时 `inject()` 注入 skill 内容 |
| 定时任务 | 插件注册面向模型的调度工具；定时器触发 → 空闲 `followup(…, {source:{kind:'cron'}})` / 忙碌 `inject()` |
| UI（GUI/CLI） | 监听 `session/event`；输入 → `followup()` |
| 遥测/可回放 trace | `session/event` → JSONL；回放 = `sessions.create(id, {seed})` |
| 模型适配器 | `registerAdapter` 注册 `LlmAdapter` 子类 |
| 插件热重载 | 每个注册都是 `ctx.effect` → HMR 直接生效 |

## 8. `system-prompt/assemble` 的注意义务

`system-prompt/assemble` 是专家协作式的整体装配变换：**返回的装配结果具有权威性**，监听器作者有责任保留活跃的 Code Mode 与结构化输出协议的贡献。需要展示/查找/执行对齐的工具过滤，优先用 `ctx.tools.restrict()`。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **扩展插件形态（cookbook）**：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/extension-cookbook
- **新增 Conversation Node（cookbook）**：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/adding-a-conversation-node
