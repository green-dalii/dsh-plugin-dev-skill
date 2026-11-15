# 08 · 能力分层设计（三个角色）与能力 Seam 目录

> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。

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

> 本节表格较长，已拆为两个文件：核心服务部分见 `08b-seams-core.md`；平台、UI 与演进部分见 `08c-seams-platform.md`。
> 两个文件都沿用本表的表头（`ctx 键 | 角色 | 说明`），并按原表顺序续接，行内容与拆分前的原表逐字一致。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **能力的三种角色设计**：https://deepseek-harness.github.io/deepseek-harness/develop/practice/
- **能力 Seams 与核心服务**：https://deepseek-harness.github.io/deepseek-harness/reference/capability-seams
- **子系统参考（skills / tools / lsp / typert 等）**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/
- **术语表（capability-seam 的规范定义，源码）**：https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/glossary.zh.md
