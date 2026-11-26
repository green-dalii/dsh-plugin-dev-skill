# 13 · 升级指南索引、官方链接与 dsh-doc 分工

> SDK 基线：`@deepseek-ai/*` **0.2.3-alpha.2**（cordis **4.2.0-alpha.1**）。

> 本文件收录三类「本技能之外」的信息：① 上游升级指南原文在哪、哪些篇与本技能相关；② 官方文档入口；
> ③ 上游内置 skill **`dsh-doc`** 与本技能的分工（**重要：两者并存，不是替代关系**）。
> 哪些版本改了什么，见 `12b-migration-errors.md` 与各篇 References；本文件只负责「去哪读原文」。

## 0. 官方文档入口

- 开发者第一步：https://deepseek-harness.github.io/deepseek-harness/develop/basic/ （中文）/ `/en/develop/basic/`（英文）
- 服务与 seam 全局视图：https://deepseek-harness.github.io/deepseek-harness/reference/capability-seams
- 文档站只发布 `develop/**`、`guide/**`、`reference/**` 与部分 `reference/subsystems/*`（已确认有 `ptc-runtime`、`schedule`、`approval` 等）；`glossary`、`event-producer-consumer`、`defensive-patterns` 以及多数 `subsystems/**` 页面**只在 GitHub 仓库里**，本目录各篇已在相应位置给出仓库链接。

## 1. 上游升级指南

> **不要依赖篇数**：`docs/upgrade-guide/v<T>/` 的篇数在补丁版本之间会变（guide 目录按「离开的版本」命名，`vT/` 描述的是从 vT 升到下一个版本）。**以遍历目录得到的实际篇目为准**，本文件只给稳定的篇名线索。

### 0.2.0-rc.2
0.2.0-rc.2 升级指南（含 `remove-runtime-invariants`、`subpath-plugin-display-manifest`、`schedule-bundle-retired`、`account-sign-in-errors`）：仓库内 `docs/upgrade-guide/v0.2.0-rc.2/`（文档站尚未发布索引页）。

### 0.2.1-alpha.2 ~ alpha.4
0.2.1-alpha.2 ~ alpha.4 升级指南（推荐关注的与插件开发相关的：`plugin-engines-dsh` / `plugin-install-over-installed` / `sdk-minimal-image-compaction` / `stored-credentials-precedence` / `pi-ai-model-discovery`；其余如 Azure route、DeepSeek 账户、Desktop 快捷键、AccountBonusNotification 不影响插件开发）：https://github.com/deepseek-ai/deepseek-harness/tree/master/docs/upgrade-guide （按子目录 `v0.2.1-alpha.{2,3,4}/<name>/guide.md` 打开）。关键改动已经并入 `12b-migration-errors.md` 与对应 References 篇目。

### 0.2.1-rc.1 ~ 0.2.2-alpha.2
**0.2.1-rc.1 ~ 0.2.2-alpha.2 升级指南**：同样在 `docs/upgrade-guide/` 下，按子目录 `v0.2.1-rc.{1,2,3,4}/` 与 `v0.2.2-alpha.2/` 打开。**与插件开发直接相关的一批**（以目录为准，下列为稳定篇名）：`conditional-tools` / `tool-executor-plugins` / `subagent-control-tools` / `session-projection-handles` / `session-store-writes` / `attachment-read-access` / `llm-request-purpose-declarations` / `schedule-agent-tools` / `schedule-remote-host-tasks` / `ptc-script-format` / `ptc-caller-cancellation` / `web-fetch-private-destinations` / `webserver-index-peer` / `official-bundle-lists` / `approval-projection-dependency` / `independent-session-forks` / `pi-ai-protocol-replay` / `pi-ai-model-catalog` / `context-menu-services` / `context-menu-target` / `file-drag-callbacks` / `web-file-downloads` / `model-listing-refresh` / `reasoning-body-props` / `model-badge-package-removal`。关键改动已经并入 `12b-migration-errors.md` 与 `03c`/`05b`/`06b`/`07*` 等篇目。

### 0.2.2-alpha.3 ~ 0.2.2-rc.3（0.9.x 旧基线）
**0.2.2-alpha.3 ~ 0.2.2-rc.3 升级指南（0.9.x 旧基线的主要来源）**：按 `docs/upgrade-guide/v0.2.2-alpha.3/` 与 `docs/upgrade-guide/v0.2.2-rc.1/` 打开。**与插件开发直接相关的 9 篇**：`office-kit-package`（`ctx.officeToPdf` → `ctx.officeKit`）/ `subagent-names`（工具按名寻址、`list_agents` 改形、catalog v3）/ `attachment-error-codes`（`AttachmentError` 改继承 `HarnessError`，工具与模型请求失败保留 `ATTACHMENT_*` 码）/ `plugin-update-method`（`BundleInfo.updatable` → `update`）/ `session-append-overloads`（`Session.append` 双重重载）/ `terminal-backend-cleanup-error`（`CLEANUP_FAILED`）/ `runtime-context-reminders`（`<system-reminder>` 包装与 `source.sections`）/ `web-search-billing`（DeepSeek Search API 计费与凭据来源）/ `dsh-doc-skill`（Creator mode 四技能合并为 `dsh-doc`）。其余（`cua-*`、`forge-*`、`account-*`、`archive-worktrees`、`window-drag-regions`、`terminal-bundle-sidebar-backend`、`office-operation-tools`、`office-skill-resources`、`chat-process-activity-context`、`subagent-interrupt-default`）属 UI / CUA / 账户 / 计划任务宿主侧，未进本技能正文。

### 0.2.2-rc.4 ~ 0.2.3-alpha.2（当前基线）
**升级指南**：按 `docs/upgrade-guide/v0.2.2-rc.3/`、`v0.2.2-rc.4/`、`v0.2.2-rc.5/`、`v0.2.3-alpha.1/` 打开（目录按「离开的版本」命名；alpha.2 标签无独立目录）。共 **40 篇**，其中 **31 篇与插件开发相关**：

- **rc.3 目录（22 篇，16 篇相关）**：`cordis-inspect-tool` / `cordis-loader-entry-validation` / `action-card-blocks` / `create-worktree-tool-merged` / `working-directory-tool-removed` / `deepseek-request-auth` / `deepseek-file-policy` / `deepseek-refusal-code` / `profile-context-overlay-paths` / `ptc-mcp-image-values` / `ptc-output-limit` / `ptc-tool-result-inspection` / `session-fork-source` / `subagent-initial-task-source` / `subagent-model-selection-live-setting` / `upstream-skills-base-row`。
- **rc.4 目录（3 篇，全相关）**：`web-search-deepseek-model-default` / `workspace-write-boundary-follows-root` / `forge-rate-limited-failure`（仅边界摘要）。
- **rc.5 目录（14 篇，11 篇相关）**：`compaction-summary-preview` / `independent-action-cards` / `list-agents-capacity` / `office-single-skill` / `personalized-recommendations-bundle-retired` / `pi-image-resize-defaults` / `ptc-default-scoped-repl` / `sdk-prompt-time-zone` / `session-query-inspect-session-removed` / `system-prompt-integrations` / `archive-worktrees-without-sandbox-policy`。CUA 三篇（`cua-activity-helper` / `cua-held-inputs` / `cua-system-input`）属宿主内部。
- **0.2.3-alpha.1 目录（1 篇）**：`node-24-22-3`。

关键改动已并入 `12c-migration-errors.md` 与 `03d` / `04` / `05*` / `07b` / `08*` / `11` / `14` 等篇目。Client/Web UI 的 `client-hmr-plugin-events-stream` / `session-panel-entries` / `session-retain-conversation-facet` / `settings-section-plugins-page` 按设计决策保持 SKIP。

## 2. ⚠️ 陷阱：`master` 分支的指南超前于发布标签（历史教训）

`master` 分支的 `docs/upgrade-guide/v0.2.2-rc.2/` 以及部分后补的 rc.1 篇目（`cordis-root-and-intercept-metadata`、`python-ptc-removal`、`ptc-bootstrap-protocol`、`ptc-scoped-repl-default`、`ptc-inspect-output`、`shell-fs-tool-error-codes`、`experimental-tool-error-codes`、`package-export-cleanup` 等）在 **rc.3 标签里并不存在**，其内容也未落到 rc.3 代码（当时逐条用源码验证：cordis 4.1.0 仍有 `ctx.root` / `Service.config` / `Service.resolveConfig`；rc.3 仍有 experimental Python PTC 与 `jsonSchemaToPy`；`PROGRAM_PROTOCOL_VERSION` 仍为 2；`PtcProgramFormat` 仍无 `scoped-repl`）。**所以 0.9.x 基线没有提前跟进它们。**

本次升基线到 `dsh-v0.2.3-alpha.2` 后，PTC 相关已落地：`PtcProgramFormat` 现含 `scoped-repl`、bootstrap 协议升 5。来源是两个**不同**变更——`v0.2.2-rc.1/ptc-scoped-repl-default`（只翻 `persistent-in-memory` 条目的 `replScoped` 默认）与 `v0.2.2-rc.5/ptc-default-scoped-repl`（把默认 `executionMode` 翻成 `persistent-in-memory`），勿混为一谈。其余篇目是否已落地仍按下方方法逐条判断，**不要因为 master 上有 guide 就写进手册**。

> 判断方法：拿不准某篇指南是否已落地时，**去 tag 对应的源码里 grep 该 API 是否存在**，而不是看 `master` 上有没有这篇 guide。

## 3. 与上游内置 skill `dsh-doc` 的分工

DSH 自 0.2.2-rc.1 起把四个创作类 skill（含 `cordis-plugin-development`）合并成单个 **`dsh-doc`**，随 `@deepseek-ai/dsh-agent-preset` 发行，位于 `skills/dsh-doc/`。

**它不是创作模式专属**：`skill-filesystem` 的 `customSkillDirs` 指向该目录，而 `standard` / `ptc` / `cordis` 三个 preset 都挂了 `skill-filesystem`。**创作模式**（preset id `cordis`）比标准模式多出来的只有两样：改写过的 persona，以及 `@deepseek-ai/dsh-tool-cordis` 提供的**只读**运行时探针 **`cordis_inspect`**（0.2.2-rc.4 起由原 `cordis_inspect_list` / `cordis_inspect_query` 合并而来）。

**`dsh-doc` 是路由层，不是手册。** 它的 `SKILL.md` 只有 41 行、约 4.6 KB，知识来源优先级为：运行时探针 → 装机文档（`$DSH_INSTALL_DIR/docs/`）与包源码 → 两者都拿不到时明说「未验证」。**上游是有意不写 API 的**：技能正文超过 **8192 字符**会被 tool-result pruner 砍到只剩首尾，所以它把细节全放在 `references/`（单篇 `packages.md` 就有 44 KB）里按需读取。本技能的 SKILL.md 也遵守同一条预算。

| 你要做的事 | 用哪个 |
|---|---|
| 查一个正在运行的 DSH 里某个 Service 的**现役**方法/事件签名 | `dsh-doc`（`cordis_inspect`，活体权威） |
| 装一个 bundle 进 profile、看 `application`/`warnings`、在新会话里验证 | `dsh-doc`（`install_bundle` 全生命周期比我方详细） |
| 写 Web Client / UI 插件（slots、theme token、chat row、图标与详情页） | `dsh-doc`（本技能**明确不做 UI**） |
| 连 MCP server、写 agent preset | `dsh-doc` |
| 离线查 API 手册、要能直接照抄的 TS 模板 | **本技能** |
| 想知道「从哪个版本起改了什么」的累积清单 | **本技能**（`12b-migration-errors.md`） |
| 在 Claude Code / Codex / Cursor 等**非 DSH 宿主**里改 DSH 插件 | **本技能**（`dsh-doc` 依赖装机路径与探针，换宿主不可用） |
| 需要一份 seam 全景图 / capability 分层设计模式 | **本技能**（`08*`） |

> 两者装在同一台机器上并不冲突，技能目录里会同时出现两个条目；按上表分流即可。

## 4. 其它入口

PTC 运行时子系统（自 0.2.1-alpha.1 起从 `code-runtime` 改名）与 Claude Code Mods 兼容层（0.2.1-alpha.1 新增的实验性 bridge，**仅仓库**）：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/ptc-runtime 与 https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/claude-code-mods.md 。

- 源码仓库：https://github.com/deepseek-ai/deepseek-harness
- 本技能自身：https://github.com/green-dalii/dsh-plugin-dev-skill （版本见仓库根 `VERSION`；载入后自查流程见 `15-self-update.md`）

> 索引与**术语对照表**（上游重命名备忘，如 Code Mode → PTC mode、`CallId` → `ToolCallId`、`ctx.codeRuntime` → `ctx.ptcRuntime`）见 `00-INDEX.md`。
