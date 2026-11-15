# 03 · 工具开发完整参考（defineTool）

> 精简提炼自 develop/basic/tool、reference/cookbook/adding-a-tool、reference/subsystems/tools、reference/tool-execution-pipeline。
> API 以本地 SDK `@deepseek-ai/dsh-tools` **0.2.2-rc.3**（cordis **4.1.0**）为准。**0.2.1-rc.2 是一次大重构**：工具执行拆成 executor 插件、工具声明改由「步骤准入」决定——见 `03c-tools-pipeline.md` §7/§8/§9。逐版本变化见 `References/00-INDEX.md`。
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
    name: 'read_file',                                  // 模型看到的工具名（snake_case 惯例）
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

## 2. execute() 契约与定义级元数据（规则）

- **参数已为你校验**：`defineTool` 在 execute 前按 `ParameterSchemaSpec` 校验模型生成的 arguments（类型、必填键、字面量、oneOf 分支、嵌套值）。显式 object 节点必须声明 `additionalProperties: true | false`。schema DSL 表达不了的约束（非空字符串、正数、跨字段）仍要自己检查并抛错。
- **注册借用你的只读定义**：注册后不要修改 schema 或替换回调。热替换 = dispose 旧 effect + 注册替代品。
- **执行身份受保护**：注册表把 arguments 物化为无损 JSON、冻结，分配不透明 `exec.token`；`exec.signal` 是调用方持有、必填的取消信号。`args` 视为只读。额外两个运行时扩展：`exec.deferContext(msg)` 把上下文挂到**本次执行自己的结果**上（直到本工具的 `tool/result` 之后才追加，按调用序，组合工具用它转运嵌套分派上下文）；`exec.concludeTurn()` 把本次成功结果标记为当前轮次的终点。另新增 `exec.schema?: ToolSchema`（**0.2.0 新增**）：PTC 内层调用的**绑定期**工具 schema，由其生产者冻结、**永不写入日志**（`signal`/`token`/`deferContext`/`concludeTurn`/`agent` 不变）。
- **声明并返回规范 JSON 值**：`output.schema` 用 `ValueSchemaSpec`（对象/数组/标量/null 根均可）。execute 只返回推导出的值；注册表快照、校验、冻结后交给 `output.render(args, value)`。**不要返回内容块，不要逼调用方从自然语言解析 id/字段。**
- **抛异常或无效值 = `isError`**。基础设施故障抛异常；成功但结果不理想（如非零退出码）→ 返回规范值，由 render 解释。
- **遵守 `exec.signal`**：信号触发时取消进行中的工作。
- 可选 `output.presentationMeta(args, value)`：从同一规范值派生可回放的 JSON（纯函数），注册表把它持久化在 `tool/result` 的 `meta` 上并传给 `presentResult` 供回放。嵌套的 `run_code` 子分派没有卡片，会跳过该投影器。
- 可选 `agent.inject({ content, source: { kind: 'plugin', plugin: '<name>' } })`：异步追加持久化上下文（下一次模型请求可见；不是唤醒）。注意防护已 dispose 的 agent。

**定义级运行时元数据**（`defineTool` 顶层字段，除模型可见的 `deferLoading` 外都不进入模型请求——`schemas()` 只白名单 `name`/`description`/`parameters`/`deferLoading`）：

- `timeoutMs?: number`：协作式超时预算（毫秒），由 `@deepseek-ai/dsh-tool-call-timeout-policy`（一个 `tools/execute` 包装器）强制执行。声明它即承诺把 `exec.signal` 转发给能在中止时归于静止的实现。
- `isConcurrencySafe?(args): boolean`：与同批兄弟调用是否可重叠。**只有精确返回 `true` 才并行**；缺省、抛异常、返回非 `true` 一律按独占处理，独占调用构成排序屏障。选择并行即承诺不改动父级拥有的状态。
- `projectContent?(exec, result): ContentBlock[] | undefined`：把**执行期准备好的内容**（文本 + 图片）在 `tools/post-execute` **之前**装进去；回调在调用开始时捕获，对每个进入 post-execute 的归一化结果恰好运行一次，post-execute 的策略替换仍然权威；**绕过 post-execute 的流水线失败会跳过该投影**。
- `finalizeContent?(exec, result): ContentBlock[] | undefined`：最后一道**只管内容**的同步变换，位于 post-execute **之后**（**包括**绕过 `tools/post-execute` 的流水线失败），对每个归一化结果恰好调用一次，位置在无损物化之前。必须全函数、不得抛错；返回 `undefined` 保留原内容，其余字段仍归注册表所有。
- `deferLoading?: true`：唯一模型可见的顶层字段（随 `ToolSchema` 投影给模型）：声明该工具**延迟加载**，模型按需激活，而不是每次请求都下发完整声明列表。

## 3. 参数与值 schema 词汇（ValueSchemaSpec）

- 标量：`string` / `number` / `integer` / `boolean` / `null`；`enum` 与 `const` 值必须与节点类型匹配。
- 容器：`array`（可带 `items`）、`object`（`properties` + 显式 `additionalProperties`）。
- `oneOf`：恰好命中一个分支，**至少要有 2 个分支**。
- `{ type: 'json' }`：不施加约束的无损 JSON（推导为 `JsonValue`）。
- 参数定义是**隐式开放对象**的逐属性映射，required 是每属性的 `required: true` 标注，**只能写 `true` 或省略**——写 `required: false` 会**类型报错**；显式 object 节点里**没有 `required: [...]` 数组**，必填同样靠每个属性自己的 `required: true`。

> 本主题的官方文档链接见 `03c-tools-pipeline.md` 末尾。
