# `examples/hello-tool`

最小可抄的 DSH tool 模板。**写完之后**应当能走完：

1. `dsh plugin add ../hello-tool` 装进你的 profile
2. `dsh --profile demo --dump-config` 看到 `id: hello-tool`
3. 在 Web UI 里问模型："用 hello_tool 跟我说个招呼"
4. 模型最终拿到一条文本 `"Hello, world!"`（或带你的名字）

## 文件

```
hello-tool/
├── package.json          # 声明 dsh.bundle + peerDependencies
├── cordis.patch.yml      # 把自己作为一个 entry 注入
├── src/
│   └── index.ts          # defineTool + Config
└── README.md
```

## 关键点

- `parameters` 用隐式开放对象：`name: { type: 'string', required: false }`。**不要**写 `required: false`——它是类型错误；不写即默认可选。
- `output.schema = { type: 'string' }`；`output.render` 是纯函数。
- `execute` 返回 `output.schema` 声明的**规范 JSON 值**（这里是字符串），不是给人看的句子；给模型看的文本由 `output.render` 投影。
- `config.greeting` 在 `cordis.patch.yml` 默认 `"Hello"`；用户可在自己 profile 的 `cordis.patch.yml` 里整行覆盖（patch 不做深合并）。
- `peerDependencies` 声明 `@deepseek-ai/dsh-tools: 0.2.0-rc.2`——0.2.0 起这是硬契约。

## 怎么改成你自己的 tool

1. 改 `package.json` 的 `name` 与 `peerDependencies`（保留与 `@deepseek-ai/dsh-tools` 的 peer）。
2. 改 `cordis.patch.yml` 的 `id`（保持 stable——它是 Loader 对账键）。
4. 改 `src/index.ts` 里的 `name`、工具 `name`、`description`、`parameters`、`output.schema`、`output.render`、`execute`。

## 上手前请通读

- [SKILL.md §4 定义工具](../../SKILL.md)（铁律 + 参数 DSL 陷阱）
- [References/03-tools.md](../../References/03-tools.md)（完整契约、流水线、后台任务）
- [References/04-config.md](../../References/04-config.md)（Schemastery + `!!js`）

## 关于"能不能 `npm install`"——不一定

`@deepseek-ai/dsh-tools` 是 DSH 自带的 SDK，由 DSH 安装目录解析，并非公开 npm 包。本 example 的运行**依赖你已经按 `SKILL.md` §0.1 装好了 DSH**（即 `~/.dsh/` 或 `$DSH_HOME/profiles/<name>/node_modules` 已就绪），然后通过 `dsh plugin add <本地路径>` 把这个目录作为「组合包成员」加入 profile——不需要 `npm install` 它。

如果你想把它发布为可被远端 `dsh plugin add <name>` 使用的 npm 包，则需要在你的注册表（如 npmmirror）发布一个同名同版本的包，让 DSH 0.2.0 的 peer 兼容契约（见 `SKILL.md` §10）能校验通过。