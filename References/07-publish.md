# 07 · 打包与安装插件

> 精简提炼自 develop/basic/publish 与 `apps/cli/reference`（CLI 行为参考）。SDK 基线 `@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）；§2 的版本契约、bundle 清单迁包与 executor 挂载要求已按 0.2.1-rc.2 ~ 0.2.2-rc.3 修订。

## 1. 两个概念：组合包（bundle）与 profile

安装机制基于两个概念，都由 `package.json` 描述，但 manifest 种类不同：

- **组合包（bundle）**：附带一个配置层的 npm 包，manifest 声明 `dsh.bundle`（指向一个 patch 文件或有序列表）。回答“这个包贡献什么？”——你编写并分发的东西。
- **profile**：位于 `$DSH_HOME/profiles/<name>` 的可启动组合，manifest 声明 `dsh.profile`（有序 `bundles` 列表）。回答“这套配置由哪些组合包按什么顺序组成？”——用户用 `dsh --profile <name>` 启动的东西。

**没有东西同时是两者。** `dsh <name>` 是 `dsh --profile <name>` 的简写（简写名必须紧跟 `dsh`）；`plugin` 仍是管理命令，要启动名为 `plugin` 的 profile 得写 `dsh --profile plugin`，重复 `--profile` 会报错。

## 2. 组合包结构

```
hello-plugin/
├── package.json       # 声明 dsh.bundle
├── cordis.patch.yml   # 层内容（配置贡献）
└── index.js           # 插件模块
```

```jsonc
// package.json
{
  "name": "dsh-hello-plugin",
  "version": "0.1.0",
  "type": "module",
  "main": "index.js",
  "files": ["index.js", "cordis.patch.yml"],
  "dsh": { "bundle": { "patch": "./cordis.patch.yml" } }
}
```

```yaml
# cordis.patch.yml —— 与 --patch overlay 同格式；插件按包名引用
- insert:
    - id: hello
      name: dsh-hello-plugin
```

`patch` 的路径相对**声明它的包根目录**解析；也可以给**有序数组**（`string | string[]`），按数组顺序作为**同一层**应用，且每个文件里的相对插件路径相对该文件解析。没有 `dsh.bundle` 声明的包仍可安装，但只作为普通依赖（`dsh plugin` 打印一次性警告、不激活任何层）；若日后 `update` 到带该声明的版本，会自动激活。库包就使用这种格式。

manifest 另有两个可选的新键：`dsh.manifestVersion: 1`（manifest 格式版本，与包版本、Session 格式版本无关）与顶层 `icon`（插件卡片图标；展示元数据见 §4）。

**DSH 版本契约（0.2.0 起，0.2.1-alpha.3 改规则）**：兼容检查**先看 `engines.dsh`**——一旦声明，它一个 range 就决定兼容性，DSH 的 `@deepseek-ai/dsh` / `@deepseek-ai/dsh-*` peer 规则**只在没有 `engines.dsh` 时**才生效（peer 范围不再会替 `engines.dsh` 补齐）。不兼容的行会被**拒绝**、bundle 会被**跳过**，除非 profile 的 `compatibility.json` 里有精确 `name@version` → 运行时版本的豁免。`workspace:` 协议**只在 peerDependencies 里合法**，`engines.dsh` 里写 `workspace:` 一律不兼容；`engines` 不是对象或 `engines.dsh` 不是字符串 → manifest 在兼容性检查阶段无法读取 → bundle 被拒。拒绝记录（`IncompatiblePlugin` / `PluginCompatibility`）的字段名是 **`requirements`**（不是 `peers`），键是 `engines.dsh` 或 peer 包名。linked checkout 场景建议把共享 dsh 包同时写进 `peerDependencies` 与 `devDependencies`（后者供 linked checkout 与类型检查），且**不**声明 `engines.dsh`（回到 peer 路径）。

**官方 bundle 清单迁包（0.2.1-rc.2 起）**：`PROFILE_TEMPLATES`、`ProfileTemplate`、`DEFAULT_PROFILE_BUNDLES`、`OPTIONAL_BUNDLES`、`ON_DEMAND_BUNDLES`、`OFFICIAL_ON_DEMAND_CATALOG`、`OfficialBundleCatalogEntry` **不再从 `@deepseek-ai/dsh-app-boot` 导出**，改从新包 **`@deepseek-ai/dsh-official-bundles`** 导出（值与类型不变）。依赖这些清单的插件 / CLI 工具必须**加依赖并改 import 来源**；`initProfile`、`loadProfile` 等其它名字**仍从 `@deepseek-ai/dsh-app-boot` 导入**。

**自定义组合必须挂工具 executor（0.2.1-rc.2 起）**：`dsh-tools` 的 `mode` / `maxParallelSubCalls` 配置字段**已删除**（加载时直接拒绝），Native / PTC 执行改由 `@deepseek-ai/dsh-tool-executor-native` / `@deepseek-ai/dsh-tool-executor-ptc` 承担。随附 profile 都挂了 executor；**自定义 `cordis.yml` / patch 漏挂会导致启动失败**（不是降级）。

**依赖 / 激活顺序要求**：

- `@deepseek-ai/dsh-user-approval` **必须排在 `@deepseek-ai/dsh-session-projection` 之后**——`ApprovalService` 依赖 `sessionProjections`，缺失或未就绪时激活会**失败**（**不再退化为回读事件日志**）。
- 工具 executor 行（`tool-executor-native` / `tool-executor-ptc`）**必须启用**，否则启动失败。
- `@deepseek-ai/dsh-tool-subagent/model-selection-settings`（若需要多模型路由）**必须排在创建 Agent 之前**，并提供 `sessions` 与 `sessionProjections` 服务。

## 3. profile 结构（自动维护）

profile 目录含三个文件：

- `package.json` — 树外插件依赖（pnpm 管理）+ `dsh.profile` manifest：有序 `bundles` 列表（`patchReload` 字段已删除，残留键是**惰性的**，没有读取方）。
- `cordis.yml` — 空列表，由 Profile Manager 维护，不要手写。
- `cordis.patch.yml` — 用户自己的 patch 层（每个组合包层之后应用）。

首次初始化还会生成 `pnpm-workspace.yaml`（pnpm 配置；从 git 安装时的 `allowBuilds` 写在它里面，由 pnpm 维护）。

profile manifest 从不需要手写：

- `web`、`headless`、`sdk`、`sdk-minimal`、`acp` 首次使用时自动从**随附模板**初始化（如 `web` = base + web-app）。
- `dsh --profile <name> --from-default-profile <template>` 从随附模板派生新的自定义 profile：**只把模板当前的 bundle 列表复制进新 manifest，依赖为空、用户 patch 为空**；目标名不能是随附名（另有保留的 `desktop`），且目标目录必须不存在。
- `dsh plugin` 为其他名称初始化一个以 base 为基础的 profile，并维护其中已安装的 bundle 列表。
- bundle 加载失败**不是致命的**：无法解析、不可读、未声明 `dsh.bundle`、或 DSH peer 不兼容且未豁免的 bundle 会被**跳过**（仍留在 `dsh.profile.bundles` 里，记入 `skippedBundles`，每次启动打印一次），其余 bundle 保持顺序；profile manifest 与用户 patch 的错误仍会让启动失败。

## 4. 安装与移除

```sh
dsh plugin --profile demo add ./hello-plugin       # 首次自动初始化 profile（dsh-base 是第一个 bundle）
dsh plugin --profile demo add .                    # 相对路径按“调用目录”锚定，装的是当前 checkout
dsh --profile demo --dump-default-config           # 只看组合包各层，不启动
dsh --profile demo --dump-config                   # 再看 profile/home patch 与 --patch overlay（看到 "# == dsh-hello-plugin" 层）
dsh --profile demo --dump-config-schema            # 再看 JSON Schema 2020-12（同一批层，含组合条目与 patch 层）
dsh --profile demo                                 # 启动
dsh plugin --profile demo remove dsh-hello-plugin  # 同时移除依赖和对应层
```

- 三个 dump 标志（`--dump-config` / `--dump-default-config` / `--dump-config-schema`）**互斥**且不接受 app 参数；`--dump-default-config` 不接受 `--patch`。`--dump-config-schema` 与 `--dump-config` 走同样四层，并会 **import 组合模块**（只对可信 profile 运行）。
- `dsh plugin --profile <name> <args>`（`--profile` 必填）在 profile 目录内转发给 pnpm，所有 pnpm 子命令可用；DSH 自有子命令会**先被拦截**：`version-exemptions`、`allow-version <package@version> --dsh-version <exact> --accept-risk`、`revoke-version …`（精确版本豁免记录在 profile 的 `compatibility.json`）。`add`/`install` 具名包会在跑 pnpm 前做兼容检查，被拒时打印确切的 `allow-version` 命令；**没有** `dsh plugin build`/`pack`/`publish`。`add` 支持：本地目录/checkout、`github:you/repo`、npm 包名、tarball；相对 spec（`.`、`../plugin` 及 `file:`/`link:` 形式）会先锚定到调用目录，避免在插件 checkout 里执行 `add .` 时错误地自链 profile。
- 每次成功后 `dsh.profile.bundles` 按安装状态重算：声明了 `dsh.bundle` 的依赖按依赖顺序追加；`update` 后才获得该声明的依赖会自动激活；被移除或不再声明的会移出层栈。
- **组合包成员变化需要重启 profile**（正在运行的 profile 保持本次启动的组合包集合）。配置热重载现在是**YAML 组合的属性**（manifest 的 `patchReload` 已删除）：base 的 `hmr` 行（包名由 `@deepseek-ai/cordis-plugin-hmr` 变为 **`@deepseek-ai/dsh-hmr`**）在 base 系 profile（含 `web`）**默认启用**，profile 与 home 的 `cordis.patch.yml` 编辑即热重载；其 `config.root: []` 意味着监听**源码模块**仍需 opt-in（在 profile patch 里改成 `root: ["."]`）。`headless` / `sdk` / `acp` bundle 显式 `disabled: true`（仅启动时加载），`sdk-minimal` 没有该行；launcher 自身不再安装任何 watcher。
- **持久安装走 Plugin Manager**：`@deepseek-ai/dsh-plugin-manager` 已随 0.2.0 发行版交付（`apps/cli` 与 base bundle 的依赖），提供 `plugin_manager` 工具（`install_bundle` / `set_bundle` / `set_plugin` / `remove_bundle` / `list_version_exemptions` / `set_version_exemption`）与 Web「插件」页，改动**跨会话持久**。`dsh-tool-cordis` 现在**只读**（`cordis_inspect_list` / `cordis_inspect_query`），`cordis_define` / `cordis_run` **已移除**，不能再当作进程内动态扩展路径。
- **可选展示元数据**：`locale/en.json`（及其他语言）里的 `meta.title` / `meta.description`，配合 `exports: { "./locale/*.json": … }`、`files`，以及顶层 `icon`（SVG/PNG/JPEG/WebP，≤256 KiB，路径必须在包内且真实路径不得逃逸）；用 `pnpm run verify-package-meta` 校验。这些只显示在 Plugin Manager 的卡片/详情上，**不激活插件**。

## 5. 配置层顺序（生效配置）

1. `dsh.profile.bundles` 各组合包 patch（按列表顺序）
2. profile 自身的 `cordis.patch.yml`
3. `$DSH_HOME/cordis.patch.yml`（机器级偏好）
4. 每个 `--patch <path>` overlay（按 argv 顺序）

列表之外，launcher 还会在 `--patch` overlay 之后再追加一个 patch：当 `DSH_TELEMETRY_DISABLED` 设为任何非空值、且组合里存在 `session-telemetry-otel` 行时，追加 `{ id: 'session-telemetry-otel', disabled: true }`（v0.1.5-rc.2 起就有）。

**后应用者按行胜出，且 patch 替换目标行整个 `config` 值（不是深合并）**。推论：

- 覆盖别层某行（按 `id`）时，必须重述该行需要的每一个键。
- 用户可在自己 profile 的 patch 中覆盖你的行 → 优先给出用户大概率保留的默认值，其余交给 schema。
- 你用 `!!js` 从运行时服务读值时（如 `port: !!js ctx.webStartup.port ?? 8080`），用户 patch 用字面量替换整个 `config` 会连同这次运行时读取一起去掉。
- 内置组合包名（`@deepseek-ai/dsh-base`、`@deepseek-ai/dsh-web-app`、`@deepseek-ai/dsh-headless`、`@deepseek-ai/dsh-sdk-app`、`@deepseek-ai/dsh-sdk-minimal`、`@deepseek-ai/dsh-acp-app`）先从 dsh 安装目录解析，再从 profile 的 `node_modules` 解析；pnpm 只管后者。**安装的包拥有自己的依赖**，组合包可放心依赖 `@deepseek-ai/dsh-base` 存在且与安装一致。


> 本主题的官方文档链接见 `07b-publish-advanced.md` 末尾。
