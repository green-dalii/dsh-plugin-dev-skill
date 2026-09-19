# 05 · LLM 适配器开发指南

> 精简提炼自 develop/practice/llm-adapter、reference/cookbook/adding-an-llm-adapter、reference/subsystems/llm-streaming。
> 参考实现：`packages/llm/llm-deepseek`（直接 HTTP + SSE，`eventsource-parser` 分帧）、`packages/llm/llm-pi-ai`（封装 LLM 库）。
> 术语以 `@deepseek-ai/dsh-llm`（0.1.5-rc.2）的类型为准：工具调用 id 是 `ToolCallId`，旧名 `CallId` 已删除、SDK 不再导出。

## 1. 概述

LLM 适配器 = 继承 `LlmAdapter` 并实现 `stream()` 的类：把 Harness 的提供方无关请求（`GenerateOptions`）转成具体提供方 API 调用，把响应转回 Harness 分片（`StreamChunk`）。`stream()` 是唯一必须实现的方法，其余方法都有基类默认实现。

## 2. 最小实现

```ts
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'
import { LlmAdapter, type GenerateOptions, type StreamChunk } from '@deepseek-ai/dsh-llm'

class MyAdapter extends LlmAdapter {
  constructor(private apiKey: string) { super() }

  async *stream(options: GenerateOptions): AsyncIterable<StreamChunk> {
    // 1. options.messages → 提供方格式
    // 2. 调流式 API（必须传 options.signal）
    // 3. 响应 → StreamChunk 序列
  }
}

export interface Config {
  apiKey: string
  providers: string[]
}

export const Config: Schema<Config> = Schema.object({
  apiKey: Schema.string().required(),
  providers: Schema.array(Schema.string()).required(),
})

export const name = 'my-llm-adapter'
export const inject = ['llm']

export function apply(ctx: Context, config: Config) {
  ctx.llm.registerAdapter(config.providers, new MyAdapter(config.apiKey))
}
```

## 3. StreamChunk 协议（严格遵守）

```ts
import { ToolCallId, type StreamChunk } from '@deepseek-ai/dsh-llm'

async function* exampleChunks(): AsyncIterable<StreamChunk> {
  // 1. 每个内容块以 block-start 开始
  yield { type: 'block-start', index: 0, blockType: 'text' }
  // 2. 文本增量
  yield { type: 'text-delta', index: 0, text: 'Hello' }
  yield { type: 'text-delta', index: 0, text: ' world' }
  // 3. 每个内容块以 block-end + 完整块结束
  yield { type: 'block-end', index: 0, block: { type: 'text', text: 'Hello world' } }
  // 4. 工具调用块
  yield { type: 'block-start', index: 1, blockType: 'tool-call' }
  yield {
    type: 'tool-call-delta', index: 1,
    id: ToolCallId('call-123'), name: 'bash',
    argumentsDelta: '{"command":"ls"}',       // 原始 JSON 文本增量
  }
  yield {
    type: 'block-end', index: 1,
    block: { type: 'tool-call', id: ToolCallId('call-123'), name: 'bash', arguments: '{"command":"ls"}' },
  }
  // 5. 用量：必须在 finish 之前
  yield { type: 'usage', usage: { inputTokens: 100, outputTokens: 50 } }
  // 6. finish 必须是最后一块
  yield { type: 'finish', reason: { kind: 'stop' } }          // 或 { kind: 'tool-calls' } 请求执行工具
}
```

分片全集（封闭联合类型，新增变体会在每个消费方触发编译错误）：`block-start`、`text-delta`、`reasoning-delta`（`{ index, text }`，推理/思考内容，与可见文本分开）、`tool-call-delta`、`block-end`、`usage`、`finish`。`finish.reason` 还可为 `{ kind: 'max-tokens' }` 或带 `failure` 的 `{ kind: 'error' | 'aborted' }`。

关键规则：

- 每个 `block-start` 必有对应 `block-end`；块重组由 assembler 负责，适配器只需发出格式正确的分片。
- `index` 按块首次出现的流顺序从 0 递增；同一块的每次 delta 复用该 index。
- `tool-call` 的 `arguments` 全程是**原始 JSON 字符串**（流式片段用 `argumentsDelta`）；提供方返回已解析对象时，`block-end` 要重新 stringify。
- `usage` 必须在 `finish` 前；`finish` 后不再发出任何内容。稳健做法：缓冲 finish/usage 直到提供方流结束标记再统一 flush（应对结尾仅含 usage 的分片）。
- `usage` 各计数互不重叠：`inputTokens` 只含未缓存输入，缓存命中单列 `cacheReadTokens`/`cacheWriteTokens`（计费输入为三者之和）；`reasoningTokens` 已含在 `outputTokens` 内，汇总时不得重复相加。提供方把缓存折进 `prompt_tokens`（DeepSeek）时要自行扣除。

## 4. GenerateOptions 与模型元数据

- `stream()` 接收仓库导出的 `GenerateOptions`：`provider`/`model`、适配器拥有的 `reasoningEffort`、对话历史、系统提示词、工具 schema、生成参数、停止序列、`signal`、`sessionId`、`purpose`。完整字段以 `@deepseek-ai/dsh-llm` 的类型为准。
- 不支持的字段：`throw new LlmError(..., 'UNSUPPORTED_OPTION')`，绝不静默丢弃。
- 覆写 `resolveModel(provider, model, signal?)`：一次查询返回确切的提供方/模型身份 + 可选 `context`（`contextWindow`）、适配器配置的 `defaultMaxTokens`、`reasoning` 元数据（有序不透明 ID、展示名、可选 `defaultEffort`）与 `systemPromptUpdate`。推理元数据保留适配器给出的权威可选列表（含能力 API 返回的 `off`），不提升为核心枚举、不自动改写不支持的值。异步查询必须响应可选 signal。
- 覆写 `providerInfo(provider)`（返回 `{ id, name }`，`id` 必须等于该路由）与 `listModels(provider)`，向选择器公布展示元数据；目录仅供参考、不是请求白名单，适配器仍可接受未列出的模型 id。
- 仅当提供方对请求图片计视觉 token 时才覆写 `imageRequestPricing(provider, model)`：必须同步、无 I/O 地返回 `priceImages(...)`。

## 5. 注册与使用

```ts
ctx.llm.registerAdapter(['my-provider'], adapter)
```

- 第一个参数是该适配器处理的提供方路由列表；`GenerateOptions.provider` 选择适配器，`GenerateOptions.model` 是适配器拥有的模型 id（无需在生命周期启动时注册）。
- 注册基于副作用（HMR 安全）；每个提供方路由一个适配器，重复注册抛 `DUPLICATE_ADAPTER`；多路由注册要么全成功要么全失败。
- 返回值是 `AdapterRegistrationHandle`：调用即释放全部路由；`handle.replace(providers)` 原子替换同一适配器实例的路由（候选集先整体校验，失败时保持原路由不变）。
- 适配器插件可额外声明哪些路由**可以**运行：`ctx.llm.registerConfigurableProviders(entries)`（每条含 `provider`、`displayName`、`settingsNs`、`settingsPath`），让配置界面在路由注册前就呈现休眠的提供方；`registerModelDiscovery(settingsNs, discover)` 让设置界面能探测用户正在编辑的草稿端点。
- 密钥管理走 Cordis 原生方式：schemastery Config + 环境变量回退，`cordis.yml` 里 `!!js process.env.MY_KEY` 注入；**不要在代码里读自定义密钥文件**。

cordis.yml 中使用：

```yaml
- id: my-llm
  name: './src/my-llm-adapter.ts'
  config:
    apiKey: !!js process.env.MY_API_KEY
    providers: [my-provider]

- id: agent-loop
  name: '@deepseek-ai/dsh-agent-loop'
  config:
    agents:
      - id: main
        provider: my-provider
        model: my-model-v1
```

## 6. 错误处理

- 传输与协议故障：`throw new LlmError(msg, 'STABLE_CODE', { status?, providerRetryAfterMs?, requestId? })`；`LlmError.failure` 携带可序列化的 `LlmFailure`（`message`/`code`/`status`/`providerRetryAfterMs`/`requestId`）。**不要依赖普通 `Error` 自动转换**。
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

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **LLM 适配器（教程）**：https://deepseek-harness.github.io/deepseek-harness/develop/practice/llm-adapter
- **添加 LLM 适配器（cookbook）**：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/adding-an-llm-adapter
- **LLM 流式响应子系统**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/llm-streaming
