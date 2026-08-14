# 05 · LLM 适配器开发指南

> 精简提炼自 develop/practice/llm-adapter、reference/cookbook/adding-an-llm-adapter。
> 参考实现：`packages/llm/llm-deepseek`（直接 HTTP + SSE，`eventsource-parser` 分帧）、`packages/llm/llm-pi-ai`（封装 LLM 库）。

## 1. 概述

LLM 适配器 = 继承 `LlmAdapter` 并实现 `stream()` 的类：把 Harness 的提供方无关请求（`GenerateOptions`）转成具体提供方 API 调用，把响应转回 Harness 分片（`StreamChunk`）。

## 2. 最小实现

```ts
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'
import { LlmAdapter, type GenerateOptions, type StreamChunk } from '@deepseek-ai/dsh-llm'

class MyAdapter extends LlmAdapter {
  constructor(private apiKey: string) { super() }

  async *stream(options: GenerateOptions): AsyncIterable<StreamChunk> {
    // 1. options.messages → 提供方格式
    // 2. 调流式 API（传 options.signal）
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
import { CallId, type StreamChunk } from '@deepseek-ai/dsh-llm'

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
    id: CallId('call-123'), name: 'bash',
    argumentsDelta: '{"command":"ls"}',       // 原始 JSON 文本增量
  }
  yield {
    type: 'block-end', index: 1,
    block: { type: 'tool-call', id: CallId('call-123'), name: 'bash', arguments: '{"command":"ls"}' },
  }
  // 5. 用量：必须在 finish 之前
  yield { type: 'usage', usage: { inputTokens: 100, outputTokens: 50 } }
  // 6. finish 必须是最后一块
  yield { type: 'finish', reason: { kind: 'stop' } }          // 或 { kind: 'tool-calls' } 请求执行工具
}
```

关键规则：

- 每个 `block-start` 必有对应 `block-end`。
- `index` 从 0 开始递增，标识内容块顺序；同一块的每次 delta 复用该 index。
- `tool-call` 的 `arguments` 全程是**原始 JSON 字符串**（流式片段用 `argumentsDelta`）；提供方返回已解析对象时，`block-end` 要重新 stringify。
- `usage` 必须在 `finish` 前；`finish` 后不再发出任何内容。稳健做法：缓冲 finish/usage 直到提供方流结束标记再统一 flush。

## 4. GenerateOptions 与 resolveModel

- `stream()` 接收仓库导出的 `GenerateOptions`：模型、适配器拥有的推理强度 ID、对话历史、系统提示词、工具 schema、生成参数、停止序列、中止信号。完整字段以 `@deepseek-ai/dsh-llm` 的类型为准。
- 不支持的字段：`throw new LlmError(..., 'UNSUPPORTED')`，绝不静默丢弃。
- 覆写 `resolveModel(provider, model, signal?)`：一次查询返回确切的提供方/模型身份 + 可选 `context`/`reasoning` 元数据。推理元数据含有序不透明 ID、展示名、可选配置默认值；保留适配器给出的权威可选列表（含能力 API 返回的 `off`），不提升为核心枚举。异步查询必须响应可选 signal。
- 可选覆写 `listModels()`：向选择器公布模型选项。

## 5. 注册与使用

```ts
ctx.llm.registerAdapter(['my-provider'], adapter)
```

- 第一个参数是该适配器处理的提供方路由列表；`GenerateOptions.provider` 选择适配器，`GenerateOptions.model` 是适配器拥有的模型 id。
- 注册基于副作用（HMR 安全）；每个提供方路由一个适配器，重复注册抛错；多路由注册要么全成功要么全失败。
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

- 传输与协议故障：`throw new LlmError(msg, 'STABLE_CODE')`；agent loop 保留错误及其 code 用于诊断与策略处理。**不要依赖普通 `Error` 自动转换**。
- 错误只有两条合法路径：从 `stream()` **抛出**（传输/协议故障，用带稳定 code 的 `LlmError`），或以 `finish {kind:'error'|'aborted'}` 结束流（提供方带内故障）。消费方两者都处理。
- 每个提供方 HTTP 请求合并 `attributionHeaders()`，并传递 `options.signal`。
- 需要回放状态时：把最小无损 JSON 投影作为 `finish.replayState` 发出；重建历史时验证该状态；状态缺失时不要仅凭 provider/model 名推断原生回放。

## 7. 实现结构建议

让协议格式（wire format）类型、请求序列化、传输解析、分片转换、适配器类各自独立职责；参考 `llm-deepseek` 的布局。对比 `llm-deepseek`（OpenAI 兼容）与 `llm-pi-ai`（不同 API 格式）可看到同一套契约在不同 SDK 之上的实现。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **LLM 适配器（教程）**：https://deepseek-harness.github.io/deepseek-harness/develop/practice/llm-adapter
- **添加 LLM 适配器（cookbook）**：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/adding-an-llm-adapter
- **LLM 流式响应子系统**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/llm-streaming
