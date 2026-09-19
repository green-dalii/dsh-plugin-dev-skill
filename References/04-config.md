# 04 · 插件配置与 Schemastery

> 精简提炼自 develop/basic/config、cordis-tutorial 第 5 章。

## 1. 导出 Config（接口 + schema）

插件导出同名的 TS 接口与 Schemastery schema；默认值直接写在 schema 中。消费方拿到类型，Cordis 拿到验证器。Cordis 在运行 `apply` 前校验配置并填充默认值。

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

- `Schema` 是显式默认导出；`Schema<Config>` 是类型用法（写成 `import z from '@deepseek-ai/schemastery'` + `z<Config>` 等价）。
- **不要导出普通对象作为 `Config`** —— Cordis 只接受 Standard Schema 验证器（`Plugin.Config?: StandardSchemaV1`）。普通对象会在加载时直接失败。
- 校验是**同步**的：schema 返回 Promise 时 Cordis 抛 `TypeError: Async config validation is not supported`。
- `Config` 是可选的：不导出 schema 时 `apply` 会原样收到用户写的 config（没有校验与默认值）。

## 2. 在 cordis.yml 中传配置

```yaml
- insert:
    - id: hello
      name: './src/my-plugin.ts'
      config:
        greeting: 'Hi there'
        maxRetries: 5
```

插件加载时：schema 校验 → 填充未提供字段的默认值 → 传入 `apply`。**`apply` 始终收到完整且经过校验的配置。** 校验失败会让该插件的 fiber 进入 FAILED，CLI 打印错误并以非零状态退出。

## 3. 严格校验示例

```ts
export const Config = Schema.object({
  apiKey: Schema.string().required(),                              // 必填
  timeout: Schema.number().default(30000),                         // 数字 + 默认
  mode: Schema.union(['fast', 'accurate']).default('fast'),        // 字面量联合
})
```

无效配置导致加载失败并给出明确错误，例如（实测输出，路径由 Cordis 追加）：

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

- `!!js` 仅在 `config` 与条目 `disabled` 字段内有效（`config` 递归生效）。
- `disabled: !!js ...` 在每次挂载决策时基于 loader 上下文求值（可按平台/环境门控一行）。
- 其余元数据（`name`、`id`、`inject` 等）保持静态字面值。
- `dsh --profile <name> --dump-config` 会**原样打印** `!!js` 表达式而不求值，适合自查。

## 6. 配合 HMR

配置变更触发插件热替换：卸载旧实例 → 加载新实例。由于注册都是 effect 自动清理，替换后不残留旧实例的注册。

前提是最终组合允许 HMR：自定义 profile 默认 `patchReload: live`，launcher 会挂载只监视 patch 文件的 HMR 回退，所以改 `cordis.yml`/`cordis.patch.yml` 的 `config` 就能热重载。**源码模块**热替换是另一回事——base 里的 `hmr` 行默认 `disabled: true`，要按 profile 显式启用。

## 7. 把配置放上 Web 设置页（可选）

Web 的「插件配置」页以 settings 命名空间为键配对：Host 半侧用 `ctx.settings.installSection()` 注册命名空间，浏览器半侧注册同名卡片，两侧自动配对（Host 未服务的命名空间不渲染任何东西）。

```ts
export function apply(ctx: Context, config: Config) {
  let source = () => config            // 权威配置源，由 setSource 更新
  ctx.inject(['settings'], (settingsCtx) => {
    settingsCtx.settings.installSection(ctx, 'my-plugin', Config, config, {
      setSource: (current) => { source = current },        // 用户写入后成为权威值
      onChange: () => { rebuild(source()) },               // 重新判定派生事实
      validate: (value) => { assertReachable(value.endpoint) },  // schema 表达不了的约束：拒绝写入
    })
  })
}
```

- `installSection` 的第 4 个参数（这里的 `config`）就是 `cordis.yml` 里的配置，作为组装层 `base` 与回退值；用户文档层叠在它之上。没有 settings provider 时照常工作（`ctx.inject` 保证可选）。
- `validate` 在**写入**时拒绝，而不是留到下次使用才发现。
- 字段上加 `role('secret')` 的值不会出现在任何响应里。
- 完整示例（含浏览器半侧与打包要求）见官方 Cookbook。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **插件配置（教程）**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/config
- **Cordis 教程 5：配置**：https://deepseek-harness.github.io/deepseek-harness/develop/cordis-tutorial/05-config
- **插件配置目录（生成参考）**：https://deepseek-harness.github.io/deepseek-harness/reference/config-catalog
- **Cookbook：新增设置卡片**：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/adding-a-settings-card
- **settings 子系统**：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/settings
