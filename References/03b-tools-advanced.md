# 03b · 工具进阶：后台任务、执行策略与 UI 卡片

> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。

> 本文件是工具参考的第 2/3 部分，覆盖后台任务、执行策略与观测钩子、UI 卡片。
> 第 1 部分见 `03-tools.md`，第 3 部分见 `03c-tools-pipeline.md`。

## 4. 长时间运行的工作（后台任务）

通过 producer 配置控制 `run_in_background`，注册到 `ctx.jobs`：

```ts
const jobs = ctx.get('jobs')
if (!jobs) throw new Error('background jobs unavailable: load @deepseek-ai/dsh-jobs and @deepseek-ai/dsh-tool-jobs')
return {
  kind: 'background',
  jobId: jobs.start({
    kind: 'bash',                  // 任务种类
    label: args.command,           // 展示用
    ...exec.agent ? { owner: exec.agent.id } : {},   // owner 是 SessionId（上游 cookbook 仍写 owner: exec.agent，以类型与 tool-bash 为准）
    output: sources,               // 可选：JobOutputSource[]，注册表按自己的节奏拉取
    run: (job) => {
      // 返回 { cancel, done }；done 在清理完成后 settle 且不 reject
      // 也可以推送：job.append(text, options?) / job.updateProgress(line)
    },
  }),
}
```

要点：

- 后台分支返回**类型化的规范句柄**（如 `{ kind: 'background', jobId }`），输出 schema 必须能承载它；PTC mode 绝不能解析渲染文本拿 id。
- **producer 契约已改**：`owner` 是 `SessionId`；`JobHooks` 只剩 `{ cancel(reason?), done }`（`readOutput?` 已移除）；流式输出改用 spec 上的 `output?: readonly JobOutputSource[]`（拉取）和/或 `JobHandle.append` / `updateProgress`（推送）；`run` 现在接收 handle；`JobOutcome` 的一次性返回值改名为 `result?: string`。
- 预先中止的调用（已 abort 才进入 producer）判为失败。
- 发布 jobId 后，用**任务自有的取消信号**（归 `job_kill` / owner dispose / 服务 teardown），不再用 `exec.signal`。
- 前台工作仍与 `exec.signal` 耦合。

## 5. 执行策略与观测（扩展点）

| 扩展点 | 模式 | 用途 | 返回 |
|---|---|---|---|
| `tools/pre-execute` | waterfall | allow/deny/ask 策略 | `PreToolDecision`: `{kind:'allow'}` / `{kind:'deny',reason,info?:ToolErrorInfo}`（`ToolErrorInfo` 含 `reason?`）/ `{kind:'cancel'}`（规范的前置取消结果，不呈现为策略拒绝）/ `{kind:'ask',reason?,displayReason?}` |
| `ctx.tools.guard()` | 单调守卫 | 最终拒绝（后续无法撤销） | **`string \| ToolGuardDenial \| undefined`**（0.2.2-rc.3 起可返回 `{ reason, info? }` 把结构化错误身份一并持久化；返回 `undefined` 放行） |
| `tools/execute` | waterfall | 环绕分发：超时/重试/指标；可替换 `exec.signal` 不可移除 | `ToolExecutionResult` |
| `tools/post-execute` | waterfall | 替换内容或值、阻止结果、附加模型上下文 | `PostToolDecision`: `accept` / `block`（0.2.2-rc.3 起 `block` 可带 `info?: ToolErrorInfo`） |
| `tools/ptc-dispatch-log` | waterfall | 改写一次 `run_code` 子分派**持久日志副本**的内容（程序已拿到完整值，模型两者都看不到） | `ContentBlock[]` |
| `tools/change` | emit | 工具集变化（注册/注销/作用域限制变化）；不受作用域过滤 | — |
| `tools/result` | emit | 只读观测不可变最终结果（日志/审计） | — |

规则：

- `tools/pre-execute` 返回 `ask` 只在审批服务返回 `allowed-once` 后继续，否则拒绝；无审批通道或无 agent 时 ask 也变成拒绝。
- guard 是单调的：任何 guard 都能拒绝，但没有任何 guard 能把已被拒绝的调用改回允许。
- **错误身份（0.2.2-rc.3 起）**：`tool/result` 的 `error` 会持久化错误类名与码。抛出 **`HarnessError` 子类**（基类来自新包 `@deepseek-ai/dsh-error`）才会带 `error.name` + `error.code`；普通 `Error` 只有 message。常见身份：
  - 审批拒绝 → `{ name: 'ApprovalError', code: 'APPROVAL_REJECTED' | 'APPROVAL_CANCELLED' | 'APPROVAL_UNAVAILABLE' }`（`APPROVAL_UNAVAILABLE` = 没有审批服务/Agent/通道能应答）
  - 取消（signal 已 abort 且抛出物不是 `HarnessError`）→ `{ name: 'AbortError', code: 'ABORTED' }`
  - 工具体缺上下文 → `ToolContextUnavailableError`（`TOOL_CONTEXT_UNAVAILABLE`），不可由模型纠正
- `tools/post-execute` 替换内容会保留规范值与元数据；替换值会重新校验并重算内容/元数据；`block` 会把纠正反馈变成 `isError`。**内容替换是展示策略而非保密策略**——要隐藏程序化值必须 `block` 或替换该值（PTC mode 程序仍能拿到 `value`）。
- PTC mode 的 `run_code` 子分派走同一条完整流水线：携带父级 token、记录 `tool/ptc-dispatch`、把拒绝呈现为有约束力的驳回，并省略 `additionalContexts` 以保持调用与结果相邻。
- **尽量不要把部署策略内建到工具中**——放钩子插件（见 `11-cookbook.md` 权限门禁示例）。

流水线顺序（不修改循环本身）：
`tools/pre-execute` → guard → `tools/execute`（环绕） → **`projectContent`（定义自有）** → `tools/post-execute` → `finalizeContent`（定义自有，快照固定） → `tools/result`（不可变最终结果）。

## 6. UI 卡片（展示，与模型内容分离）

`output.render` 产出模型可见内容；**UI 卡片是独立关注点**，通过纯展示投影 + 可选 `presentCall` / `presentResult` 声明。两者返回 `card` 标签的渲染意图：

**调用时（`presentCall(args)` → ToolCallView）**：
- `{ card: 'generic', title, kind?, rawInput?, content?, locations? }` — 默认；`locations: [{path, line?}]` 供编辑器跟随
- `{ card: 'terminal', title, description?, cwd? }` — 调用本身是 shell 命令（tool-bash）
- `{ card: 'diff', title, diffs, locations? }` — 创建/修改文件；`diffs: [{path, oldText, newText}]`（新文件 `oldText: null`）

**完成时（`presentResult(args, {content, isError, meta?})` → ToolResultView）**：
- `generic` / `terminal`（原始输出+退出元数据）/ `diff`（已应用 hunk，来自 `presentationMeta`）/ `search`（`shape:'matches'|'paths'` + `truncated`/`total`）/ `web`（`kind:'search'|'fetch'`）/ `read`（行号窗口）

硬性规则：

- **纯函数**：这些方法在实时流式输出**和**会话日志回放时都会运行——不做 I/O、不读会话状态、不用时钟/随机数。
- **UI 格式不进入模型结果**：围栏、diff、相对化路径不因服务 UI 而进入规范值或 Native 内容。
- 展示路径软校验：坏参数/旧日志 → 回退通用卡片，绝不 crash 回放。

> 本主题的官方文档链接见 `03c-tools-pipeline.md` 末尾。
