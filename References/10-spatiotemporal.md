# 10 · 论文解读：《A Programming Paradigm for Spatiotemporal Composability》

> 本文是对本目录 PDF 的精简解读。论文作者：Yifan Shi、Wei Zhang（北京大学）、Tianyi Cui（DeepSeek-AI）。
> 它给出了 DSH 底层框架 **Cordis** 的形式化基础——理解 DSH 插件“为什么这样设计”的关键。

## 1. 问题：动态组合缺乏形式化基础

现代软件越来越需要**动态组合**（运行时加载/卸载/重配组件）：插件系统、自演化 agent harness 都是。传统组合是静态的（函数调用、模块导入、类继承），而动态组合的两个维度没有成熟理论：

- **时间可组合性（temporal composability）**：组件移除时，它对共享环境的所有修改必须被完全、安全地撤销。
- **空间可组合性（spatial composability）**：组件必须能结构化、可验证地声明/发现/解析相互依赖，并在依赖变化时协调生命周期。

静态情形下，前者退化为词法作用域（RAII），后者退化为模块导入解析；动态情形下两者都变难：effect 的作用域不再词法有界，依赖会出现/消失/换身份。

## 2. 方法：把 effect 与 coeffect 提升为运行时机制

- **可逆效应（revertible effects）**：把每个上下文变换建模为 `Γ → Γ × (Γ → Γ)`——应用后返回新上下文 + 显式逆操作。运行时跟踪并组合这些逆，卸载时按 LIFO 恢复环境，**完整环境恢复成为结构性保证**。
- **反应式余效应（reactive coeffects）**：组件声明它需要的环境约束（依赖）作为 specification；上下文每次变化都对照该 spec 通知组件（激活/停用/中性），依赖关系被声明式地、反应式地管理。

## 3. 上下文范式（Context Paradigm）

把 effect 上下文与 coeffect 上下文统一为**单一上下文类型**（运行时一等的 `ctx`）：effect 侧是可逆变换，coeffect 侧是依赖信息；coeffect 上的观测等价性为 effect 提供独立性。这构成一个编程范式——组件 = 一份 coeffect spec（inject）+ 一个 effect 函数（apply）。

## 4. 动态组合演算与元理论

把两个机制组合成“组件”概念，给出动态组合的演算与操作语义，元理论把时空可组合性从单个组件带到整个交错组件系统：

- **Preservation**（保持） / **Temporal Composability** / **Spatial Composability** / **Progress** / **Confluence**（合流：无论按什么顺序加载/卸载，系统收敛到同一静止状态——这是 loader 对账正确性的基础）。

## 5. 实现：Cordis（三层）

### 5.1 核心库（Core Library）

理论 → 实现的对应（节选）：

| 理论 | 实现 |
|---|---|
| 统一上下文 Γ∞ | `ctx`（一等上下文） |
| effect（可逆） | `ctx.effect(callback)` — 唯一修改上下文的原语；返回 disposer，卸载时恢复 |
| coeffect get/set | `ctx.get(key)` / `ctx.set(key, value)`（经 `@@store` / `@@isolate` / `@@intercept` 三层解析） |
| isolate / intercept | `ctx.isolate(key, realm)` / `ctx.intercept(key, metadata)` |
| 组件实例（fiber） | `fiber`：`fiber.inject`（依赖）、`fiber.apply`（effect 函数）、`fiber.state`（生命周期）、`fiber.dispose`（恢复累加器） |
| 反应式通知 | 服务安装/移除时通知所有声明该 key 的 fiber，`refresh` 重算 target → 重载/卸载 |
| 上下文访问 | Proxy：`ctx[key]` 沿 fiber 链向上解析到 committed 视图；声明了但未提交 → `INACTIVE_ACCESS`；根也没有 → `UNDECLARED_ACCESS`（能力式访问控制） |

关键机制：

- **LIFO 恢复**：每个新逆 prepend 到累加器，卸载按逆序执行。
- **inertial（惯性）状态机**：一旦进入 reload/unload 转换就运行到完成，期间对 target 变化的响应被挂起；转换完成时若 target 不匹配则链入下一转换。这保证系统不会进入半重载状态。
- **服务消失的可见性**：提供方进入 UNLOADING 即“停止提供”，依赖方先于绑定被移除就重算不满足视图并开始自身拆除——依赖方读到的视图在整个加载期（含自身 teardown）保持不变。
- **系统边界**：可独占修改并可恢复的位置在边界内（被跟踪、可恢复）；否则在边界外（操作视为 id，不跟踪）。coeffect 通过“获取阶段”把外部位置重新化：`open` 安装描述符（内部、可逆），`write` 推送数据（外部、不可逆）；对外部排放的恢复靠 withhold 或补偿（compensation）。

### 5.2 组件加载器（Component Loader）

- **声明式配置**：系统描述为持久记录（配置树），loader 把它物化为 fiber 并持续对账。entry 字段：`id`（对账键）、`url`（模块）、`isolate`/`intercept`（注解）、`config`（绑定进 apply）、`disabled`。
- **对账（reconciliation）**：按字段 diff 应用最小破坏性操作——`id`/`url` 变化重建条目；`isolate` 重指派 realm；`intercept` 原地更新；`config` 交给组件（group 条目按子 id keyed diff 递归对账）；`disabled` 卸载/重载。
- **HMR（热模块替换）**：把可逆效应模式提升到模块级。三阶段：模块分类（受 changed 影响且 import 链可达的 accepted / 不能热替换触发全重启的 declined）→ 陈旧条目检测（依赖树触及 accepted 的条目）→ 事务性重载（备份模块缓存 → dispose 旧 fiber → 用新模块 create 新 fiber；任何失败恢复缓存并回滚）。**无需开发者标注接受边界**（对比 Webpack/Vite）。

### 5.3 案例：Koishi

Koishi 是构建在 Cordis 上的开源聊天机器人框架，4000+ 社区插件。验证了：元框架的表达力与通用性（服务端与 web 控制台是两个独立的 Cordis 应用）；时间可组合性零认知负担（作者无需写卸载路径）；跨开放生态的空间可组合性（IM 适配器/数据库驱动/功能插件由不同作者编写，只通过 coeffect 连接即保持一致性）。

## 6. 讨论中的工程启示（对插件开发者有用）

- **服务复用（broker 模式）**：一个接口多个实现的两种形态——排他绑定（同时只绑一个，切换会扰动所有消费方）与服务代理（中央 broker 被注入，多提供方共存，broker 分派；滚动更新/负载均衡/跨进程调用都基于此）。DSH 中 `ctx.llm` 适配器注册表、`ctx.shell` 多提供方就是这种结构。
- **能力式访问控制**：`inject` 声明即能力请求，上下文 proxy 即能力中介；未声明的访问报错。编排者可在加载时审查组件所需能力。
- **语言无关**：时间可组合性要求闭包（逆作为值捕获）；空间可组合性要求声明+通知机制。TypeScript 是当前实现，范式本身语言无关（也解释了 DSH 有 Python SDK 的方向）。

## 7. 与 DSH 插件开发的直接关联

- `ctx.effect` / `ctx.on` / `ctx.plugin` / `ctx.tools.register` 等**全部**是可逆效应：卸载自动恢复——这就是“不要手动清理”的理论依据。
- `inject` 就是 reactive coeffect：服务消失/恢复自动重载，就是通知机制。
- cordis.yml 对账、HMR 事务性重载、服务隔离（isolate）、拦截（intercept）都直接对应论文机制。
- **组件作者的义务**：效应携带的逆必须真的恢复它伴随的效应（运行时不验证 witness）；系统边界外的排放（如已发送的邮件）恢复不了，需要 withhold 或补偿——所以工具描述要如实、破坏性操作要走审批/沙箱。

---

## 官方文档链接

> 本文为精简提炼，官方文档更新时请从以下 URL 获取新内容并修订本文：

- **论文 PDF（原文）**：https://github.com/cordiverse/paper/blob/main/paper.pdf
- **项目仓库**：https://github.com/deepseek-ai/deepseek-harness
- **官方文档站**：https://deepseek-harness.github.io/deepseek-harness/
