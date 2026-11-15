# 12 · 通用错误与修正（对照自查）

> 本文件是错误自查清单的第 1/2 部分：**与版本无关的设计 / 实现错误**。
> 带版本标记的破坏性变更见同目录 `12b-migration-errors.md`；升级指南原文索引见 `13-upgrade-guides.md`。
> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。

| 错误 | 修正 |
|---|---|
| 手动 `removeListener` / `clearInterval` | 全部改为 `ctx.on` / `ctx.effect`，卸载自动清理 |
| `export const Config = { ... }`（普通对象） | 用 `Schema.object({...})` 构建 Standard Schema |
| 硬编码 timeout/路径/阈值 | 移入 `Config` 字段并给默认值 |
| 在 `output.render` / `presentCall` 里做 I/O、读文件、用时钟 | 保持纯函数；I/O 进 `execute`，持久元数据进 `presentationMeta` |
| 工具 `execute` 返回人类可读文本而不是规范值 | 返回 `output.schema` 声明的规范 JSON 值；文本归 `output.render` |
| waterfall 监听器忘调 `next()` | 观察者必须 `next()`；不调 = 有意短路 |
| 用 `ctx.get()` 探测必需依赖 | 必需依赖写 `inject` |
| 服务名撞车（`ctx.tools`、`ctx.llm` 等） | 自有服务加辨识度前缀 |
| patch 覆盖别层行只写改动的键 | 重述该行全部所需键（整 config 替换语义） |
| 未声明 `inject` 却直接用 `ctx.xxx` | 补 `inject`（或改用 `ctx.get` 做可选探测） |
| waterfall 调用方忘传最后一个 `next` 实参 | 调用方传最内层延续：`ctx.waterfall(name, ...args, next)`（与「监听器必须调 `next()`」是两件事） |
| 怀疑 SKILL.md 与官方 DSH 不一致 | 跑 `bash scripts/verify.sh`：版本三处一致 + frontmatter 合法 + 官方链接 200（CI 也会跑） |

## 官方文档链接

- 工具设计原则：https://deepseek-harness.github.io/deepseek-harness/reference/cookbook/extension-cookbook
- 防御性模式（仓库内）：https://github.com/deepseek-ai/deepseek-harness/tree/master/docs/defensive-patterns
