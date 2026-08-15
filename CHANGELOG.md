# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

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
