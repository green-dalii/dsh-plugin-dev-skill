---
name: dsh-plugin-dev-skill
description: 指导任何 Agent 正确、高效、符合规范地开发 DeepSeek Harness（DSH）插件。涵盖 Tool（defineTool）、LLM 适配器、服务与依赖、事件系统、配置、打包发布，以及 Cordis 框架的心智模型、代码模板与验证清单。
whenToUse: 当任务涉及为 DeepSeek Harness 编写/修改/调试插件（tool、LLM adapter、服务提供方、钩子、UI、协议桥等），编写或修改 cordis.yml / cordis.patch.yml / dsh.profile / dsh.bundle 配置，使用 dsh plugin 命令，或需要理解 ctx.tools、ctx.llm、ctx.agents、ctx.sessions 等服务与 tools/*、agent/*、session/event 等事件时，加载本技能。
metadata:
  version: 0.9.0
  upstream: https://github.com/green-dalii/dsh-plugin-dev-skill
  sdk-baseline: 0.2.2-rc.3
---

# DeepSeek Harness Plugin Dev Skill

> **本文件是索引与铁律，不是手册。** 操作手册正文在 `References/`（每篇都在 8,192 字符以内，可安全整篇读取）。
> **SDK 基线**：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。所有 API 陈述以此为准。
> ⚠️ **载入后先执行 §1**，再开始干活。

## 0. 与 DSH 内置 `dsh-doc` 的分工（两者并存，不是替代关系）

DSH 自带内置 skill **`dsh-doc`**（随 `@deepseek-ai/dsh-agent-preset` 发行；`standard` / `ptc` / `cordis` 三个 preset 都挂了它，**不是创作模式专属**）。分流：

| 场景 | 用哪个 |
|---|---|
| 查正在运行的 DSH 里某 Service / UI Slot 的**现役**签名；用现成工具管理**运行中 profile** 里的 bundle（`install_bundle`、启用停用、看 `application`/`warnings`）；连 MCP；写 agent preset | `dsh-doc`（创作模式下另有 `cordis_inspect_*` 活体探针） |
| **自己写/打包** bundle 与 `dsh plugin` 的安装语义、配置层顺序；离线 API 手册；可直接照抄的 TS 模板；跨版本「改了什么」累积清单；**非 DSH 宿主**（Claude Code / Codex / Cursor） | **本技能**（打包见 `07-publish.md` / `07b-publish-advanced.md`） |

理由、`dsh-doc` 的设计取舍与完整分流表见 `References/13-upgrade-guides.md` §3。

## 1. 载入后第一件事：检查本技能是否最新（强制）

本技能随 DSH 演进。用过期版本会写出**编译不过或语义不对**的插件。完整流程见 `References/15-self-update.md`，压缩版：

1. 读本目录 `VERSION`；**没有此文件**（残缺拷贝）视为旧版，直接执行第 3 步。
2. 取远端版本（一次几字节 GET，用 tag-pinned URL 绕开 raw.githubusercontent 的 CDN 滞后）：
   ```sh
   TAG=$(git ls-remote --tags --sort=-v:refname https://github.com/green-dalii/dsh-plugin-dev-skill.git | awk -F/ '/refs\/tags\/v/ {print $3; exit}')
   curl -fsSL --max-time 8 "https://raw.githubusercontent.com/green-dalii/dsh-plugin-dev-skill/${TAG}/VERSION" | tr -d '[:space:]'
   ```
3. 远端**更高** → 更新（git 检出 `git pull --ff-only`；纯拷贝 `git clone --depth 1` 后 `rsync -a --delete --exclude .git`），更新后**重新读 SKILL.md 与要用的 References**；**相同或本地更高** → 直接用（不降级）；**无法联网** → 明说「未能检查更新（原因）」后继续，别卡住。
4. 同一会话内远端未变则不必重查；**每次载入技能都要查一次**。

## 2. 铁律（违反其一即为缺陷）

1. **所有注册走 `ctx`**（`ctx.on` / `ctx.tools.register` / `ctx.effect` / `ctx.plugin` / `ctx.provide`）——卸载自动清理，**绝不手写 `removeListener` / `clearInterval`**。
2. **不经 `ctx` 管理的资源**（连接、定时器、句柄、watcher）必须包进 `ctx.effect(() => () => cleanup)`。
3. **依赖必须声明**（`inject`）：不用 `ctx.get()` 探测必需依赖；加载顺序由依赖决定，**不由 `cordis.yml` 行序决定**。
4. **配置必须可配置**：任何不同部署可能取值不同的参数都进 `Config`，绝无硬编码。检验标准——能否只改 `cordis.yml` 就改这个值？
5. **配置错误要响亮**：Schemastery schema 在加载时校验，非法配置直接失败，不带病运行。
6. **展示回调必须是纯函数**：`output.render` / `presentCall` / `presentResult` 会在实时流**与会话回放**中运行，不做 I/O、不读会话状态。
7. **工具返回规范值**：`execute` 返回 `output.schema` 声明的 JSON 值，人读文本归 `output.render`；不要返回内容块。
8. **waterfall 观察者必须 `next()`**；不调 `next()` 是「有意短路」，只属于拥有该决策的监听器。
9. **工具声明只能用 `when` 条件**：0.2.1-rc.2 起 `system-prompt/assemble` 不再携带工具数组，读 `assembly.tools` 会拿到 `undefined`。
10. **补丁整行替换 `config`**（不是深合并）：覆盖别层某行时，重述该行需要的**每一个**键。

## 3. 版本演进（细节见 `12b-migration-errors.md` 与 `13-upgrade-guides.md`）

| 版本 | 一句话 |
|---|---|
| 0.2.0 | 无特权内核定型；`ctx.codeRuntime`→`ctx.ptcRuntime`；删 `agent/session-start` 与 profile `patchReload`；去 E2B 改 SSH |
| 0.2.1-alpha.1~4 | 基本无公共 API 破坏；`engines.dsh` 优先于 peer、`peers`→`requirements`；`plugin_market` 加入 |
| 0.2.1-rc.1 ~ 0.2.2-alpha.2 | **大重构**：executor 拆成独立插件、工具声明改 `when` 准入、`agent/request` 不再公开、session 投影改异步 handle、`purpose` 改声明式 |
| 0.2.2-alpha.3 ~ **rc.3（基线）** | cordis **4.1.0**；错误契约重构（`dsh-error`、`LLM_FAILURE_CODES`、`ToolGuardDenial`、`ApprovalError`）；`Session.append` 批量重载；子代理全面具名；`ctx.officeKit` |

## 4. 索引：任务 → 读哪篇

下表路径均在 `References/` 下。

| 要做的事 | 读 |
|---|---|
| 建立 DSH / Cordis 心智模型 | `01-dsh-architecture.md` + `09-cordis-primer.md` |
| 写第一个插件（形态、inject、effect、生命周期、HMR） | `02-plugin-basics.md` |
| 写 Tool：`defineTool`、schema、后台任务、UI 卡片 | `03-tools.md` → `03b-tools-advanced.md` |
| 工具步骤准入 / PTC / executor 插件 | `03c-tools-pipeline.md` |
| 插件配置（Schemastery、设置页） | `04-config.md` |
| 写 LLM 适配器（StreamChunk、模型元数据） | `05-llm-adapter.md` |
| LLM 错误码、`LLM_FAILURE_CODES`、`fromFailure` | `05b-llm-errors.md` |
| 服务与依赖、`inject`、服务隔离 | `06-services.md` |
| 事件系统、分发模式、常用事件 | `06b-events.md` |
| 打包、安装进 profile、配置层顺序 | `07-publish.md` |
| git 安装坑、组合包作者六件事、重装与展示元数据 | `07b-publish-advanced.md` |
| 能力分层设计（Definition / Provider / Consumer） | `08-capability-layering.md` |
| 查某个 `ctx.*` seam 是什么角色 | `08b-seams-core.md` / `08c-seams-platform.md` |
| `ctx` 上到底有哪些 API | `09b-cordis-ctx-api.md` |
| 扩展模式与「功能 → 机制」映射 | `11-cookbook.md` |
| 通用错误对照自查 | `12-mistakes.md` |
| 版本破坏性变更对照 | `12b-migration-errors.md` |
| 升级指南原文索引、官方链接、与 `dsh-doc` 的分工 | `13-upgrade-guides.md` |
| 开发流程四阶段、覆盖范围边界（UI / Schedule / 子代理 / Web 搜索） | `14-workflow-and-scope.md` |
| 本技能自我更新流程（完整版） | `15-self-update.md` |
| 论文《A Programming Paradigm for Spatiotemporal Composability》解读 | `10-spatiotemporal.md` |

文件总览与**术语对照表**（上游重命名备忘，如 Code Mode → PTC mode、`CallId` → `ToolCallId`）见 `00-INDEX.md`。

## 5. 交付前自查

- [ ] 每个可调参数都在 `Config` 里，且 schema 能拒掉非法值
- [ ] 所有注册都在 `ctx` 上或包在 `ctx.effect()` 里；卸载后无残留监听
- [ ] 工具：`output.schema` 有规范值、`output.render` 是纯函数、`exec.signal` 被遵守
- [ ] 事件：选对事件域，waterfall 观察者都调了 `next()`
- [ ] 依赖写进 `inject`；去掉提供方后插件 `PENDING` 而非崩溃
- [ ] 怀疑与官方不一致 → 在仓库根跑 `bash scripts/verify.sh`（版本三处一致 + frontmatter 合法 + 官方链接 200；CI 也跑）
