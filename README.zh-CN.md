# DeepSeek Harness (DSH) 插件开发技能

[English](README.md) | **简体中文**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Updated](https://img.shields.io/badge/updated-2026--11--15-informational)](CHANGELOG.md)
[![DeepSeek Harness](https://img.shields.io/badge/DeepSeek%20Harness-0.2.2--rc.3-blue)](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.2-rc.3)
[![Skill version](https://img.shields.io/badge/skill-0.9.0-brightgreen)](VERSION)
[![deepseek-harness on GitHub](https://img.shields.io/github/stars/deepseek-ai/deepseek-harness?logo=github&label=deepseek-harness)](https://github.com/deepseek-ai/deepseek-harness)
[![Docs](https://img.shields.io/badge/Docs-DeepSeek%20Harness-blue)](https://deepseek-harness.github.io/deepseek-harness/develop/basic/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**一个让任何 AI 编码 Agent 都能正确开发 [DeepSeek Harness（DSH）](https://github.com/deepseek-ai/deepseek-harness) 插件的 Agent Skill**——高效、符合官方规范。

加载 [`SKILL.md`](SKILL.md)，Agent 即可获得分流规则、10 条铁律、版本演进摘要、任务→文件路由表与交付前自查；操作手册正文在 [`References/`](References/00-INDEX.md) 下的 **25 篇文档**里，**每篇都压在 8,192 字符以内**，以便完整穿过 DSH 的 tool-result 剪枝。

**别称 / 检索关键词**：DSH 插件开发技能、DeepSeek Harness 插件开发、`dsh-plugin-dev-skill`。

## 目录

- [为什么需要这个技能](#为什么需要这个技能)
- [你能得到什么](#你能得到什么)
- [三步上手](#三步上手)
- [结构](#结构)
- [自检能力](#自检能力)
- [安装](#安装)
  - [作为 DSH 技能](#作为-dsh-技能)
  - [在其他 Agent 宿主中使用（Claude Code、Codex）](#在其他-agent-宿主中使用claude-codecodex)
- [常见问题（FAQ）](#常见问题faq)
- [资料来源](#资料来源)
- [相关项目](#相关项目)
- [贡献](#贡献)
- [许可](#许可)

## 为什么需要这个技能

写一个 DSH "Hello World" 插件只需一行。但要写出**正确的**插件——`defineTool` 输出契约遵守、可逆效应替代手工清理、`inject` 依赖语义、Standard Schema 配置校验、事件分发模式选型、真正能装上车的打包——才是本技能编码的内容。

技能**基于第一性原理**：每条铁律都基于底层框架 Cordis 的学术基础（[arXiv:2608.25512](https://arxiv.org/abs/2608.25512)），并把这些原理落地成可直接照抄的代码模板。每条 API 陈述都对照真实 SDK 类型在声明基线（`@deepseek-ai/*` 0.2.2-rc.3、cordis 4.1.0）实测过；模板在撰写时已对照该基线校验，但**不在 CI 中做类型检查**——DSH SDK 不是公开 npm 包。

## 你能得到什么

- **心智模型先行**：Cordis「可逆效应 + 反应式余效应」理论，凝练成 10 条任何插件作者都必须遵守的铁律。
- **覆盖五类插件面**：`tool`（`defineTool`）、`llm`（adapter）、`service`（definition + provider + consumer）、`event`（dispatch modes）、`bundle`（profile + manifest + Plugin Manager）。
- **模板经过真实 SDK 类型校验**：代码样例在撰写时对照基线 SDK 校验过，且就是维护者自己使用的那几段。
- **自带自检**：附带 [`scripts/verify.sh`](scripts/verify.sh)——一行基线复核（版本一致性 + README 徽章交叉核对 + frontmatter 合法性 + 上游 URL 存活 + 阅读预算与索引完整性），项目自身的 CI 在每次 push 上都会跑它。
- **Tag-pinned 更新检查**：见 `SKILL.md` §1 与 [`AGENTS.md`](AGENTS.md) 「Mandatory flow on entry」。
- **可追踪上游**：每个主题的官方文档 URL 收在该主题最后一篇的末尾（拆分出来的各部分互相指向）。

Agent 介入仓库时的约定（加载、检查、不能动哪些文件）见 [`AGENTS.md`](AGENTS.md)。

## 三步上手

1. **安装**本技能（推荐符号链接——见 [安装](#安装)）。
2. **打开** `SKILL.md`；Agent 会自动跑 §1 的更新检查并提示是否有新版本。
3. **照着** [`References/14-workflow-and-scope.md`](References/14-workflow-and-scope.md) §1 的四阶段流程（侦察 → 实现 → 验证 → 交付）走。
4. **Agent 写工具时**：用 [`References/03-tools.md`](References/03-tools.md) §1 里的 `defineTool` 模板（整段照抄，只需改四个字段 `name` / `description` / `parameters` / `output.schema`）。
5. **发版或提 PR 前**：跑 `bash scripts/verify.sh`——绿灯意味着版本、frontmatter 与所有上游链接都一致。

## 结构

```
dsh-plugin-dev-skill/
├── SKILL.md                     # 索引层：分流规则、铁律、任务→文件路由（≤ 8192 字符）
├── VERSION                      # 技能版本号；SKILL.md §1 要求载入时检查它
├── AGENTS.md                    # CLI Agent 自动读取的约定文件
├── README.md                    # 英文说明（默认）
├── README.zh-CN.md              # 本文件（中文说明）
├── CHANGELOG.md                 # 变更日志
├── CONTRIBUTING.md              # 贡献指南
├── SECURITY.md                  # 安全政策
├── LICENSE                      # MIT
├── References/                  # 操作手册正文（25 篇，每篇 ≤ 8192 字符）
│   ├── 00-INDEX.md              # 文件总览、SDK 基线、上游重命名术语对照
│   ├── 01-dsh-architecture.md   # DSH 架构：CLI、profile/bundle、配置层、插件加载
│   ├── 02-plugin-basics.md      # 插件形态、运行时与包地图、inject/effect、Fiber、HMR
│   ├── 03-tools.md              # 工具基础：defineTool、execute 契约、schema 词汇
│   ├── 03b-tools-advanced.md    # 后台任务、执行策略、UI 卡片
│   ├── 03c-tools-pipeline.md    # 步骤准入（when）、PTC mode、executor 插件
│   ├── 04-config.md             # 插件配置与 Schemastery
│   ├── 05-llm-adapter.md        # LLM 适配器：StreamChunk 协议、GenerateOptions、注册
│   ├── 05b-llm-errors.md        # LLM 失败码、retryChoice、fromFailure、pi-ai 1.3.0
│   ├── 06-services.md           # 服务与依赖：消费方/提供方、服务隔离
│   ├── 06b-events.md            # 事件系统、分发模式、常用 Harness 事件
│   ├── 07-publish.md            # 打包、安装、profile、配置层顺序
│   ├── 07b-publish-advanced.md  # git 安装坑、表层组合包、组合包作者六件事
│   ├── 08-capability-layering.md# 三种角色能力设计
│   ├── 08b-seams-core.md        # 能力 Seam 目录（一）：核心服务
│   ├── 08c-seams-platform.md    # 能力 Seam 目录（二）：平台与 UI
│   ├── 09-cordis-primer.md      # Cordis 入门：概念、分发、Service、Fiber、Loader
│   ├── 09b-cordis-ctx-api.md    # ctx API 速查
│   ├── 10-spatiotemporal.md     # 论文解读（时空可组合性）
│   ├── 11-cookbook.md           # 扩展模式（钩子/UI/协议桥/功能→机制）
│   ├── 12-mistakes.md           # 通用错误与修正（与版本无关）
│   ├── 12b-migration-errors.md  # 版本迁移错误（破坏性变更对照）
│   ├── 13-upgrade-guides.md     # 升级指南索引、官方链接、与 dsh-doc 的分工
│   ├── 14-workflow-and-scope.md # 开发流程四阶段 + 覆盖范围边界
│   └── 15-self-update.md        # 本技能的自我更新流程
├── scripts/
│   └── verify.sh                # 基线复核（版本/frontmatter/链接/字符预算），CI 在每次 push 上跑
└── .github/workflows/ci.yml     # GitHub Actions：verify.sh + 上游 release 信号
```

## 自检能力

`scripts/verify.sh` 是本项目自身的质量门。它检查四件事：

1. **版本一致**：`VERSION`、SKILL.md frontmatter `metadata.version`、最新 CHANGELOG 标题三者必须相等；README 徽章另做交叉核对——`skill-<ver>` 对 `VERSION`，SDK 徽章里的 release tag 对 `metadata.sdk-baseline`。
2. **SKILL.md frontmatter 合法**：`name` 必须是 kebab-case（`^[a-z0-9]+(?:-[a-z0-9]+)*$`）；`description` 与 `metadata.{version, upstream, sdk-baseline}` 必须存在。
3. **上游 URL 存活**：`*.md` 内所有指向 `deepseek-harness.github.io`、`github.com/deepseek-ai/`、`github.com/cordiverse`、`arxiv.org`、`registry.npmjs.org` 与 `raw.githubusercontent.com` 的 URL 必须返回**恰好 `200`**。CDN 临时 `000` 会重试两次才判失败。
4. **阅读预算与索引完整性**：`SKILL.md` 与每个 `References/*.md` 不超过 **8,192 字符**——即 `compaction-tool-result-pruner` 的阈值（`thresholdChars: 8192`、`headChars: 4096`、`tailChars: 1024`，`standard` / `ptc` / `cordis` 三个 preset 相同）。技能是通过 tool result 送达模型的，超过这条线就会在上下文压缩时丢掉中间部分。同一项检查还会验证 `SKILL.md` 恰好路由到 `References/` 中实际存在的文件。

macOS bash 3 兼容；支持 `SKIP_FRONT=1` / `SKIP_VERSION=1` / `SKIP_URLS=1` / `SKIP_BUDGET=1` 局部跳过。

```sh
bash scripts/verify.sh   # 绿灯退出 0；任何漂移退出 1
```

## 安装

### 作为 DSH 技能

DSH 的 skill 系统接受「目录包（`<name>/SKILL.md`）」或「平铺 Markdown（`<name>.md`）」两种形态；发现**不递归**（刻意不支持 `**/SKILL.md`）。本地发现根目录按优先级：

| 根目录 | 适用场景 |
|---|---|
| `<项目根>/.dsh/skills` | 项目级（rank 100） |
| `<项目根>/.agents/skills` | 项目级（rank 200） |
| `customSkillDirs`（宿主配置） | 宿主指定（rank 300） |
| `$DSH_HOME/skills`（即 `~/.dsh/skills`） | 用户级（rank 400） |
| `$DSH_HOME/../agents/skills`（即 `~/.agents/skills`） | 用户 agents 目录（rank 500） |
| 内置技能目录 | 随 DSH 发行（rank 600） |

例如安装为用户级技能：**安装目录名必须与 SKILL.md frontmatter 中的 `name` 一致**（`dsh-plugin-dev-skill`），且需符合 kebab-case：

```sh
# 推荐：符号链接到 git 检出，之后一句 git pull 即可保持最新
git clone https://github.com/green-dalii/dsh-plugin-dev-skill.git ~/src/dsh-plugin-dev-skill
ln -s ~/src/dsh-plugin-dev-skill ~/.dsh/skills/dsh-plugin-dev-skill

# 或者：普通拷贝（更新时需要重新拷贝）
mkdir -p ~/.dsh/skills/dsh-plugin-dev-skill
cp SKILL.md VERSION ~/.dsh/skills/dsh-plugin-dev-skill/
cp -r References ~/.dsh/skills/dsh-plugin-dev-skill/References
```

**保持最新**：本技能自带 [`VERSION`](VERSION)，并在 `SKILL.md` §0.1 要求 Agent **载入后的第一件事就是检查是否有新版本**——`git ls-remote --tags` 取最新发布 tag，再读 `${TAG}/VERSION`（tag 钉死，避开 `main` 分支 CDN 缓存延迟），做语义化比较；若远端更新则先更新（符号链接/git 检出走 `git pull`；普通拷贝走重新 clone + `rsync`），**更新完再使用本技能**。推荐的安装形态就是上面的**符号链接**：一句 `git pull` 就地把已加载的技能更新掉；DSH 会跟随符号链接的技能目录（`watchFollowSymlinks` 默认开启），Claude Code 与 Codex 同样支持。如果无法检查（离线、无网络、无写权限），Agent 应明确说明「未能检查更新」，并基于本地版本继续，而不是假装检查过。

### 在其他 Agent 宿主中使用（Claude Code、Codex）

本技能遵循开放的 [Agent Skills 标准](https://agentskills.io)：一个包含 `SKILL.md` 与 YAML frontmatter（`name` / `description` / `whenToUse`）及配套 `References/` 目录的文件夹——与 Claude Code、Codex 及众多 Agent 宿主使用的形态一致，凡是支持 Agent Skills 的地方都可以安装。

**方式 A：让 Agent 自己安装（推荐）**——直接把仓库地址告诉它，让它自行克隆安装。例如在 Claude Code 会话里粘贴：

> 请把 https://github.com/green-dalii/dsh-plugin-dev-skill 这个技能安装到 `~/.claude/skills/dsh-plugin-dev-skill/`，之后我处理 DeepSeek Harness 插件开发时加载 `SKILL.md`。

或者在 Codex CLI 会话里粘贴：

> 请把 https://github.com/green-dalii/dsh-plugin-dev-skill 这个技能安装到 `~/.agents/skills/dsh-plugin-dev-skill/`。

通用说法（适用于任何 Agent）：

> 请把 https://github.com/green-dalii/dsh-plugin-dev-skill 安装到你的技能目录（文件夹 `dsh-plugin-dev-skill`，内含 `SKILL.md` 与 `References/`），当任务涉及开发 DeepSeek Harness（DSH）插件时使用它。

**方式 B：手动安装**

| Agent / 宿主 | 安装位置 | 调用方式 |
|---|---|---|
| Claude Code（个人级） | `~/.claude/skills/dsh-plugin-dev-skill/SKILL.md` | `/dsh-plugin-dev-skill`，或描述匹配时自动加载 |
| Claude Code（项目级） | `<仓库>/.claude/skills/dsh-plugin-dev-skill/SKILL.md` | 同上 |
| Codex CLI（用户级） | `~/.agents/skills/dsh-plugin-dev-skill/SKILL.md` | `/skills` 浏览，`$dsh-plugin-dev-skill` 提及 |
| Codex CLI（仓库级） | `<仓库>/.agents/skills/dsh-plugin-dev-skill/SKILL.md` | 同上 |
| DSH | `~/.dsh/skills/dsh-plugin-dev-skill/SKILL.md` | 见上方[作为 DSH 技能](#作为-dsh-技能) |
| 任意 Agent Skills 宿主 | `<技能目录>/dsh-plugin-dev-skill/SKILL.md` | 按宿主说明 |

```sh
git clone https://github.com/green-dalii/dsh-plugin-dev-skill.git ~/.claude/skills/dsh-plugin-dev-skill
# 或改为符号链接：
ln -s /path/to/dsh-plugin-dev-skill ~/.claude/skills/dsh-plugin-dev-skill
```

注意事项：

- 文件夹名请保持 `dsh-plugin-dev-skill`——必须与 frontmatter 中的 `name` 一致（Claude Code 会用它作为命令名）。
- 不支持的宿主会忽略 `whenToUse` 等扩展 frontmatter 字段，不影响加载。
- 彩蛋：DSH 同样读取项目级 `.agents/skills`，所以在 `<仓库>/.agents/skills/dsh-plugin-dev-skill/` 放一份，Codex 与 DSH 可以共用。

## 常见问题（FAQ）

### DeepSeek Harness（DSH）是什么？

DeepSeek Harness 是一个 Agent Harness SDK：其中每一项能力——工具、LLM 适配器、文件访问、沙箱、持久化，乃至 **agent loop 本身**——都是挂载到共享上下文上的插件。它没有「特权内核」可供打补丁，扩展方式就是挂载插件。上游仓库：[deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)；官方文档：[deepseek-harness.github.io](https://deepseek-harness.github.io/deepseek-harness/develop/basic/)。

### 不装这个技能就不能写 DSH 插件吗？

能写。最小插件只是一个导出 `apply(ctx)` 函数的模块，官方文档也讲了。本技能的价值在于**一次写对**：`defineTool` 的规范输出契约、用可逆效应替代手工清理、`inject` 的依赖语义、Standard Schema 配置校验、事件分发模式选型，以及真正能装上车的打包方式。

### 用它可以做出什么？

用 `defineTool` 注册的工具、LLM 适配器（`LlmAdapter.stream()`）、服务定义/提供方/消费方、监听 `tools/*` 与 `agent/*` 的钩子插件、UI 插件、协议桥（ACP、SDK）、后台任务，以及可发布的组合包与 profile。

### 哪些 Agent 能加载它？

任何实现 Agent Skills 标准的宿主，包括 DSH（项目级与用户级技能目录）、Claude Code（`~/.claude/skills/`）与 Codex CLI（`~/.agents/skills/`）——详见[安装](#安装)。

### 技能内容是英文的吗？

技能正文（`SKILL.md`）与参考资料以**中文**撰写（与官方 DSH 文档一致）；代码模板、API 名与命令行与语言无关。README 提供英文与中文两个版本。

### 它适配哪个 DeepSeek Harness 版本？

`@deepseek-ai/*` **0.2.2-rc.3** 与 cordis **4.1.0**——所有 API 陈述都是对该版本实测验证的。自 0.2.0 以来的关键变化：`ctx.codeRuntime` → `ctx.ptcRuntime` 改名、Plugin Manager 随发行版交付、E2B 系移除改由 SSH 家族接管；0.2.1-rc.1 ~ 0.2.2-alpha.2 是一次大重构（executor 插件、`when` 步骤准入）；0.2.2-rc.3 重构错误契约（`@deepseek-ai/dsh-error`、`LLM_FAILURE_CODES`）。完整差异见 [`CHANGELOG.md`](CHANGELOG.md) 与 [`References/12b-migration-errors.md`](References/12b-migration-errors.md)。

### 如何保持最新？

推荐把技能安装为指向 git 检出的**符号链接**，`git pull` 即可就地把已加载的技能更新掉。此外，技能在**每次载入时会检查自身版本**：把本机 `VERSION` 与最新发布 tag 比对，若有新版本则先更新再使用（`SKILL.md` §1）。远端检查只取一个极小的文件，离线时会优雅降级。

### 可以让 Agent 自己安装吗？

可以。把仓库地址告诉 Agent，让它把技能装进自己的技能目录即可——可直接复制上文[方式 A](#在其他-agent-宿主中使用claude-codecodex) 里的提示词。

### 发现 API 写错或链接失效怎么办？

欢迎开 Issue 或 PR——见 [CONTRIBUTING.md](CONTRIBUTING.md)。每个主题的官方文档 URL 收在该主题最后一篇的末尾，便于核对并修正上游漂移。

## 资料来源

- 官方文档站（中文/英文）：https://deepseek-harness.github.io/deepseek-harness/develop/basic/
- 源码仓库：https://github.com/deepseek-ai/deepseek-harness
- 最新 tag 发布：https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.2-rc.3
- 论文：《A Programming Paradigm for Spatiotemporal Composability》（Cordis 框架的学术基础，arXiv:2608.25512）：https://arxiv.org/abs/2608.25512

所有参考文档均为**精简提炼**（不是官方文档照搬），以「开发出正确、高效、符合规范的插件」为目标组织。

## 相关项目

同一作者的其它项目：

| 项目 | 简介 |
|---|---|
| [`green-dalii/dsh-shift-router`](https://github.com/green-dalii/dsh-shift-router) | **DSH 的双层模型路由器**：LLM Judge 路由、多模型回退链、指数退避的运行时故障转移，以及任务级编排。同时也是一个按本技能所讲规范构建的真实 DSH 插件实例。 |
| [`green-dalii/pi-shift-router`](https://github.com/green-dalii/pi-shift-router) | `dsh-shift-router` 所改编的原版 Pi coding-agent 扩展：由 LLM judge 把每一轮 agent 交给合适的模型——例行工作走快速执行，难题走强推理——并带多模型故障转移。[主页](https://shiftrouter.greenerai.top) |
| [`GD4AI/obsidian-llm-wiki`](https://github.com/GD4AI/obsidian-llm-wiki) | Obsidian 社区插件（id `karpathywiki`），实现 Karpathy 的 LLM Wiki：把笔记与 PDF 变成互相链接的 LLM 知识库——实体页/概念页、图驱动的问答、本地优先隐私。[主页](https://llmwiki.greenerai.top) |
| [`green-dalii/obsidian-llm-wiki-cli`](https://github.com/green-dalii/obsidian-llm-wiki-cli) | 无头摄取 CLI（npm [`karpathywiki-cli`](https://www.npmjs.com/package/karpathywiki-cli)，`llm-wiki` 可执行文件）：在 Node 下直接跑插件生产环境的 `WikiEngine`，不需要 Obsidian 渲染器、零 `obsidian` 导入。 |

## 贡献

欢迎提交 Issue 与 PR！请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全相关问题见 [SECURITY.md](SECURITY.md)。提 PR 前先本地跑 `bash scripts/verify.sh`——CI 也会跑一遍。

## 许可

[MIT](LICENSE) © 2026 green-dalii
