# 参考资料索引（References）

本目录是 **DeepSeek Harness（DSH）插件开发**的人机可读精简提炼资料，由官方文档站
（https://deepseek-harness.github.io/deepseek-harness/ ）与仓库源码（https://github.com/deepseek-ai/deepseek-harness ）
提炼而成，**不是官方文档的照搬**，而是面向“开发插件”这一目标的高信号浓缩。

使用方式：先读项目根目录的 `SKILL.md`（操作手册），需要深度背景时按需查阅本目录对应文件。

| 文件 | 主题 | 官方对应章节 |
|---|---|---|
| `01-dsh-architecture.md` | DSH 架构总览：CLI、profile、bundle、配置层、插件加载 | guide + develop/basic + 架构 |
| `02-plugin-basics.md` | 第一个插件、三种形态、inject、effect、生命周期、HMR | develop/basic/、framework/、cordis-tutorial 1-2 |
| `03-tools.md` | 工具开发完整参考：defineTool、执行流水线、后台任务、UI 卡片 | develop/basic/tool、cookbook/adding-a-tool、subsystems/tools |
| `04-config.md` | 插件配置与 Schemastery schema | develop/basic/config、cordis-tutorial 5 |
| `05-llm-adapter.md` | LLM 适配器完整指南：LlmAdapter、StreamChunk、GenerateOptions | develop/practice/llm-adapter、cookbook/adding-an-llm-adapter |
| `06-framework-services-events.md` | 服务与依赖、事件系统、生命周期细节 | develop/framework/、cordis-tutorial 3-4 |
| `07-publish.md` | 打包、安装、profile、配置层顺序 | develop/basic/publish |
| `08-capability-layering.md` | 三种角色能力设计 + 能力 seam 目录 | develop/practice/、reference/capability-seams |
| `09-cordis-primer.md` | Cordis 入门：核心概念、分发模式、ctx API 速查 | reference/cordis-primer、cordis-api/* |
| `10-spatiotemporal.md` | 论文《A Programming Paradigm for Spatiotemporal Composability》解读 | [论文原文](https://github.com/cordiverse/paper/blob/main/paper.pdf) |
| `11-cookbook.md` | 扩展模式：权限门禁、UI 插件、协议桥、功能→机制映射 | reference/cookbook/extension-cookbook |

原始材料：

- 官方文档站（中文/英文双语）：`develop/basic/`、`develop/framework/`、`develop/practice/`、`develop/cordis-tutorial/`、`reference/`
- 仓库：https://github.com/deepseek-ai/deepseek-harness
- 论文：《A Programming Paradigm for Spatiotemporal Composability》（DeepSeek-AI / 北京大学，Cordis 框架的学术基础）：
  https://github.com/cordiverse/paper/blob/main/paper.pdf
