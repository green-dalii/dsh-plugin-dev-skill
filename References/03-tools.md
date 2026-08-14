# 03 · 工具开发完整参考（defineTool）

> 精简提炼自 develop/basic/tool、reference/cookbook/adding-a-tool、reference/subsystems/tools、tool-execution-pipeline。
> 生产级参考实现：`packages/shell/tool-bash`（前台 + 后台 + 沙箱）、`packages/fs/tool-fs`（diff 卡片）、`packages/web/tool-web`（web 卡片）。

## 1. 最小形态

```ts
import { readFile } from 'node:fs/promises'
import type { Context } from '@deepseek-ai/cordis'
import { defineTool } from '@deepseek-ai/dsh-tools'

export const name = 'my-tool'
export const inject = ['tools']

export function apply(ctx: Context) {
  ctx.tools.register(defineTool({
    name: 'read_file',                                  // 模型看到的工具名
    description: 'Read a file from disk.',              // 模型看到的描述
    parameters: {
      path: { type: 'string', required: true, description: 'Absolute path' },
      limit: { type: 'number' },                        // 可选（不标 required）
    },
    output: {
      schema: { type: 'string' },                       // execute 返回的规范值
      render: (_args, value) => [{ type: 'text', text: value }],
    },
    async execute(args, exec) {
      // args 由 schema 推断类型：{ path: string; limit?: number }
      return readFile(args.path, { encoding: 'utf8', signal: exec.signal })
    },
  }))
}
```

注册是 effect：dispose 插件 fiber 即注销工具；schema 自动流入系统提示词组装。

## 2. execute() 契约（规则）

- **参数已为你校验**：`defineTool` 在 execute 前按 `ParameterSchemaSpec` 校验模型生成的 arguments（类型、必填键、字面量、oneOf 分支、嵌套值）。显式 object 节点必须声明 `additionalProperties: true | false`。schema DSL 表达不了的约束（非空字符串、正数、跨字段）仍要自己检查并抛错。
- **注册借用你的只读定义**：注册后不要修改 schema 或替换回调。热替换 = dispose 旧 effect + 注册替代品。
- **执行身份受保护**：注册表把 arguments 物化为无损 JSON、冻结，分配不透明 `exec.token`；`exec.signal` 是调用方持有、必填的取消信号。`args` 视为只读。
- **声明并返回规范 JSON 值**：`output.schema` 用 `ValueSchemaSpec`（对象/数组/标量/null 根均可）。execute 只返回推导出的值；注册表快照、校验、冻结后交给 `output.render(args, value)`。**不要返回内容块，不要逼调用方从自然语言解析 id/字段。**
- **抛异常或无效值 = `isError`**。基础设施故障抛异常；成功但结果不理想（如非零退出码）→ 返回规范值，由 render 解释。
- **遵守 `exec.signal`**：信号触发时取消进行中的工作。
- 可选 `output.presentationMeta(args, value)`：从同一规范值派生可回放的 JSON（纯函数），持久化在 `tool/result` 上供 `presentResult` 回放。
- 可选 `agent.inject({ content, source: { kind: 'plugin', plugin: '<name>' } })`：异步追加持久化上下文（下一次模型请求可见；不是唤醒）。注意防护已 dispose 的 agent。

## 3. 参数与值 schema 词汇（ValueSchemaSpec）

- 标量：`string` / `number` / `integer` / `boolean` / `null`；`enum` 与 `const` 值必须与节点类型匹配。
- 容器：`array`（可带 `items`）、`object`（`properties` + 显式 `additionalProperties`）。
- `oneOf`：恰好命中一个分支。
- `{ type: 'json' }`：不施加约束的无损 JSON（推导为 `JsonValue`）。
- 参数定义是**隐式开放对象**的逐属性映射，required 是每属性的 `required: true` 标注。

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
    ...exec.agent ? { owner: exec.agent } : {},
    run: () => {
      // 返回 { cancel, done, readOutput? }
      // done: 清理完成后 settle 且不 reject
      // readOutput: 可选的消费式有界输出读取
    },
  }),
}
```

要点：

- 后台分支返回**类型化的规范句柄**（如 `{ kind: 'background', jobId }`），输出 schema 必须能承载它；Code Mode 绝不能解析渲染文本拿 id。
- 预先中止的调用（已 abort 才进入 producer）判为失败。
- 发布 jobId 后，用**任务自有的取消信号**（归 `job_kill` / owner dispose / 服务 teardown），不再用 `exec.signal`。
- 前台工作仍与 `exec.signal` 耦合。

## 5. 执行策略与观测（扩展点）

| 扩展点 | 模式 | 用途 | 返回 |
|---|---|---|---|
| `tools/pre-execute` | waterfall | allow/deny/ask 策略 | `PreToolDecision`: `{kind:'allow'}` / `{kind:'deny',reason}` / `{kind:'ask'}` |
| `ctx.tools.guard()` | 单调守卫 | 最终拒绝（后续无法撤销） | `string | undefined`（返回 reason 即拒绝） |
| `tools/execute` | waterfall | 环绕分发：超时/重试/指标；可替换 `exec.signal` 不可移除 | `ToolExecutionResult` |
| `tools/post-execute` | waterfall | 替换内容或值、阻止结果、附加模型上下文 | `PostToolDecision`: `accept` / `block` |
| `tools/result` | emit | 只读观测不可变最终结果（日志/审计） | — |

规则：

- `tools/pre-execute` 返回 `ask` 只在审批服务返回 `allowed-once` 后继续，否则拒绝；无审批通道或无 agent 时 ask 也变成拒绝。
- guard 是单调的：任何 guard 都能拒绝，但没有任何 guard 能把已被拒绝的调用改回允许。
- `tools/post-execute` 替换内容会保留规范值与元数据；替换值会重新校验并重算内容/元数据；`block` 会把纠正反馈变成 `isError`。
- **尽量不要把部署策略内建到工具中**——放钩子插件（见 `11-cookbook.md` 权限门禁示例）。

流水线顺序（不修改循环本身）：
`tools/pre-execute` → guard → `tools/execute`（环绕） → `tools/post-execute` → `finalizeContent`（定义自有，快照固定） → `tools/result`（不可变最终结果）。

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

## 7. 作用域相关（了解）

- `ctx.tools.register(def)` — 全局或调用方 agent 作用域注册（作用域注册遮蔽全局；保留名 `run_code` 冲突失败）。
- `ctx.tools.restrict({ allow?, deny? })` — 按 agent 作用域过滤继承的全局工具；限制取交集；作用域自身注册不受限制。
- `ctx.tools.get(name, scope?)` / `ctx.tools.schemas(scope?)` — 按作用域查看工具/投影 schema。
- `ctx.tools.execute(input)` — 直接驱动一次调用（测试/协议桥用），input 含 `callId`、`name`、`arguments`、必填 `signal`、可选 `agent`/`parent`。
- 工具名重复：一层内重复、保留的 `run_code` 名会失败。

## 8. Code Mode 自动触达

在 Code Mode 中，每个可见工具都可通过 `await tools.<name>(args)` 调用，无需额外集成；成功解析为策略处理后的最终规范 JSON 值，失败以 `ToolCallError` reject（只能看 `name`/`toolName`/`message`）。因此**把 `output.schema` 设计为实用的程序化 API**：直接返回句柄与字段，面向人的解释放 `output.render`。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **开发一个 Tool（教程）**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/tool
- **工具编写参考（cookbook）**：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/adding-a-tool
- **工具子系统**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/tools
- **工具执行流水线**：https://deepseek-harness.github.io/deepseek-harness/reference/tool-execution-pipeline
