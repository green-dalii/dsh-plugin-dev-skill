# 05b · LLM 适配器：错误处理与实现结构

> SDK 基线：`@deepseek-ai/*` **0.2.3-alpha.2**（cordis **4.2.0-alpha.1**）。

> 本文件是 LLM 适配器开发指南的第 2/2 部分：涵盖错误处理（`LlmError` / 失败码 / 重试策略 / 流式超时）、实现结构建议与官方文档链接；第 1 部分见 `05-llm-adapter.md`（概述、最小实现、StreamChunk 协议、GenerateOptions、注册与使用）。

## 6. 错误处理

- 传输与协议故障：`throw new LlmError(msg, '<CODE>', { status?, providerRetryAfterMs?, requestId?, offloadImages? })`；`LlmError.failure` 携带可序列化的 `LlmFailure`（`message`/`code`/`status`/`providerRetryAfterMs`/`requestId`/`offloadImages`）。**不要依赖普通 `Error` 自动转换**。
- **错误码是受约束的联合类型（0.2.2-rc.3 起，此前是自由字符串）**：`LlmError` 构造函数的 `code` 参数类型为 **`BuiltinLlmFailureCode`** = `keyof typeof LLM_FAILURE_CODES | \`HTTP_${number}\``。`LLM_FAILURE_CODES` 收录 **50 个**内置码，按用途大致分组：
  - 凭据/账户：`INVALID_CREDENTIAL`、`MISSING_CREDENTIAL`、`NO_CREDENTIAL_STORE`、`ACCOUNT_QUOTA`、`ACCOUNT_SIGN_IN_REQUIRED`、`ACCOUNT_TOKEN_INVALID`、`AUTH`
  - 额度/限流（可重试候选）：`QUOTA`、`RATE_LIMIT`
  - 上下文/模型：`CONTEXT_WINDOW_EXCEEDED`、`UNKNOWN_MODEL`、`MODEL_UNSUPPORTED`、`INVALID_MODEL_CONTEXT`、`INVALID_MODEL_INFO`、`INVALID_MODEL_MAX_TOKENS`、`INVALID_MODEL_REASONING`
  - 响应/流（可重试候选）：`EMPTY_RESPONSE`、`MALFORMED_RESPONSE`、`STREAM_CLOSED`、`TIMEOUT`、`TRANSPORT`、`SERVER`
  - 适配器/注册：`NO_ADAPTER`、`DUPLICATE_ADAPTER`、`INVALID_ADAPTER`、`INVALID_CONFIG`、`INVALID_REQUEST`、`UNSUPPORTED_OPTION`、`UNSUPPORTED_CONTENT`、`UNSUPPORTED_REASONING_EFFORT`、`IMAGE_OFFLOAD_REQUIRED`、`ABORTED`
  - 其余（发现、目录、回放、请求头等）共约 20 个，见 `LLM_FAILURE_CODES` 原文
  - 标 `retryChoice: true` 的码共 **8 个**，显式列表：`EMPTY_RESPONSE` / `MALFORMED_RESPONSE` / `QUOTA` / `RATE_LIMIT` / `SERVER` / `STREAM_CLOSED` / `TIMEOUT` / `TRANSPORT`。它们出现在 **`RETRY_CODE_CHOICES`**，供重试策略的 `retryableCodes` 选择——**只是候选项，默认不重试**。
- **提供方自有码**（不在上表里的）不能塞进构造函数：用静态方法 **`LlmError.fromFailure(failure, options?)`** 重新抛出已观测到的失败，保留其 `message` / `code` / 提供方事实。
- `IMAGE_OFFLOAD_REQUIRED` 配合 `offloadImages`（应卸载几处最旧的已保留图片）告诉调用方如何自愈。
- **`HarnessError` 已迁到独立包 `@deepseek-ai/dsh-error`**（0.2.2-rc.3 起），`dsh-llm` 再导出**同一个类**——所以从任一入口 `instanceof` 都成立；它带稳定 `code` 与 **`cause` 链**，`tool/result` 与回放靠它保留失败类别。
- 错误只有两条合法路径：从 `stream()` **抛出**（传输/协议故障，用带稳定 code 的 `LlmError`），或以 `finish { kind: 'error' | 'aborted', failure }` 结束流（提供方带内故障）。两条路径共用同一 `LlmFailure` 类型，消费方两者都处理。
- 适配器必须禁用底层 SDK 的自动重试：**一次适配器调用 = 一次提供方尝试**。重试由挂载的 `@deepseek-ai/dsh-llm-retry` 在持久 agent 步骤边界执行，策略由适配器按路由提供：覆写 `providerRetryPolicy(provider)` 返回已解析策略，或返回 `undefined` 使用 normal 默认（`EMPTY_RESPONSE`、`RATE_LIMIT`、`SERVER`、`TIMEOUT`、`TRANSPORT` 最多重试 5 次，退避 500ms→10s、10% 抖动）；`always` 模式无上限。
- 上下文溢出只有一个规范 code `CONTEXT_WINDOW_EXCEEDED`（用 `isContextWindowExceededError()` 分类，抛错或带内 finish 都一样）；`QUOTA` 表示配额/余额耗尽；正常结束但零内容块的 completion 是 `EMPTY_RESPONSE` 错误而非静默成功，默认会被重试。按 code 路由，绝不解析提供方文本。
- 提供方停顿在传输层受时限约束：交付适配器暴露正数有限的 `streamIdleTimeoutMs`（默认 5 分钟），watchdog 只在 iterator `next()` 未完成时启动，到期映射为 `TIMEOUT`，更早的调用方中止保留为 `ABORTED`。
- 每个提供方 HTTP 请求合并 `attributionHeaders()`（只产生标准 `user-agent`，默认取 `APP_IDENTITY`），并传递 `options.signal`。
- 需要回放状态时：把最小无损 JSON 投影作为 `finish.replayState`（`ReplayEnvelope`：`response` + 与发射块序列对齐的可选 `blocks`）发出；重建历史时验证该状态，仅当历史与目标 provider 路由由**同一适配器实例**拥有时 `LlmRuntime` 才传递。状态缺失时不要仅凭 provider/model 名推断原生回放；已存状态不可用只降级为提供方无关转换并带出诊断，不让请求失败。
- 要给 `deepseek-official` 请求注入顶层字段，走提供方扩展注册表 `ctx.deepseekLlmApiExtensions.register(field, provider)`：准备失败在 HTTP 前拒绝，`accept()` 事务只在 2xx 后运行；这些字段不进模型消息，也不进 pi-ai 路径。

## 7. 实现结构建议

让协议格式（wire format）类型、请求序列化、传输解析、分片转换、适配器类各自独立职责；参考 `llm-deepseek` 的布局。对比 `llm-deepseek`（OpenAI 兼容）与 `llm-pi-ai`（不同 API 格式）可看到同一套契约在不同 SDK 之上的实现。

---

## 8. pi-ai 适配器的版本与模型目录变动（0.2.1-rc.2 起）

**pi-ai 适配器已升到 pi-ai 1.3.0**：

- `kimi-coding` 改用 `openai-completions` 协议（`https://api.kimi.com/coding/v1`）；`opencode` / `opencode-go` 端点由 `/zen` 改为 `/inference`。
- 多个 provider 的模型 ID 被移除（`opencode-go` 的 `deepseek-v4-flash`、`openrouter` 的 `anthropic/claude-sonnet-4`、`google-vertex` 的 `gemini-flash-latest` 等），**无自动替代**。自建 provider 或 preset 引用这些 ID 时必须逐个替换。
- 过期的 `providers.<provider>.modelOverrides.<id>` 会报**缺失目录诊断**，且新覆盖被拒绝。
- 部分模型的 `contextWindow` / `maxTokens` 下调。

---

## 9. DeepSeek 文件策略与图片缩放（0.2.3-alpha.2 起）

### 9.1 `DeepSeekFilePolicy`
- 现**必填** `uploadConcurrency`、`uploadMaxRetries`、`uploadRetryDelayMs`、`uploadTimeoutMs`。默认值用 `@deepseek-ai/dsh-llm-deepseek` 的 `resolveAdapterOptions(options).filePolicy` 取；自定义值走 `fileExpiresAfterSeconds`、`fileRefreshMarginSeconds`、`fileQuotaCleanupBatch`；`ensureUploaded` 会记录 Files API 返回的文件 id。

### 9.2 图片缩放
- `imageMaxBytes` 是**硬性的编码后字节上限**，`imageTargetBytes` 是优先目标；缩图按质量阶梯 85 / 75 / 60；连 1×1 都放不下时抛 `IMAGE_REQUEST_TOO_LARGE`。
- DeepSeek `models` / `modelOverrides` 配置键 `imageMaxBytes` → `imageTargetBytes`（默认 2 MiB；旧键被拒），硬上限固定 32 MiB。
- `ImageRequestTarget`：`maxBytes` → `maxImageBytes`，并新增 `imageTargetBytes`（须 ≤ `maxImageBytes`）；最终尺寸由 `readImageRequest` 给出。
- DeepSeek 辅助：`resolveRequestImageTargetBytes`、`DEFAULT_REQUEST_IMAGE_TARGET_BYTES`；可调 `requestImageMinShrinkFactor`（1.1）、`requestImageByteHeadroom`（0.95）。

### 9.3 `refusal` 停止原因
- `stop_reason: "refusal"` 现产出 `CONTENT_REFUSED`（此前为 `MALFORMED_RESPONSE`），同样适用于 LLM 错误 finish 与失败轮次 `turn/end` 错误。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **LLM 适配器（教程）**：https://deepseek-harness.github.io/deepseek-harness/develop/practice/llm-adapter
- **添加 LLM 适配器（cookbook）**：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/adding-an-llm-adapter
- **LLM 流式响应子系统**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/llm-streaming
