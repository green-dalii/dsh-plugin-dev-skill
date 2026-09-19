# 贡献指南

感谢你愿意为 **Deepseek Harness Plugin Dev Skill** 做贡献！本仓库是文档型项目，欢迎各类改进。

## 目录

- [如何贡献](#如何贡献)
- [内容约定](#内容约定)
- [提交流程](#提交流程)
- [开发与验证](#开发与验证)
- [行为准则](#行为准则)

## 如何贡献

- **修正错误**：发现官方文档或本项目引用有误、链接失效、示例代码不工作，请提交 PR。
- **同步官方更新**：官方文档更新后，`References/` 每篇末尾都有"官方文档链接"，请对照更新并修订对应精炼内容，同时在 `CHANGELOG.md` 记录。
- **新增参考**：若某主题（如新的子系统、新扩展点）值得补充，请遵循下面的内容约定新增或扩展文档。
- **改善技能可用性**：`SKILL.md` 的任何改进——更清晰的模板、更准的铁律、更实用的自查表——都非常欢迎。

## 内容约定

1. **精简提炼，不照搬**：`References/` 是对官方文档的高信号浓缩，不要整段复制官方原文；保留指向官方的 URL。
2. **面向 Agent 与人类**：文档应同时可被 Agent 按步骤执行、可被人类快速阅读。
3. **示例代码必须可运行**：`SKILL.md` 与参考文档中的代码模板需能通过类型检查与端到端运行（见下文"开发与验证"）。
4. **中文为主，保留英文术语**：与官方中文文档保持一致；术语首次出现可附英文。
5. **文件命名**：`References/` 使用 `NN-主题.md`（两位数字序号 + kebab-case），并在 `00-INDEX.md` 登记。

## 提交流程

1. Fork 本仓库并克隆到本地。
2. 创建特性分支：`git checkout -b fix/xxx` 或 `docs/xxx`。
3. 提交变更，提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)（如 `docs: 同步官方文档更新`、`fix: 修正工具模板`）。
4. 推送分支并创建 Pull Request，描述改动内容与验证方式。

## 同步与发布清单（保持徽章与版本一致）

每次「同步官方更新」或发版时，请一次性更新下列位置，避免徽章、正文与实际不符：

| 位置 | 需要更新什么 |
|---|---|
| `VERSION`（单行，如 `0.4.0`） | 技能版本号。**必须与 `SKILL.md` frontmatter 的 `metadata.version`、以及 `CHANGELOG.md` 最新条目标题三处一致** |
| `SKILL.md` frontmatter `metadata` | 同步 `version` 与 `sdk-baseline` |
| `README.md` / `README.zh-CN.md` 徽章行 | `updated-YYYY--MM--DD`（更新日期，双连字符转义）；`DeepSeek Harness-<版本>`（本轮实测适配的 DSH 版本） |
| `SKILL.md` 顶部「SDK 基线」 | 实测所用的 `@deepseek-ai/*` 版本（含 cordis 版本） |
| `References/00-INDEX.md` | 「SDK 基线」说明与术语对照表（上游重命名备忘） |
| `CHANGELOG.md` | 新增版本条目（[Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式） |
| git | 提交、打 tag（`vX.Y.Z`）并推送 |

> `VERSION` 是 Agent 在载入技能时用于比对更新的依据（见 `SKILL.md` §0.1），所以**发版必须同步它**，否则更新检查会失效。

徽章是 shields.io 静态徽章，改完可用下面的命令确认能正常渲染：

```sh
curl -sL "https://img.shields.io/badge/updated-2026--09--19-informational" | grep -o "<title>[^<]*</title>"
curl -sL "https://img.shields.io/badge/DeepSeek%20Harness-0.1.5--rc.2-blue" | grep -o "<title>[^<]*</title>"
```

## 开发与验证

本仓库为纯文档项目，无构建步骤。但涉及 `SKILL.md` 或参考文档中的代码模板变更时，请**实测**验证，不要只做纸面检查：

```sh
# 1. 类型检查：把模板写成 .ts，用真实 SDK 的类型定义跑 tsc --strict
#    （node_modules 指向 DSH 安装树，如 ~/.npm/_npx/<hash>/node_modules）
tsc -p /tmp/dsh-verify/tsconfig.json

# 2. 官方链接有效性：下列 URL 应全部返回 200
grep -rhoE "https://(deepseek-harness\.github\.io|github\.com/deepseek-ai)[^ )>\"]*" SKILL.md References/*.md \
  | sort -u | while read -r u; do printf '%s ' "$(curl -sL -o /dev/null -w '%{http_code}' "$u")"; echo "$u"; done

# 3. 作为技能加载：用真实 DSH skill 注册表挂载本目录，确认 list() / get() 正常
#    （@deepseek-ai/dsh-skill + @deepseek-ai/dsh-skill-filesystem，customSkillDirs 指向本目录父级）
```

注意：官方文档站只发布 `develop/**`、`reference/**` 与 `guide/quickstart`；`architecture`、`glossary`、`event-producer-consumer`、`defensive-patterns` 等**仅存在于仓库**，引用时应给出 GitHub 源码链接。

验证通过后，在 PR 描述中说明验证结果。

## 行为准则

- 友善、专业；评审意见针对代码与内容，不针对个人。
- 尊重原作者的提炼意图：改动应有明确理由，避免无谓的风格翻新。
