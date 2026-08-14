# 01 · DSH 架构总览

> 精简提炼自官方文档（guide + develop/basic/publish + CLI 参考）。目标：建立“DSH 是什么、插件如何被加载与组合”的整体地图。

## 1. DeepSeek Harness 是什么

DeepSeek Harness 是**用于构建 Agent Harness 的插件化 SDK**。它不是单体应用，而是一套 Cordis 插件组合：模型适配、工具执行、文件访问、会话持久化、Web UI……每一项能力都是一个插件，通过 `cordis.yml` 组合成可启动的“profile”。

- 官方文档站：https://deepseek-harness.github.io/deepseek-harness/
- 源码仓库：https://github.com/deepseek-ai/deepseek-harness （monorepo，`packages/<group>/<pkg>` 布局）
- 底层框架：**Cordis**（v4，vendor 引入）—— 一个“时空可组合性”的元框架（见 `10-spatiotemporal.md`）

## 2. CLI 入口（dsh）

| 命令 | 用途 |
|---|---|
| `dsh --profile <name>` | 启动指定 profile（`$DSH_HOME/profiles/<name>`） |
| `dsh --profile headless "job"` | 无界面一次性执行：新建持久化会话、打印最终答案并退出 |
| `dsh web` | `--profile web` 的别名（Web UI） |
| `dsh plugin --profile <name> <pnpm args...>` | 在 profile 目录里转发给 pnpm 管理插件依赖与 bundle |
| `dsh --profile <name> --dump-config` | 不启动，打印叠加后的完整配置树（验证配置层用） |
| `dsh --profile <name> --dump-default-config` | 打印默认配置树 |

- 启动器只解析自身 flag，其后的 token 交给 profile 中的应用插件（`dsh-cmdline` 提供 `cmdlineArgs` 服务解析共享的不可变参数快照）。
- 运行命令的目录作为默认 workspace 根目录。
- 从源码运行时，把 `dsh` 换成 `pnpm dsh`。

## 3. Profile 与 Bundle：两个概念、两种 manifest

安装机制基于两个概念，都由 `package.json` 描述，但携带的 manifest 种类不同：

| | 组合包（bundle） | profile |
|---|---|---|
| 回答的问题 | “这个包贡献什么？” | “这套配置由哪些组合包按什么顺序组成？” |
| manifest | `dsh.bundle`（指向一个 patch 文件） | `dsh.profile`（有序 `bundles` 列表） |
| 角色 | 你编写并分发的东西 | 用户用 `dsh --profile <name>` 启动的东西 |
| 位置 | npm 包 | `$DSH_HOME/profiles/<name>/` |

profile 目录含：`package.json`（树外插件依赖 + `dsh.profile` manifest）、`cordis.patch.yml`（用户自己的 patch 层）。profile manifest 由 `dsh plugin` 自动创建维护，无需手写。

## 4. 配置层顺序（决定生效配置）

生效配置在空根之上按顺序叠加（**后应用者按行胜出**）：

1. `dsh.profile.bundles` 中各组合包的 patch（按列表顺序）
2. profile 自身的 `cordis.patch.yml`
3. `$DSH_HOME/cordis.patch.yml`（机器级偏好，跨 profile 共享）
4. 每个 `--patch <path>` overlay（按 argv 顺序）

关键语义：

- **patch 替换目标行整个 `config` 值，不是深度合并**。
- 推论 1：覆盖别层某行时（按 `id`），必须重述该行需要的**每一个键**。
- 推论 2：用户可以在自己 profile 的 patch 里覆盖你的行而不改你的包 → 优先给出用户大概率保留的默认值，其余交给 schema。
- 内置组合包（`@deepseek-ai/dsh-base`、`dsh-web-app`、`dsh-headless`）始终从 dsh 安装目录解析；pnpm 只管理树外包。

## 5. 插件加载机制

- 配置是一组 **entry**（条目），每项含：`id`（稳定标识，对账键）、`name`（模块说明符：相对路径或 npm 包名）、`config`、`group`（嵌套组）、`disabled`、`inject`（条目级依赖）。
- Loader 读 `cordis.yml`，把每个 entry 挂载为一个子插件（fiber）。**各 entry 并发启动**，加载先后由服务依赖（inject）决定，不由文件行序决定。
- `!!js` 表达式在 `config` 与 `disabled` 字段内求值（基于 loader 上下文），可用于按平台/环境门控一行。
- 修改配置触发**对账**：loader 按 `id` 比较条目，只挂载/卸载/重配变化的部分（未写 `id` 的条目每次读取都会得到新生成的 id，任何文件编辑都会被视为删除+新增并重挂载）。

## 6. 开发环境速览

- 推荐路径：克隆仓库 → `pnpm install` → 在 `tmp/`（git 忽略）里写示例 → `pnpm dsh web --patch ./你的cordis.yml` 加载本地插件；或 `node --import tsx ../../vendor/cordis/bin.js` 跑纯 Cordis 教程（无需 API key）。
- 本地插件 patch 示例：

```yaml
- insert:
    - id: hello
      name: '/absolute/path/to/deepseek-harness/scratch-plugin/src/my-plugin.ts'
```

> 插件路径必须是绝对路径；patch 只贡献配置，不改变 loader 解析模块路径时使用的 profile 目录。

## 7. 内核主干（六个包）

一个轮次（turn）沿同一条循环流经六个核心包：

1. `session/` — 仅追加的 `SessionEvent` 日志与内存 store（唯一真源，`ctx.sessions`）
2. `system-prompt/` — 提示词段落与工具 schema 组装（`ctx.systemPrompt`）
3. `tools/` — 带作用域的工具注册表与受保护执行流水线（`ctx.tools`）
4. `agent/` — `Agent` 接口、实时注册表、发起者作用域、`agent/*` 事件（`ctx.agents`）
5. `agent-loop/` — 实现公开 `Agent` 约定的具体 driver（`ctx.agentLoop`）
6. `scope/` — 按 agent 作用域注册的库原语（非服务）

> 扩展插件依赖 `agent` 而**绝不直接依赖 `agent-loop`**，循环因此可替换。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **入门（Web UI / 模型配置）**：https://deepseek-harness.github.io/deepseek-harness/guide/quickstart
- **打包与安装插件（profile/bundle/配置层）**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/publish
- **CLI 行为参考（源码仓库）**：https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.md
