# 07 · 打包与安装插件

> 精简提炼自 develop/basic/publish。

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

> 没有 `dsh.bundle` 声明的包仍可安装，但只作为普通依赖（`dsh plugin` 打印警告、不激活任何层）。库包就使用这种格式。

## 3. profile 结构（自动维护）

profile 目录含两个文件：

- `package.json` — 树外插件依赖（pnpm 管理）+ `dsh.profile` manifest 及其有序 `bundles` 列表
- `cordis.patch.yml` — 用户自己的 patch 层（每个组合包层之后应用）

profile manifest 从不需要手写，`dsh plugin` 负责创建和维护。

## 4. 安装与移除

```sh
dsh plugin --profile demo add ./hello-plugin     # 首次自动初始化 profile（dsh-base 是第一个 bundle）
dsh --profile demo --dump-config                 # 不启动，验证配置层（看到 "# == dsh-hello-plugin" 层）
dsh --profile demo                               # 启动
dsh plugin --profile demo remove dsh-hello-plugin  # 同时移除依赖和对应层
```

`dsh plugin --profile <name> <args>` 在 profile 目录内转发给 pnpm，所有 pnpm 子命令可用。`add` 支持：本地目录、`github:you/repo`、npm 包名、tarball。

## 5. 配置层顺序（生效配置）

1. `dsh.profile.bundles` 各组合包 patch（按列表顺序）
2. profile 自身的 `cordis.patch.yml`
3. `$DSH_HOME/cordis.patch.yml`（机器级偏好）
4. 每个 `--patch <path>` overlay（按 argv 顺序）

**后应用者按行胜出，且 patch 替换目标行整个 `config` 值（不是深合并）**。推论：

- 覆盖别层某行（按 `id`）时，必须重述该行需要的每一个键。
- 用户可在自己 profile 的 patch 中覆盖你的行 → 优先给出用户大概率保留的默认值，其余交给 schema。
- 内置组合包名称始终从 dsh 安装目录解析；pnpm 只管理树外包 → 组合包可放心依赖 `@deepseek-ai/dsh-base` 存在。

## 6. 从 GitHub 安装：构建脚本这道坎

git 安装拉取的是**源码，不是构建产物**（没有环节运行 `build`）。必须两边各做一件事：

- **作者**：提供自包含的 `prepare` 脚本（pnpm 在 git 安装后运行它），不能假设仅开发环境才有的上下文（如旁边有 monorepo checkout）。参考 [turtle-ui](https://github.com/deepseek-harness/turtle-ui)：`prepare` 用专用 tsdown 配置直接转译 `src/`，不建项目引用、不做类型检查。
- **用户**：pnpm ≥10 默认拒绝 git 依赖的 `prepare`，首次 `add` 会失败；把 pnpm 打印的包键加进 profile 的 `pnpm-workspace.yaml` 的 `allowBuilds` 并重新 `add`：

```yaml
allowBuilds:
  dsh-hello-plugin: true
```

**要如实看待这项授权**：允许该包代码在安装时于你的机器上执行，且不在 agent 沙箱内。只对源码可信的包授权，并锁定 commit（`github:you/hello-plugin#<sha>`）。

**不想让用户授权构建** → 分发构建产物：
- 发布 npm：`pnpm publish` 时构建好 `lib/`。
- 交付 tarball：`pnpm pack`，用户 `dsh plugin add ./hello-plugin-0.1.0.tgz`。

## 7. 表层组合包持有自己的命令行（进阶）

可运行应用的组合包挂载一个普通提供方插件，导出 `inject = ['cmdlineArgs']`，用 `@deepseek-ai/dsh-cmdline` 的 `parseCmdline` 解析共享的不可变参数快照，再在 action 中把应用自有服务提供出去：

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

遇到 `--help` 时提供方不发布该服务 → 这些行不激活。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **打包与安装插件**：https://deepseek-harness.github.io/deepseek-harness/develop/basic/publish
- **CLI 行为参考（源码仓库）**：https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.md
