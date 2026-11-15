# 15 · 本技能的自我更新流程

> SDK 基线：`@deepseek-ai/*` **0.2.2-rc.3**（cordis **4.1.0**）。

> 本技能会随官方 DSH 演进而更新。**每次载入本技能后先执行本文件第 1 节**；不是最新版就先更新，再开始干活。
> 这一节刻意做得很短成本很低（一次几字节的 GET），但跳过它的代价是写出编译不过或语义不对的插件。

## 1. 强制流程：载入后第一件事是检查更新

**本技能会随官方 DSH 演进而更新。每次载入本技能后，先确认自己用的是最新版；若不是最新版，先更新、再开始用它干活。**
理由很实际：上游有过破坏性改名（`Code Mode` → PTC mode、`CallId` → `ToolCallId`、`ctx.codeRuntime` → `ctx.ptcRuntime`、profile manifest 删除 `patchReload`），用过期版本会写出**编译不过或行为不对**的插件。

1. **读本地版本**：`VERSION` 文件与`SKILL.md` 同目录，内容形如 `0.6.0`（frontmatter 的 `metadata.version` 是同值副本）。
   - 若**没有** `VERSION` 文件（例如只拷贝了 `SKILL.md` 的残缺安装），视为**旧版本，直接执行第 4 步更新**。
2. **取远端版本**（一次约 5 字节的 GET，用短超时，不要拖慢主任务）—— 为了抗 `raw.githubusercontent.com` 的 CDN 缓存延迟（曾观测到刚 `git push` 后 5+ 分钟内 `main` 分支 raw URL 仍返回旧文件），**优先读 tag-pinned URL**（tag 不会被新提交覆盖，永远指向同一个发布）：
   ```sh
   # 1) 先问最新 tag（成本几乎为零）
   TAG=$(git ls-remote --tags --sort=-v:refname https://github.com/green-dalii/dsh-plugin-dev-skill.git | awk -F/ '/refs\/tags\/v/ {print $3; exit}')
   # 2) 用 tag 钉住的 raw URL 读 VERSION —— 这一份保证是「最新发布」而非「main 分支的 CDN 缓存」
   curl -fsSL --max-time 8 "https://raw.githubusercontent.com/green-dalii/dsh-plugin-dev-skill/${TAG}/VERSION" | tr -d '[:space:]'
   ```
   把拿到的远端版本记为 `REMOTE`。再读 `main` 分支 raw URL 拿到的版本记为 `MAIN`：如果两者**不一致**（CDN 延迟，main 落后于 tag），**以 tag-pinned 的 `REMOTE` 为准**—— `MAIN` 是「远端最终会稳定到的值」。若 `git ls-remote` 也失败，退而求其次：
   ```sh
   curl -fsSL --max-time 8 https://raw.githubusercontent.com/green-dalii/dsh-plugin-dev-skill/main/VERSION | tr -d '[:space:]'
   ```
3. **比较（语义化版本）**：
   - 远端 **高于** 本地 → 执行第 4 步，更新完再继续。
   - 两端**相同** → 直接用。
   - 远端 **低于** 本地 → 说明本地是开发中的更新版，**不要降级**，直接用。
4. **更新到最新版**，按安装形态二选一：
   - **符号链接 / git 检出**（推荐形态）：
     ```sh
     cd "$(readlink -f <本 SKILL.md 所在目录>)" && git pull --ff-only
     ```
     若该目录不是 git 仓库（纯拷贝安装），改用下一条。
   - **普通拷贝**：
     ```sh
     git clone --depth 1 https://github.com/green-dalii/dsh-plugin-dev-skill /tmp/dsh-plugin-dev-skill-new
     rsync -a --delete --exclude .git /tmp/dsh-plugin-dev-skill-new/ <本 SKILL.md 所在目录>/
     ```
   更新后**重新读取 `SKILL.md` 与本次要用到的 `References/`**——内容可能已变（尤其是 API、术语与包名）。
5. **无法联网 / 检查失败时**：不要卡住，也不要假装检查过。明确说一句「未能检查 skill 更新（原因）」，然后基于当前本地版本继续工作，并在需要新 API 时提示用户可能存在版本差异。
6. **同一会话内**：已成功比较过且远端版本未变时，可以跳过重复检查（不必每次工具调用都发请求）；但**每次载入技能都要检查**。
7. **怀疑基线漂移时**：跑 `bash scripts/verify.sh`（在仓库根目录）做一次完整复核——版本三处一致、SKILL.md frontmatter 合法、官方链接全部 200。CI 也会跑它。

> 检查成本是一个几字节的 GET，而用过期技能写出编译不过或不符合规范的插件，代价要高得多。
