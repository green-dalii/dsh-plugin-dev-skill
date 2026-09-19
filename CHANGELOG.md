# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [0.5.0] - 2026-09-19

### 新增

- **`llms.txt`**：面向 LLM 爬虫与答案引擎（GEO）的机器可读索引，用绝对 raw URL 指向 `SKILL.md`、`VERSION`、11 篇 `References/`、CHANGELOG 与上游资料，便于生成式引擎直接抓取与引用。
- **README 增加 FAQ（中英双语，9 问 9 答）**：DSH 是什么、不装技能能否写插件、能做出什么、哪些 Agent 能加载、内容是英文吗、适配哪个 DSH 版本、如何保持最新、能否让 Agent 自己安装、如何反馈错误。问题式小标题与具体答案（含版本号、目录名、命令）是 GEO 提取与引用的高价值结构。
- **README 增加「这是什么（以及不是什么）」**：明确实体边界（纯文档技能包、不是插件/库/分支、不增加运行时依赖），并声明适用的宿主与 SDK 基线——利于答案引擎准确归类。
- **README 增加目录（TOC）与「别称/检索关键词」**：补齐检索同义词（DSH 插件开发技能、DeepSeek Harness 插件开发、`dsh-plugin-dev-skill`）与站内锚点导航。

### 变更

- **README 标题与开篇重写（中英同步）**：H1 由 `Deepseek Harness Plugin Dev Skill` 改为 `DeepSeek Harness (DSH) Plugin Development Skill`（修正大小写、补齐「插件开发」关键词）；开篇首句改为「一个让任何 AI 编码 Agent 都能正确开发 DeepSeek Harness（DSH）插件的 Agent Skill」这一定义式陈述；「其他 Agent」章节更名为「在其他 Agent 宿主中使用（Claude Code、Codex）」并加锚点。
- **仓库元数据（GitHub）**：补充 description 与 topics，覆盖 `cordis`、`claude-code`、`codex`、`agent-skills-standard` 等检索词。

### 修复

- **`SKILL.md` §0.1 补健壮性**：本地缺少 `VERSION` 文件时（例如只拷贝了 `SKILL.md` 的残缺安装），不再无从判断——明确按「旧版本」处理并直接执行更新。

## [0.4.0] - 2026-09-19

### 新增

- **`VERSION` 文件**（单行版本号）与 `SKILL.md` frontmatter 的 `metadata`（`version` / `upstream` / `sdk-baseline`），作为更新检查的机器可读依据。
- **`SKILL.md` §0.1「载入后第一件事：检查 skill 是否最新」强制流程**：要求 Agent 每次载入本技能后先比对本机 `VERSION` 与远端 `VERSION`（`curl` 单个小文件、短超时，失败则回退 `git ls-remote --tags`），远端更高则**先更新再使用**：
  - 符号链接 / git 检出安装 → `git pull --ff-only`
  - 普通拷贝安装 → `git clone` + `rsync -a --delete`
  - 更新后**重新读取** `SKILL.md` 与相关 `References/`（API 与术语可能已变）
  - 无法联网时明确说明「未能检查更新」后继续，不阻塞、也不假装检查过；同一会话内可跳过重复检查
  - 顶部前言加了醒目提示，避免被略读跳过
- README（中英）新增「保持最新 / Keeping it up to date」小节：把**符号链接**列为推荐安装形态，并说明自动更新流程与降级保护（远端低于本地时不降级）。

### 变更

- **README 徽章列补充**（中英双语同步）：
  - 「更新日期」徽章（`updated-2026--09--19`，链接到本 CHANGELOG）
  - 「适配的 DeepSeek Harness 版本」徽章（`DeepSeek Harness-0.1.5--rc.2`，链接到官方仓库）
  - 「deepseek-harness」GitHub 仓库徽章（带 star 计数，链接到官方仓库）
  - 正文中的 **DeepSeek Harness（DSH）** 现链接到官方仓库 https://github.com/deepseek-ai/deepseek-harness
- **`CONTRIBUTING.md` 新增「同步与发布清单」**：列出每次同步官方更新/发版时需要一并更新的位置（`VERSION`、`SKILL.md` 的 `metadata` 与 SDK 基线、README 徽章日期与版本、`00-INDEX.md`、`CHANGELOG.md`、git tag），并强调三处版本号必须一致，否则更新检查失效；同时补充可直接复制的实测验证命令（`tsc --strict`、全量链接 200 检查、真实 skill 注册表加载）。

## [0.3.0] - 2026-09-19

对官方 DSH 文档与真实 SDK 做了全量复核（官方仓库自 0.1.0 起有大量更新），并据此修订全部内容。**SDK 基线：`@deepseek-ai/*` 0.1.5-rc.2（cordis 4.0.2）**。

### 修复

- **破坏性重命名同步**：
  - `Code Mode` / `code-mode` → **PTC mode** / `ptc`（SKILL.md、References/03、08、11）
  - `CallId` → **`ToolCallId`**（SKILL.md §2/§8、References/05）；旧名已从 `@deepseek-ai/dsh-llm` 删除，原示例代码在现行 SDK 下**无法编译**
  - `LlmError(..., 'UNSUPPORTED')` → `'UNSUPPORTED_OPTION'`（SKILL.md、References/05）
- **API 形状错误修正**：`ctx.waterfall(name, ...args, next)` → `ctx.waterfall(name, ...args)`（`next` 由分发器注入、只有监听器收到）；`bail` 补为同步方法且返回首个 bail 值；补 `waterfall` 有返回值、五种分发均有 `(thisArg, name, ...)` 重载。
- **删除不存在的 API**：`ctx.scope`（References/09）——作用域由 `@deepseek-ai/dsh-scope` 的 `createScope`/`scopeOf`/`scopeTarget` 承担。
- **卡片词汇收窄**：`presentCall` 仅 `'generic' | 'terminal' | 'diff'`；`'search' | 'web' | 'read'` 只属 `presentResult`（SKILL.md §4）。
- **嵌套 schema DSL 精确化**：参数属性 `required` 只能写 `true` 或省略（写 `false` 会类型报错）；object 节点必须显式声明 `additionalProperties` 且**没有 `required: [...]` 数组**（必填靠每个属性自己的 `required: true`）；补 `type: 'json'` 节点与 `oneOf` 至少 2 个分支。
- **失效链接修复**：`adding-a-conversation-node` 页已被上游移除（改指 `reference/subsystems/conversation`）；`defensive-patterns`、`event-producer-consumer`、`architecture`、`glossary` 等**未发布到文档站**（改指 GitHub 源码链接）；移除 404 的 `turtle-ui` 链接。
- 示例包引用修正：上游已退役 `dsh-acp-demo` / `dsh-sdk-jsonrpc-demo` / `dsh-agent-spine-demo`，改为现行 `dsh-acp-app`、`dsh-sdk-app` 等（References/11）。
- UI 插件模式更新：持久 `session/event` record + 瞬态 `agent/assistant-stream` frame；keyed renderer 注册键为 `conversation.chat.node`。

### 新增

- **PTC mode 完整语义**（References/03 §8）：`mode: native | ptc | both`；`ptc` 下 model-direct 调用只能写 `run_code`，程序内子分派才能调用全部可见工具；需要带 SDK 渲染器的 code runtime；`maxParallelSubCalls` 默认 10。
- **作用域过滤分发（scoped dispatch）与事件生产方契约**（References/06、References/09、SKILL.md §7）：`Scoped<Agent>` + `scopeTarget` carrier、祖先链向上流动、`{ global: true }` 逃生舱、注册表主体事件有意不过滤；生产方的 `@mode` 声明、监听器异常隔离、payload 只读且可无损 JSON、`emit`/`bail` 同步限制。
- **工具新增机制**：定义级运行时元数据 `timeoutMs` / `isConcurrencySafe`（只有精确 `true` 才并行）/ `finalizeContent`；`exec.deferContext()` / `exec.concludeTurn()`；`ctx.tools.presentAs()` 按作用域切换呈现；事件 `tools/ptc-dispatch-log`、`tools/change`。
- **配置**：校验是**同步**的（schema 返回 Promise 会抛 `TypeError: Async config validation is not supported`）；`Config` 可整体省略；校验失败以 `ValidationError` 停在 `FAILED`、`apply` 不执行；`ctx.settings.installSection()` 上 Web 设置页；HMR 的真实前提（`patchReload: live` + base 的 `hmr` 行默认 `disabled: true`、模块热替换需显式开启）。
- **打包发布**：`dsh --from-default-profile <template>` 与随附 profile 模板（`web`/`headless`/`sdk`/`sdk-minimal`/`acp`，保留名 `desktop`）；`dsh.profile.patchReload`；`--dump-default-config`；profile 目录第三个文件 `pnpm-workspace.yaml`；相对 spec 按调用目录锚定；组合包成员变化需重启；内置组合包**两级解析**与运行时依赖归属；已构建 tarball / 本地 checkout 不需要 `allowBuilds`。
- **LLM 适配器**：`StreamChunk` 分片全集（补 `reasoning-delta` 与 `finish` 的 `max-tokens`/`error`/`aborted`）、`TokenUsage` 计数互不重叠规则、`AdapterRegistrationHandle.replace()`、`registerConfigurableProviders()`/`registerModelDiscovery()`、`providerInfo()`/`listModels()`/`imageRequestPricing()`、`LlmFailure` 与规范错误码（`CONTEXT_WINDOW_EXCEEDED`/`QUOTA`/`EMPTY_RESPONSE`）、`@deepseek-ai/dsh-llm-retry` 策略、`streamIdleTimeoutMs`、`ReplayEnvelope`、提供方扩展注册表。
- 能力 seam 目录大幅扩充（覆盖约 82 个 `ctx.*` 服务），并区分**本地 0.1.5-rc.2 尚未出现**的上游 seam（References/08）。
- `ctx.skills` 补全发现根与 rank、kebab-case 命名、`<name>/SKILL.md` / `<name>.md`（不递归）、frontmatter 必填/可选键（References/08）。
- `References/00-INDEX.md` 新增**术语对照表**（上游重命名备忘）与「站点文档 vs 仓库文档」说明。
- 心智模型补「没有特权内核」（含 agent loop 可替换）、随附 profile 名录、三个事件域、步骤/轮次定义；能力分层补硬约束「Definition 必须是 Cordis `Service`，绝不能是 TS `interface`」。

### 变更

- **SKILL.md 顶部声明 SDK 基线**（0.1.5-rc.2 / cordis 4.0.2），并在相关位置标注上游文档领先于已发布 SDK 的差异（如 `ctx.codeRuntime` → `ctx.ptcRuntime`）。
- **README 新增「相关项目 / Related projects」章节**：`dsh-shift-router`、`pi-shift-router`、`GD4AI/obsidian-llm-wiki`、`obsidian-llm-wiki-cli` 的极简介绍（中英双语）。
- README 补全 skill 发现根（rank 300 `customSkillDirs`、500 `~/.agents/skills`、600 内置）与「发现不递归」说明。
- `References/11-cookbook.md` 的「可运行的组装示例」改写为当前上游口径（`packages/bundle/*/cordis.patch.yml` + 具名 profile）。

### 验证

- 全部模板对真实 `@deepseek-ai/*` 0.1.5-rc.2 通过 `tsc --strict` 类型检查（tool 基础/复杂/oneOf、config、service+consumer、typed events、LLM adapter）。
- 项目中 **44 个**官方文档站 / GitHub 源码 URL 全部实测 HTTP 200。
- 关键破坏性结论均以 SDK 类型定义与实现源码为证据（如 `CallId` 已不导出、`ctx.scope` 不存在、`bail` 为同步）。

## [0.2.0] - 2026-08-15

### 新增

- **README 新增“在其他 Agent 中使用”章节**：给出 Claude Code、Codex 等主流 Agent 的 skill 安装位置与用法，并推荐“直接把仓库地址告诉 Agent、由 Agent 自动克隆安装”的方式：
  - Claude Code：个人级 `~/.claude/skills/`、项目级 `.claude/skills/`，用 `/dsh-plugin-dev-skill` 调用或按描述自动加载
  - Codex CLI：用户级 `~/.agents/skills/`、仓库级 `.agents/skills/`，用 `/skills` 浏览、`$dsh-plugin-dev-skill` 提及
  - 说明本项目遵循开放 [Agent Skills 标准](https://agentskills.io)（`SKILL.md` + YAML frontmatter），任何兼容宿主均可直接加载；DSH 与 Codex 共用 `.agents/skills` 约定，一份拷贝两个宿主可用
  - 支持 git clone 直装与符号链接（两个宿主均支持 symlink，便于 git pull 更新）

### 修复

- **`SKILL.md` 补上 DSH 要求的 YAML frontmatter**：缺失 frontmatter 的 skill 会被 DSH 本地提供方忽略（`missing YAML frontmatter`）。现已添加 `name` / `description` / `whenToUse`（均为必填/受支持字段），并用真实 `dsh-skill` + `dsh-skill-filesystem` 注册表验证：`ctx.skills.list()` 能发现该技能、frontmatter 字段解析正确、`ctx.skills.get()` 能加载正文。
- **技能名与安装目录名一致**：frontmatter `name` 与文件夹名统一为 `dsh-plugin-dev-skill`（kebab-case），README 安装示例同步更新。

### 变更

- **README 双语化**：默认 README 改为英文（`README.md`），原中文说明移至 `README.zh-CN.md`；两个文件互相提供语言导航链接。

## [0.1.0] - 2026-08-14

### 新增

- **`SKILL.md`**：DeepSeek Harness 插件开发技能主文件（操作手册）：
  - 心智模型与 6 条铁律（可逆效应 / 反应式余效应 / fiber 生命周期）
  - 可直接照抄的代码模板：最小插件、Tool（`defineTool`）、配置（Schemastery）、服务与依赖、事件系统、LLM 适配器、后台任务、打包发布
  - Agent 分步开发流程（侦察 → 实现 → 验证 → 交付）与常见错误自查表
- **`References/`**：11 篇精简提炼参考文档 + 索引：
  - 架构总览、插件基础、工具开发参考、配置、LLM 适配器、服务与事件、打包发布、能力分层与 seam 目录、Cordis API 速查、时空可组合性论文解读、扩展模式 cookbook
  - 每篇均附官方文档 URL，便于官方更新后修订
- **`README.md`**：项目说明、结构、使用方式、作为 DSH 技能安装的步骤
- **`LICENSE`**：MIT
- **`CONTRIBUTING.md`**：贡献指南
- **`SECURITY.md`**：安全政策
- **`.gitignore`**：macOS / Node.js / 编辑器 / DSH 运行时产物忽略规则

### 验证

- 技能内所有 TypeScript 模板通过 `tsc --strict` 对真实 `@deepseek-ai/*` 类型定义的类型检查
- 端到端运行验证通过（真实 Cordis loader + `dsh-tools`）：
  - 工具注册/执行、参数运行时校验（`isError`）、`tools/result` 事件
  - 服务提供方/消费方注入、缺失依赖时 PENDING 不崩溃
  - 配置 schema 校验失败时给出明确 `ValidationError`
