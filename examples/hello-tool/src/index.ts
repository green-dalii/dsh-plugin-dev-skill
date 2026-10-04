// Minimal DSH tool — copy this template to start your own.
//   Input  : { name?: string }            (object DSL, `name` optional, defaults to "world")
//   Output : string                       (a greeting)
//   Render : single text block
//
// 验证清单（按顺序跑；详细说明见 ./README.md）：
//   1. 把 `dsh-hello-tool` 放进你的 profile bundles（`dsh plugin add <path>`）
//   2. `dsh --profile demo --dump-config` —— 应看到 `id: hello-tool` 与 greeting 默认值
//   3. 在 Web UI / `--profile web` 里问模型："用 hello_tool 跟我打个招呼"
//   4. 期待模型最终收到文本块："Hello, world!"

import type { Context } from '@deepseek-ai/cordis'
import { defineTool } from '@deepseek-ai/dsh-tools'
import Schema from '@deepseek-ai/schemastery'

export interface Config {
  /** 默认问候语，运行时可被 profile patch 覆盖 */
  greeting: string
}

export const Config: Schema<Config> = Schema.object({
  greeting: Schema.string().required().default('Hello'),
})

export const name = 'dsh-hello-tool'

export function apply(ctx: Context, config: Config) {
  ctx.tools.register(
    defineTool({
      name: 'hello_tool',
      description: 'Return a greeting string. Use this to demonstrate the tool pipeline.',
      parameters: {
        name: {
          type: 'string',
          required: false,
          description: 'Who to greet. Defaults to "world".',
        },
      },
      output: {
        schema: { type: 'string' },
        render: (_args, value) => [{ type: 'text', text: value }],
      },
      async execute(args) {
        // 不需要 schema 已经校验过的非空字符串约束 —— 这就是 execute 内部仍要做的「DSL 表达不了的检查」
        const who = (args.name ?? 'world').trim() || 'world'
        return `${config.greeting}, ${who}!`
      },
    })
  )
}