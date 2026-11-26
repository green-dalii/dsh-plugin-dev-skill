# 08c · 能力 Seam 目录（二）：平台、UI 与演进

> SDK 基线：`@deepseek-ai/*` **0.2.3-alpha.2**（cordis **4.2.0-alpha.1**）。

> 本篇承接 `08-capability-layering.md` 的 `## 5.` 能力 Seam 目录，是其中的后半张表（平台、UI 与演进部分）及版本结构变化小节。
> 本表前半部分（核心服务）见 `08b-seams-core.md`；分层设计概念与设计要点见 `08-capability-layering.md`。

| ctx 键 | 角色 | 说明 |
|---|---|---|
| `ctx.ptcRuntime` | seam | **PTC mode** 程序运行（用宿主异步绑定运行模型写的程序）；`@deepseek-ai/dsh-ptc-runtime-node`（由 `dsh-code-runtime-worker-thread` 改名并改在全新 Node 子进程 + `ctx.sandbox` 下执行）与实验性 `@deepseek-ai/dsh-experimental-ptc-runtime-python` 提供，`tools` 与 `workflow-ptc` 消费 |
| `ctx.terminals` | seam | PTY 会话；`terminal-bash` 提供，`tool-terminal` 面向模型 |
| `ctx.lsp` | seam | LSP 导航；`lsp-stdio` 提供，`tool-lsp` 消费（只有四种标准化查询，无协议逃生口） |
| `ctx.browserUse` | seam | 浏览器操作提供方注册；提供方（playwright-mcp / chrome-devtools-mcp / stagehand-native）自持工具与浏览器资源 |
| `ctx.computerUse` | seam | 桌面操作提供方注册（cua-driver 的 mcp / native 变体）；提供方自持模型工具 |
| `ctx.attachments` | seam | 会话事件之前提交已接受的图片；`attachment-local` 提供，Session Controller / `tool-fs` / LLM 适配器消费 |
| `ctx.officeKit` | core | 已授权 Office 字节在宿主上转换；未声明原生目标时用 Node WASM。**0.2.2-alpha.3 起由 `ctx.officeToPdf` 改名**（包 `dsh-office-to-pdf` → `dsh-office-kit`）；LibreOffice Kit 缺失时不再加载失败，转换时报 `OfficeKitError` code `unavailable`，装好 Kit 无需重载 |
| `ctx.mcpManager` | core | MCP 连接管理（0.2.2-rc.3 新增，`mcp/mcp-manager`）；与只提供资源的 `ctx.mcpResources` 不同 |
| `ctx.userQuestions` | seam | 人工回答提供方；`tool-ask-user` 在提供方无关的 `ask()` promise 上暂停 |
| `ctx.directoryPicker` | seam | 带判别标记的目录选择：native（系统选择器）/ browse（应用内浏览器） |
| `ctx.workflowEngine` | seam | 工作流引擎；每个上下文一个引擎，`workflow-ptc` 提供 |
| `ctx.goals` | core | 目标状态折叠与延续 |
| `ctx.agentPresets` | core | 预挂载 YAML 声明的 preset 修订（owner 由 `preset/agent-presets` 拆为 `preset/agent-preset` + `preset/agent-preset-registry`），把 Agent 与冷读取方绑定到作用域贡献，已退役修订保留到最后一名使用者释放 |
| `ctx.agentTeams` | core | 实验性协作 seam：持久 roster、peer mailbox、任务 DAG（需显式启用） |
| `ctx.commands` | core | 面向人的命令注册 |
| `ctx.planMode` | core | 计划模式 |
| `ctx.typert` | core | 插件注册实时 zod 贡献；API 网关消费调用描述符与提供方 |
| `ctx.webServer` | core | HTTP 载体 |
| `ctx.clientModules` | core | 浏览器模块图 |
| `ctx.pluginMarket` | core | 0.2.1-alpha.2 起新增：plugin market 索引（官方或第三方目录）的只读查询；与 `plugin_manager` 配套使用（agent 端 `plugin_market` 工具即挂在此 seam 上；owner 由 `boot/plugin-market` 提供） |
| `ctx.translator` | core | 0.2.1-alpha.x 起新增：`internal/status` 消费者，把 session/agent 状态投影到外部可读形态 |
| `ctx.remoteAccess` | core | 0.2.1-alpha.x 起新增：远程访问宿主能力；`webserver/index-inject` 在 webserver 注入时挂它 |
| `ctx.webApp` | core | 0.2.1-alpha.x 起新增：与 `ctx.web`（搜索/抓取）并列的 Web 应用 seam |
| `ctx.workingDirectory` | core | 0.2.1-alpha.x 起新增：会话级 cwd；`system-prompt/assemble` 监听者之一，`session/event` 持久化字段。**0.2.3-alpha.2 起**：模型工具 `working_directory` 与包 `@deepseek-ai/dsh-tool-working-directory` 删除，`dsh-base` / `dsh-sdk-minimal` 不再挂载；读 cwd 用上下文行 `Current working directory:`，目录变更记 `workspace-root/change`（细则见 08b 迁移行） |
| `ctx.worktrees` | core | 0.2.1-alpha.x 起新增：git worktree 状态折叠（合并/分支/合并视图）。**0.2.3-alpha.2 起**：模型工具 `create_worktree` 删除，改用 `enter_worktree({ name?, from? })`；新增 Host 方法 `ctx.worktrees.enter(agent, { name })`，`cleanupOf(sessionId, null)` 返回 `{ removed }` 或保留策略下 `null`（细则见 08b 迁移行） |
| `ctx.cotTranslation` | core | 0.2.1-alpha.x 起新增：链式思考翻译 seam（与其他 adapter seam 同级别） |
| `ctx.actionCards` | core | 0.2.1-rc.2 起新增：动作卡片注册（随附 kind 原由个性化推荐 bundle 提供，0.2.2-rc.5 起该 bundle 退役、六行改由 `dsh-web-app` 默认挂载）。**0.2.3-alpha.2 起**：模型工具 `propose_action` **已删除**，模型在回答中输出围栏 `action-card` 块（`action` / `title` / `brief` / `details`），`@deepseek-ai/dsh-action-cards` 从已记录的回答读取；`ActionCardKind` 去掉 `skill` 与 `invitation`；`ActionCardProposal` / `ActionCardDecision` / `ctx.actionCards.act()` / `actionCards` Remote 键按 `cardId`（类型 `ActionCardId`）而非 `callId`，决策携带 `cardId`；服务字段 `queuedMessageLimit` 删除（`cordis.patch.yml` 中 `id: action-cards` 下该值被忽略），`Config` 只剩 `enabled`，包不再导出 `ActionCardError`。后续提案不再把早先卡片置 `replaced`；版本 3 检查点 Host 从日志重建 actionCards 投影；读 `ActionCardView.decisions` 按提案 `cardId` 索引，无决策=未开始，删除旧共享 `replaced` 阶段处理；每回合只取首个有效 action-card 块 |
| `ctx.cuaAccess` | core | 0.2.1-rc.2 起新增：computer-use 访问控制 |
| `ctx.forge` | core | 0.2.1-rc.2 起新增：Forge 提供方注册（`forge/providers-changed` 事件） |
| `ctx.forgePanel` | core | 0.2.1-rc.2 起新增：Forge 面板能力 |
| `ctx.forgeSession` | core | 0.2.1-rc.2 起新增：Forge 会话能力 |
| `ctx.headlessStartup` | core | 0.2.1-rc.2 起新增：headless 启动期能力 |
| `ctx.liveshareShares` | core | 0.2.1-rc.2 起新增：LiveShare 共享项（对应新增的 `experimental/liveshare-protocol` 包） |
| `ctx.pluginRecommendations` | core | 0.2.1-rc.2 起新增：插件推荐；0.2.2-rc.5 起原 `dsh-personalized-recommendations` bundle 退役，`plugin-recommendations` 等六行改由 `dsh-web-app` 默认挂载 |
| `ctx.profileContext` | core | 来自 `@deepseek-ai/dsh-app-boot`（0.2.0-rc.2 起的插件作者服务）。**0.2.3-alpha.2 起**：`overlays: readonly PatchOptions[]` → `overlayPaths: readonly string[]`（`--patch` 绝对路径，按 argv 顺序）；`readProfilePatches()` 每次调用重读文件（缺失/非法即抛错），`dsh-hmr` 在 `--patch` 编辑时重组合。替代读取 `ctx.profileContext.overlayPaths.flatMap(path => loadOverlayPatches(binName, path))`，完整组合 `readProfilePatches(binName, ctx.profileContext)` |

> ⚠️ 0.2.1-alpha.1 起 **`ctx.invariants` 已删除**：包 `@deepseek-ai/dsh-invariants` 与各包 `<pkg>/invariant` 子路径都不再导出；`InvariantRegistry` / `InvariantInstaller` / `InvariantFailure` / `InvariantError` 不存在。`sdk-minimal` 中五个 `*-invariant` id 也已清理。诊断失败改用自有通道上报——见 `12b-migration-errors.md` 错误表。

### `0.2.0-rc.2` 的服务结构变化（相对 `0.1.5-rc.2`）

- **移除 E2B 线**：`e2b` / `fs-e2b` / `subprocess-e2b` 包已删除，`ctx.e2b` 随之消失；远程能力改由 SSH 家族承担——`ssh/fs-ssh`、`ssh/subprocess-ssh`、`ssh/sandbox-ssh`（依次对应原来的 `fs-e2b` / `subprocess-e2b` / `e2b`）。`ctx.codeRuntime` → `ctx.ptcRuntime` 同理。
- **新增角色类别 `service`**（除已有的 core / seam / bundle 外）：尚未抽出扩展点的具体实现，当前有 `ctx.otel`（`telemetry/otel`）、`ctx.productAnalytics`（`client/product-analytics`）、`ctx.productTelemetry`（`host/product-telemetry-otel`）。
- **插件作者相关的新服务**（括号内为 owner 包路径）：`ctx.hmr`（`boot/hmr`）、`ctx.configEditor`（`boot/config-editor`）、`ctx.pluginManager`（`boot/plugin-manager`）、`ctx.profileContext`（`boot/app-boot`）、`ctx.connection`（`client/connection`）、`ctx.mcpResources`（`mcp/mcp-resources`，seam）、`ctx.browserUse`（`browser-use/browser-use`，seam）、`ctx.computerUse`（`computer-use/computer-use`，seam）、`ctx.officeKit`（`document/office-kit`）、`ctx.mcpManager`（`mcp/mcp-manager`）、`ctx.deepseekChatImport`（`experimental/deepseek-chat-import`）、`ctx.sessionLogDeepSeek`、`ctx.workspaceChanges`（`deliverables/workspace-changes`）、`ctx.schedule`（`schedule/schedule`）、`ctx.deepseekAccount`（`credentials/deepseek-account`，seam）、`ctx.speechToText`（`experimental/speech-to-text`，seam）、`ctx.speechController`（`experimental/api-speech-to-text`）。
- **提供方变动**：`ctx.workflowEngine` 的实现由 `workflow-worker-thread` 改为 `workflow-ptc`；`ctx.settings` 的 `settings-file` 提供方已移除（`@deepseek-ai/dsh-settings-file` 不再存在）。
- 上游 `capability-seams` 表格的服务行数由 `0.1.5-rc.2` 的 72 行增至 `0.2.0-rc.2` 的 92 行；**0.2.1-alpha.4 又新增 7 项**：`pluginMarket` / `translator` / `remoteAccess` / `webApp` / `workingDirectory` / `worktrees` / `cotTranslation`；**0.2.1-rc.2 起再新增 8 项**：`actionCards` / `cuaAccess` / `forge` / `forgePanel` / `forgeSession` / `headlessStartup` / `liveshareShares` / `pluginRecommendations`；**0.2.2-rc.3 为 110 项**（新增 `mcpManager` / `deepseekChatImport` / `sessionLogDeepSeek`，`officeToPdf` 改名为 `officeKit`）。

> 本表上次按本地 `0.2.2-rc.3` SDK 核对（新基线以各 seam 的 TypeScript 接口为准）：上游 `capability-seams` 页面是生成物且比本表长得多（该版有 **110** 个 `ctx.*` 服务），本表只保留插件开发常用项；以本地安装为准时，请先用该服务的 TypeScript 接口核对 key。
>
> 完整列表（含每个 seam 的 Definition 包、全部 Provider 与直接消费方）以官方 capability-seams 页面为准；开发时以各服务 TypeScript 接口和子系统页面的 `cordis-surface` 区块为权威，不要维护静态清单。

### `0.2.3-alpha.2` 迁移行（平台 seam）

| 旧 | 新 |
|---|---|
| `propose_action` / `callId` / 共享 `replaced` 阶段 / `ActionCardError` / `queuedMessageLimit` | `action-card` 围栏块 / `cardId`（`ActionCardId`）/ 按提案 `cardId` 索引 `decisions` / 无 `ActionCardError` / `Config` 仅 `enabled` |
| patch 仍点名 `tool-working-directory` | 报 `patch: entry "tool-working-directory" not found` |
| `ctx.profileContext.overlays`（`PatchOptions[]`） | `overlayPaths`（`string[]`），见上 |

> 本主题的官方文档链接见 `08-capability-layering.md` 末尾。
