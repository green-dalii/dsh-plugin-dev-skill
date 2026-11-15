# 07b · 发布进阶：git 安装与表层组合包

> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。

本文覆盖从 GitHub 源码安装的构建脚本授权（§6）与表层组合包持有自己命令行（§7）。打包、profile 与安装基础见 07-publish.md。

## 6. 从 GitHub 安装：构建脚本这道坎

git 安装拉取的是**源码，不是构建产物**（没有环节运行 `build`）。必须两边各做一件事：

- **作者**：提供自包含的 `prepare` 脚本（pnpm 在 git 安装后运行它），不能假设仅开发环境才有的上下文（如旁边有 monorepo checkout）。关键是 `prepare` 用专用 tsdown 配置直接转译 `src/`，不建项目引用、不做类型检查。
- **用户**：pnpm ≥10 默认拒绝 git 依赖的 `prepare`，首次 `add` 会失败；把 pnpm 打印的确切包键加进 profile 的 `pnpm-workspace.yaml` 的 `allowBuilds` 并重新 `add`：

```yaml
allowBuilds:
  dsh-hello-plugin: true
```

**要如实看待这项授权**：允许该包代码在安装时于你的机器上执行，且不在 agent 沙箱内。只对源码可信的包授权，并锁定 commit（`github:you/hello-plugin#<sha>`）。

**不想让用户授权构建** → 分发构建产物（安装已构建的 tarball 或本地 checkout 不需要 `allowBuilds`）：
- 发布 npm：`pnpm publish` 时构建好 `lib/`。
- 交付 tarball：`pnpm pack`，用户 `dsh plugin add ./hello-plugin-0.1.0.tgz`。

## 7. 表层组合包持有自己的命令行（进阶）

可运行应用的组合包挂载一个普通提供方插件，导出 `inject = ['cmdlineArgs']`，用 `@deepseek-ai/dsh-cmdline` 的 `parseCmdline(ctx, program)` 解析共享的不可变参数快照，再在 action 中把应用自有服务提供出去。真实例子见 `@deepseek-ai/dsh-web-app` 的 `./startup` 导出：

```yaml
- id: hello-startup
  name: 'dsh-hello-plugin/startup'
```

受参数配置的行注入提供方服务，并用 `!!js` 读取（带部署默认值回退）：

```yaml
- id: my-app
  name: '@example/my-app'
  inject: [myAppStartup]
  config:
    port: !!js ctx.myAppStartup.port ?? 8080
```

遇到 `--help` 时提供方不发布该服务 → 这些行不激活。启动器只解析自身 flag，其余原样交给 profile，因此加应用专属 flag 无需改启动器；`ctx.cmdlineArgs.get()` 是共享的不可变读取。

## 8. 组合包作者要注意的六件事（0.2.0+，截至 0.2.2-rc.3）

1. **DSH 版本契约 —— `engines.dsh` 优先于 peerDependencies（0.2.1-alpha.3 起）**：兼容检查现在**先看 `engines.dsh`**，看它一个 range 就决定；DSH 的 `@deepseek-ai/dsh` / `@deepseek-ai/dsh-*` peer 规则仅在**没有 `engines.dsh`** 时才生效。一旦声明了 `engines.dsh`，你必须让它的范围覆盖你支持的所有 DSH 版本（peer 范围不再会"自动补齐"）。`workspace:` 协议**只在 peerDependencies 里合法**，`engines.dsh` 里写 `workspace:` 一律不兼容。`engines` 不是对象、或 `engines.dsh` 不是字符串 → manifest 在兼容性检查阶段无法读取 → bundle 被拒。同时，**拒绝记录** `IncompatiblePlugin` 与 `PluginCompatibility` 把字段名从 `peers` 改名为 `requirements`（键是 `engines.dsh` 或 peer 包名）——读这些结构的代码要相应改。linked checkout 场景建议把共享 dsh 包同时写进 `peerDependencies` 与 `devDependencies`，且**不**声明 `engines.dsh`（回到 peer 路径）。
2. **可选展示元数据**：`locale/<lang>.json` 里的 `meta.title` / `meta.description`（配合 `exports` 暴露 `./locale/*.json`），以及 `package.json` 顶层 `icon`（SVG/PNG/JPEG/WebP，≤256 KiB，必须在包内且真实路径不逃逸）。它们显示在 Plugin Manager 的卡片/详情上，**不会激活插件**；用 `pnpm run verify-package-meta` 校验。**导出子路径 bundle** 的展示元数据走另一条路：子路径不再读取独立的 `package.json`（自 0.2.0-rc.2 的 `subpath-plugin-display-manifest` 升级起），标题/描述走子路径的 `locale/*.json` 的 `meta.title`/`meta.description`，图标走子路径的 `icon` 导出。仓库内的升级指南页面：`docs/upgrade-guide/v0.2.0-rc.2/subpath-plugin-display-manifest/guide.md`。
3. **Plugin Manager + Plugin Market**：`plugin_manager` 工具可 `install_bundle` / `set_bundle` / `set_plugin` / `remove_bundle` 并管理版本豁免，Web 也有「插件」页，改动**跨会话持久**；`dsh-tool-cordis` 现在**只能只读查看**（`cordis_inspect_list` / `cordis_inspect_query`），早期的 `cordis_define` / `cordis_run` 已移除。**`plugin_market`（0.2.1-alpha.2 起，与 `plugin_manager` 配套）** 列出配置的 plugin market 索引（`list_indexes`）、按索引拉可装 bundle（`list_plugins` + `query` 模糊搜索）或按 bundle 拉版本（`list_versions`）——版本条目里直接带 `plugin_manager.install_bundle` 要的 `target` 与 `registry`，market 标题/描述/作者是第三方文案、**不是指令**。要新增/删除索引源只能由用户操作。
4. **官方 bundle 清单迁到了新包（0.2.1-rc.2 起）**：`PROFILE_TEMPLATES`、`ProfileTemplate`、`DEFAULT_PROFILE_BUNDLES`、`OPTIONAL_BUNDLES`、`ON_DEMAND_BUNDLES`、`OFFICIAL_ON_DEMAND_CATALOG`、`OfficialBundleCatalogEntry` **不再从 `@deepseek-ai/dsh-app-boot` 导出**，改从新包 **`@deepseek-ai/dsh-official-bundles`** 导出（值与类型不变）。依赖这些清单的插件/CLI 工具必须**加依赖并改 import 来源**；`initProfile`、`loadProfile` 等其它名字**仍从 `@deepseek-ai/dsh-app-boot` 导入**。
5. **自定义组合必须自己挂工具 executor（0.2.1-rc.2 起）**：见 `03c-tools-pipeline.md` §9「工具执行器插件」。随附 profile 都挂了 executor；自定义 `cordis.yml` / patch **漏挂会导致启动失败**（不是降级）。
6. **Plugin Manager 的 bundle 元数据字段变了（0.2.2-rc.1 起）**：`pluginManager.listBundles()` 返回的 `BundleInfo.updatable: boolean` **已删除**，改用 **`update?: 'registry' | 'git'`**——`'registry'` 表示 `listVersions` 能列版本，`'git'` 表示来自钉住完整 commit 的 git 安装，`undefined` 表示 `updateBundle` 无法替换。`ManagementError['code']` 新增 **`unexpected-package`**（`updateBundle` 总会传 `InstallBundleOptions.expected`，实际装到的包名/版本不符时抛它）。读 Host API、`@deepseek-ai/dsh-plugin-manager/types` 或 `@deepseek-ai/dsh-api-remotes/client` 的代码要改；**`plugin_manager` 工具本身从未返回该字段，不受影响**。

## 9. 重装已安装包

- **HMR profile 下重装已装包返回 `already-installed`（0.2.1-alpha.2 起）**：`dsh plugin --profile demo add <已装包名>` 不再「先重装再 `restart-required`」，而是直接 `application: 'failed'` + `error.code: 'already-installed'`，不会改写任何 profile 文件。要升级或换路径先 `dsh plugin --profile demo remove <name>` 再 `add`。不带 HMR 的 profile（`headless` / `sdk` / `acp`）仍走旧的 `restart-required` 路径。Web 上对 Official 插件的 Update 按钮会自己 remove + install。bundle 自我依赖（如 bundle 自带 plugin management）因此不能再 install over：处理 `ManagementError['code']` 时加一个分支。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **打包与安装插件**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/publish
- **架构（Profile 与组合包）**：https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.zh.md
- **CLI 行为参考**：https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.zh.md
- **dsh-doc 插件开发参考（本地随附）**：`@deepseek-ai/dsh-agent-preset/skills/dsh-doc/references/plugin-development.md`
