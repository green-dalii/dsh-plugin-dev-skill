# 07 · 打包与安装插件

> 精简提炼自 develop/basic/publish 与 `apps/cli/reference`（CLI 行为参考）。

## 1. 两个概念：组合包（bundle）与 profile

安装机制基于两个概念，都由 `package.json` 描述，但 manifest 种类不同：

- **组合包（bundle）**：附带一个配置层的 npm 包，manifest 声明 `dsh.bundle`（指向一个 patch 文件）。回答“这个包贡献什么？”——你编写并分发的东西。
- **profile**：位于 `$DSH_HOME/profiles/<name>` 的可启动组合，manifest 声明 `dsh.profile`（有序 `bundles` 列表）。回答“这套配置由哪些组合包按什么顺序组成？”——用户用 `dsh --profile <name>` 启动的东西。

**没有东西同时是两者。**

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

`patch` 的路径相对**声明它的包根目录**解析。没有 `dsh.bundle` 声明的包仍可安装，但只作为普通依赖（`dsh plugin` 打印一次性警告、不激活任何层）；若日后 `update` 到带该声明的版本，会自动激活。库包就使用这种格式。

## 3. profile 结构（自动维护）

profile 目录含三个文件：

- `package.json` — 树外插件依赖（pnpm 管理）+ `dsh.profile` manifest：有序 `bundles` 列表和可选的 `patchReload`（`'live'` 为默认，监视 patch 文件热重载；`'startup'` 只在启动时应用一次）。
- `cordis.patch.yml` — 用户自己的 patch 层（每个组合包层之后应用）。
- `pnpm-workspace.yaml` — pnpm 配置；从 git 安装时的 `allowBuilds` 写在它里面。

profile manifest 从不需要手写：

- `web`、`headless`、`sdk`、`sdk-minimal`、`acp` 首次使用时自动从**随附模板**初始化（如 `web` = base + web-app）。
- `dsh --profile <name> --from-default-profile <template>` 从随附模板派生新的自定义 profile：只复制模板当时的组合包列表与 `patchReload`，**不复制**其依赖与 patch；目标名不能是随附名（另有保留的 `desktop`），且目标目录必须不存在。
- `dsh plugin` 为其他名称初始化一个以 base 为基础的 profile，并维护其中已安装的 bundle 列表。

## 4. 安装与移除

```sh
dsh plugin --profile demo add ./hello-plugin       # 首次自动初始化 profile（dsh-base 是第一个 bundle）
dsh plugin --profile demo add .                    # 相对路径按“调用目录”锚定，装的是当前 checkout
dsh --profile demo --dump-default-config           # 只看组合包各层，不启动
dsh --profile demo --dump-config                   # 再看 profile/home patch 与 --patch overlay（看到 "# == dsh-hello-plugin" 层）
dsh --profile demo                                 # 启动
dsh plugin --profile demo remove dsh-hello-plugin  # 同时移除依赖和对应层
```

- `dsh plugin --profile <name> <args>` 在 profile 目录内转发给 pnpm，所有 pnpm 子命令可用。`add` 支持：本地目录/checkout、`github:you/repo`、npm 包名、tarball；相对 spec（`.`、`../plugin` 及 `file:`/`link:` 形式）会先锚定到调用目录，避免在插件 checkout 里执行 `add .` 时错误地自链 profile。
- 每次成功后 `dsh.profile.bundles` 按安装状态重算：声明了 `dsh.bundle` 的依赖按依赖顺序追加；`update` 后才获得该声明的依赖会自动激活；被移除或不再声明的会移出层栈。
- **组合包成员变化需要重启 profile**（正在运行的 profile 保持本次启动的组合包集合）；profile 与 home 里 `cordis.patch.yml` 的编辑在 `patchReload: live` 时热重载。
- 版本提示：运行时 Cordis 工具（`dsh-tool-cordis` 的 `cordis_define`/`cordis_run` 等）在当前 SDK 0.1.5-rc.2 中是**会话级、进程内**的动态包，重启即清空、不写 profile，**不能**当作持久安装手段；持久安装只有 `dsh plugin` 一条路。官方主线文档已出现 Plugin Manager（`plugin_manager`）用于持久化插件配置，本地 0.1.5-rc.2 尚无该包。

## 5. 配置层顺序（生效配置）

1. `dsh.profile.bundles` 各组合包 patch（按列表顺序）
2. profile 自身的 `cordis.patch.yml`
3. `$DSH_HOME/cordis.patch.yml`（机器级偏好）
4. 每个 `--patch <path>` overlay（按 argv 顺序）

**后应用者按行胜出，且 patch 替换目标行整个 `config` 值（不是深合并）**。推论：

- 覆盖别层某行（按 `id`）时，必须重述该行需要的每一个键。
- 用户可在自己 profile 的 patch 中覆盖你的行 → 优先给出用户大概率保留的默认值，其余交给 schema。
- 你用 `!!js` 从运行时服务读值时（如 `port: !!js ctx.webStartup.port ?? 8080`），用户 patch 用字面量替换整个 `config` 会连同这次运行时读取一起去掉。
- 内置组合包名（`@deepseek-ai/dsh-base`、`@deepseek-ai/dsh-web-app`、`@deepseek-ai/dsh-headless`、`@deepseek-ai/dsh-sdk-app`、`@deepseek-ai/dsh-sdk-minimal`、`@deepseek-ai/dsh-acp-app`）先从 dsh 安装目录解析，再从 profile 的 `node_modules` 解析；pnpm 只管后者。**安装的包拥有自己的依赖**，组合包可放心依赖 `@deepseek-ai/dsh-base` 存在且与安装一致。

## 6. 从 GitHub 安装：构建脚本这道坎

git 安装拉取的是**源码，不是构建产物**（没有环节运行 `build`）。必须两边各做一件事：

- **作者**：提供自包含的 `prepare` 脚本（pnpm 在 git 安装后运行它），不能假设仅开发环境才有的上下文（如旁边有 monorepo checkout）。官方 CLI 参考里的 git 安装示例包是 `github:deepseek-harness/turtle-ui`；关键是 `prepare` 用专用 tsdown 配置直接转译 `src/`，不建项目引用、不做类型检查。
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

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **打包与安装插件**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/publish
- **架构（Profile 与组合包）**：https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.zh.md
- **CLI 行为参考**：https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.zh.md
