> SDK 基线：`@deepseek-ai/*` **0.2.3-alpha.2**（cordis **4.2.0-alpha.1**）。

# 03d · PTC 运行时细节（`ctx.ptcRuntime` / `run_code`）

> 工具流水线、步骤准入与执行器插件见 `03c-tools-pipeline.md`；本文件只收录 PTC 运行时的精确 API 事实，精简提炼而非原文转录。

## 1. 程序格式与跨调用状态

- `PtcRuntime.programFormat` 取值含 `'function-body' | 'repl' | 'script' | 'scoped-repl'`。**不要手写该联合类型**——从 `@deepseek-ai/dsh-ptc-runtime` 导入 `PtcProgramFormat`。
- 是否跨调用保留记忆由 `runtime.retainsState` 决定（基类返回 `false`），不要再以 `programFormat === 'repl'` 推断。保留状态的自定义 provider 必须覆写 `retainsState`，并继续实现 `release(owner)`。

## 2. Node PTC：默认执行模式翻转

- `@deepseek-ai/dsh-ptc-runtime-node` 的默认 `executionMode` 由 `per-call` 改为 **`persistent-in-memory`**；配合默认 `replScoped`，实际跑的是 scoped REPL，上报格式为 `scoped-repl`。
- 每个存活 Agent 持有一个 Node 进程；顶层绑定带入后续调用；顶层 `return` 被拒绝；最后一个顶层表达式语句作为完成值；模块加载用 `await import(...)`，不要用 `require`。
- **只有省略 `executionMode` 的条目受影响**（默认 profile 的 PTC mode、workflow-ptc 脚本、直接使用 runtime 的消费者）。要保留旧行为，用 patch：`- id: ptc-runtime` / `config: { executionMode: per-call }`；**patch 会整体替换 config**，务必复制已有字段。
- ⚠️ 另一篇指南 `v0.2.2-rc.1/ptc-scoped-repl-default` 是更早的**不同**改动（对已用 `persistent-in-memory` 的条目翻转 `replScoped`），不要与本条混淆。

## 3. 输出截断

- `maxOutputBytes` 只截断**展示输出**，**不中断执行**（环境初始化阶段同样适用）。`PtcRunResult.outputTruncated` 与 `error` **独立设置**；作为完成值必需的 JSON 值保持无损；溢出结果为 `output-limit`。
- 私有 bootstrap 协议修订到 **5**（3/4 号 bootstrap 在派发前被拒）。`run_code` / `createRunCodeTool` 仍返回成功，且带 `outputTruncated: true`。

## 4. 检查与 Host 桥接

- `inspect(result)` 对未改写的对象/数组结果展示工具的**最终渲染文本**（经输出策略之后），由 `@deepseek-ai/dsh-ptc-runtime` 的 `PtcInspectableValue` 承载。第三方 `PtcRuntime` 必须让 `.value` 就是该对象/数组、`.text` 与该未改写值对应，且**不要暴露包装器**。
- `HostMethods.invoke` 回复 `{ value: flatWire, inspection?: string }`；`launch.bootstrapPath` 必须部署 `@deepseek-ai/dsh-ptc-runtime-node`（`lib/process.js`、`lib/persistent-process.js`）。Bootstrap 协议 3 → 5。

## 5. MCP 图片值

- 准入的 MCP 图片块在 `type`/`mimeType`/`data` 之外新增 `attachment`。PTC 中 `{ type: 'image', attachment }` 若其 attachment 出现在最终完成值里，会变成 `Image`（与 `read_image` / CUA 截图一致）；用 `image.path` 读字节，不是 base64 `data`。被策略移除的图片块仍保留 `attachment`，但保持为 JSON。

## 6. 执行器侧约束（原 03c）

- `tool-executor-ptc` 的 `maxSubCallsPerMinute` 默认 **1024**（0.2.2-rc.3 起）：按解析后的 runtime 超时折算的每分钟子调用额度，含失败调用，用于兜住死循环；超限抛 `ToolCallLimitExceededError`。
- executor 只接受**声明 TypeScript 语言**的 PTC provider；用其它语言建 `/run-code` 工具或组装提示词会以 `ToolContextUnavailableError` / `TOOL_CONTEXT_UNAVAILABLE` 失败。

---

> 精简提炼，原文入口：https://github.com/deepseek-ai/deepseek-harness/tree/master/docs/upgrade-guide
