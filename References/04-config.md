# 04 · 插件配置与 Schemastery

> 精简提炼自 develop/basic/config、cordis-tutorial 第 5 章。

## 1. 导出 Config（接口 + schema）

插件导出同名的 TS 接口与 Schemastery schema；默认值直接写在 schema 中。Cordis 在 `apply` 前校验配置并填充默认值。

```ts
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'

export const name = 'my-plugin'

export interface Config {
  greeting: string
  maxRetries: number
  verbose?: boolean
}

export const Config: Schema<Config> = Schema.object({
  greeting: Schema.string().default('Hello'),
  maxRetries: Schema.number().default(3),
  verbose: Schema.boolean().default(false),
})

export function apply(ctx: Context, config: Config) {
  console.log(config.greeting)  // 用户值或 schema 默认值
}
```

**不要导出普通对象作为 `Config`** —— 它不满足 Cordis 要求的 Standard Schema 接口。必须用 Schemastery（或任何 Standard Schema 验证器）构建。

## 2. 在 cordis.yml 中传配置

```yaml
- insert:
    - id: hello
      name: './src/my-plugin.ts'
      config:
        greeting: 'Hi there'
        maxRetries: 5
```

插件加载时：schema 校验 → 填充未提供字段的默认值 → 传入 `apply`。**`apply` 始终收到完整且经过校验的配置。**

## 3. 严格校验示例

```ts
export const Config = Schema.object({
  apiKey: Schema.string().required(),                              // 必填
  timeout: Schema.number().default(30000),                         // 数字 + 默认
  mode: Schema.union(['fast', 'accurate']).default('fast'),        // 字面量联合
})
```

无效配置导致加载失败并给出明确错误，例如：

```
ValidationError: invalid config:
  - $.targets expected array but got not-an-array (at targets)
```

## 4. 设计原则

1. **无硬编码可调参数**：凡是不同部署取值可能不同的参数，都必须定义为配置字段。检验标准：能否在 `cordis.yml` 中改变这个值而不改代码？
2. **配置错误要响亮**：在 schema 中表达自身完备的约束，使无效配置在加载时失败。
3. **引用即校验**：配置通过 schema 但指定的服务/资源不可用时，应在能解析该引用时立即拒绝（错误配置绝不带病启动）。

## 5. `!!js` 计算值

Loader 支持 `!!js` 标签，用于必须在加载时计算的配置值：

```yaml
- name: './config-demo.ts'
  config:
    greeting: !!js process.env.DEMO_GREETING ?? 'Hello'
```

- `!!js` 仅在 `config` 与条目 `disabled` 字段内有效。
- `disabled: !!js ...` 在每次挂载决策时基于 loader 上下文求值（可按平台/环境门控一行）。
- 其余元数据（`name`、`id`、`inject` 等）保持静态字面值。

## 6. 配合 HMR

配置变更触发插件热替换：卸载旧实例 → 加载新实例。由于注册都是 effect 自动清理，替换后不残留旧实例的注册。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **插件配置（教程）**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/config
- **Cordis 教程 5：配置**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/05-config
- **插件配置目录（生成参考）**：https://deepseek-harness.github.io/deepseek-harness/reference/config-catalog
