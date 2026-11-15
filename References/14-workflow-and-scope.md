# 14 · 开发流程与覆盖范围边界

> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。

> 本文件给两件事：① 一个 Agent 从侦察到交付的**四阶段流程**（照着走即可）；② 本技能**做什么 / 不做什么**的边界，
> 以及边界外那些变化最快的宿主侧改名（UI、Schedule、子代理、Web 搜索）。
> 边界外的完整细则不在本技能维护范围内——请按文末链接读上游原文。

## 1. 开发流程（Agent 照着走）

### 阶段 A：侦察（动手前必做）
1. 读目标仓库/项目结构：`cordis.yml`（或 profile 的 `cordis.patch.yml`）、`packages/*/package.json`、现有插件源码。
2. 确认要用的服务存在且知道其 API：查 `ctx.<name>` 类型定义或子系统文档（`References/08-capability-layering.md`）。
3. 确认要监听的事件名与分发模式（`tools/*`、`agent/*`、`session/event` 等）。

### 阶段 B：实现
1. 按 `02`~`05` 各篇的模板写插件：`name` / `inject` / `Config` / `apply(ctx, config)`。
2. 所有副作用走 `ctx.*` API 或 `ctx.effect()`。
3. 所有可调参数进 `Config`（带默认值），无硬编码。
4. 定义完整的 `Config` schema，使错误配置在加载时响亮失败。
5. 工具：定义清晰 `description` 与参数说明、规范的 `output.schema`、纯函数 `output.render`（和可选展示器）。
6. 处理 `exec.signal` 取消；长任务用 `ctx.jobs` 后台化。

### 阶段 C：验证
1. 类型检查与构建通过（如 `pnpm run typecheck && pnpm run build`，在 DSH 仓库内）。
2. 用 `--patch` 或 `dsh plugin add` 加载，用 `--dump-config` 确认配置层。
3. 启动运行，确认：插件日志出现、工具/服务/事件按预期工作。
4. 测试卸载/重载：改**配置**确认注册被清理、无泄漏、无残留监听（base 系 profile 默认热重载配置）；**源码模块热替换默认关闭**，要用 profile patch 打开 `hmr` 的 `root`，否则重启进程验证。
5. 测试依赖缺失场景：去掉提供方 → 插件 PENDING 不崩溃；恢复 → 自动加载。
6. 测试错误配置：传非法 config → 明确报错。

### 阶段 D：交付
1. 按 `07-publish.md` 打包（`dsh.bundle` + patch + 自包含 prepare 脚本，或发布 npm/tarball）。
2. 写包 README：服务 API / 配置 / 事件 / 扩展点 / 设计说明。
3. 遵循仓库测试策略补测试与组装覆盖。

## 2. 覆盖范围边界

本技能**专注于**：plugin 模型心智模型、`tool` / `llm` / `service`（含 provider + consumer）/ `event` / `bundle`（含 profile + manifest + Plugin Manager）——这五类能力足以覆盖绝大多数 Agent 插件需求。

本技能**不覆盖**（需要直接查官方仓库的子系统页面）：

- **Host plugin / UI 扩展**（Web 客户端组件、composer 输入区、统计面板装饰器等）：0.2.1 把 `composer-stats` 扩展点拆为 `activity` 与 `usage` 两个独立 ID，覆盖旧 `stats` 整行的插件要更新注册 ID。**0.2.1-rc.2 ~ 0.2.2-alpha.2 期间 UI 层还有一批破坏性改名**（按影响面汇总，逐条细则见上游 `docs/upgrade-guide/`）：右键菜单注入名 `ctx.menus` → `ctx.contextMenus`，类型 `MenuTargetMap` → `ContextMenuTargetMap`（**无兼容别名**），Slot 贡献路径 `sidebar.workspaces.session.menu.item` / `sidebar.right.tab.menu.item` → `contextMenu.content`，菜单项图标 prop `symbol` → `icon?: ReactNode`；`MenuTarget` → `ContextMenuTarget`，注入名 `menuTarget` / `useMenuTarget` → `contextMenuTarget` / `useContextMenuTarget`，动作图标改走 `contextMenu.icon` Slot；图片视图与 `MarkdownDelegate.fileImages` 新增必需的 `fileDrag` 注入成员（新增 `@deepseek-ai/dsh-client-ui-file-drag` 包）；Web 端文件保存改为 `save(source, 'download')`（`canSaveAs` 恒为 `false`，`savedFile` / `reveal` 已移除）；推理 Slot 的 `conversation.chat.reasoning.body` 新增 `rawText`（模型原始输出），原 `text` 改为 Chat 预处理后的展示文本。**自定义 Client composition 还必须补挂 `@deepseek-ai/dsh-client-ui-context-menu` 与 `@deepseek-ai/dsh-client-ui-file-actions` 两行**。详见 `docs/subsystems/` 下对应文档（仅仓库内，未发布到文档站）。
- **Schedule / 自动化任务扩展**：0.2.1 起自动化任务改为 Web 内置能力，`schedule_*` 工具按模式提供（标准、创造、PTC 模式可用；极简模式与子代理不可用），并新增 `subagent_session` 错误码。**0.2.2-alpha.2 起工具名与 API 整体重构**：`schedule_create` / `schedule_list` / `schedule_view` / `schedule_edit` 取代旧工具，`schedule_create` 收 `title` / `prompt` / `rrule` / `target`（不再接受时间选择器），`schedule_edit` 用 `action: "update" | "delete"` 取代 `schedule_update` / `schedule_delete`；原生调用改为 `create({ title, prompt, timing, target? })` 与 `edit(request)`（远端为 `schedule/create`、`schedule/edit`），Session 绑定的 `delete` / `update` 已移除；定时类型改用判别式（`{ kind: "cron", cron }` / `{ kind: "rrule", rrule }`），状态用 `paused` / `ended` 取代 `inactive`。子系统页面：https://deepseek-harness.github.io/deepseek-harness/reference/subsystems/schedule 。
- **MCP / SSH / browser-use / computer-use / otel / product-telemetry / boot / voice-input / office-kit** 等 0.2.0+ 新增的子系统，文档均只存在于上游仓库 `docs/subsystems/`，相关文件内已给链接。注意 **`dsh-office-to-pdf` 已改名为 `dsh-office-kit`**、服务 `ctx.officeToPdf` → **`ctx.officeKit`**（详见 `12b-migration-errors.md`）。
- **Claude Code Mods 兼容层**（0.2.1-alpha.1 引入的实验性 bridge）：仅仓库 `docs/subsystems/claude-code-mods.md`，文档站尚未发布。
- **子代理编排细节（0.2.2-alpha.3 起全面具名）**：`@deepseek-ai/dsh-tool-subagent` 的 `modelSelectionSettings` 已改名 `modelSelection`、新增 `modelDiscovery`（每工具域一个实例，默认 `false`），`/list-models` 导出已移除；`@deepseek-ai/dsh-tool-subagent-control` 合并注册 `send_message` / `interrupt_agent` / `list_agents` 三个工具，`/list-agents` 导出已移除（禁用该行会同时禁掉三个工具）。**具名化细则见 `12b-migration-errors.md` 表格**（`agent_id` → `agent`、`list_agents` 行改形、`parentAgent` 移除、catalog payload v3）。
- **Web 搜索 / 抓取（0.2.2-rc.1 起）**：默认改用 **DeepSeek Search API**，搜索与抓取可**分别**选择计费账号或 API Key；旧的 `@deepseek-ai/dsh-web-search-exa` / `dsh-web-search-perplexity` 包**已删除**，旧的 provider 认证字段被"有序凭据来源"取代——自定义 provider 或显式配置要按上游 `web-search-billing` 指南调整。
