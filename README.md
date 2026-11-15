# DeepSeek Harness (DSH) Plugin Development Skill

**English** | [简体中文](README.zh-CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Updated](https://img.shields.io/badge/updated-2026--11--15-informational)](CHANGELOG.md)
[![Skill version](https://img.shields.io/badge/skill-0.9.1-brightgreen)](VERSION)
[![deepseek-harness on GitHub](https://img.shields.io/github/stars/deepseek-ai/deepseek-harness?logo=github&label=deepseek-harness)](https://github.com/deepseek-ai/deepseek-harness)
[![Docs](https://img.shields.io/badge/Docs-DeepSeek%20Harness-blue)](https://deepseek-harness.github.io/deepseek-harness/develop/basic/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**Loads in:**<br>
[![DeepSeek Harness](https://img.shields.io/badge/DeepSeek%20Harness-0.2.2--rc.3%20%C2%B7%20official%20compatible-blue)](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.2-rc.3) [![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-informational)](https://code.claude.com/docs/en/skills) [![Codex CLI](https://img.shields.io/badge/Codex%20CLI-compatible-informational)](https://github.com/openai/codex) [![Pi](https://img.shields.io/badge/Pi-compatible-informational)](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md) [![Cursor](https://img.shields.io/badge/Cursor-compatible-informational)](https://cursor.com/docs/context/skills) ![Google Antigravity](https://img.shields.io/badge/Google%20Antigravity-compatible-informational) [![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-compatible-informational)](https://code.visualstudio.com/docs/copilot/customization/agent-skills) [![OpenCode](https://img.shields.io/badge/OpenCode-compatible-informational)](https://opencode.ai/docs/skills/) [![Amp](https://img.shields.io/badge/Amp-compatible-informational)](https://ampcode.com/docs) [![Cline](https://img.shields.io/badge/Cline-compatible-informational)](https://docs.cline.bot) [![Goose](https://img.shields.io/badge/Goose-compatible-informational)](https://goose-docs.ai) [![Kiro](https://img.shields.io/badge/Kiro-compatible-informational)](https://kiro.dev/docs/skills/) [![Kimi Code](https://img.shields.io/badge/Kimi%20Code-compatible-informational)](https://code.kimi.com) ![ZCode](https://img.shields.io/badge/ZCode-compatible-informational) ![Minimax Code](https://img.shields.io/badge/Minimax%20Code-compatible-informational) [![Agent Skills](https://img.shields.io/badge/Agent%20Skills-standard-brightgreen)](https://agentskills.io/clients)

**An agent skill that teaches any AI coding agent how to develop [DeepSeek Harness (DSH)](https://github.com/deepseek-ai/deepseek-harness) plugins** — correctly, efficiently, and in line with the official conventions. It ships a routing index ([`SKILL.md`](SKILL.md)) plus 25 reference docs, each kept under 8,192 characters so it survives DSH's tool-result pruner intact.

It is designed to be **loaded by an agent, not read by a human** — but it also **stacks on DSH's own Creator mode**, which is where it gets interesting: see [Better together](#better-together-with-dshs-creator-mode).

**Also known as**: DSH plugin skill, DeepSeek Harness plugin development skill, `dsh-plugin-dev-skill`.

## Quick Start

You don't install this by hand, and you don't need to read `SKILL.md` yourself. **Paste this into your agent:**

> Install the skill from https://github.com/green-dalii/dsh-plugin-dev-skill into your skills directory (folder `dsh-plugin-dev-skill`, containing `SKILL.md` and `References/`), then use it whenever a task involves DeepSeek Harness plugin development. Start by running its §1 self-update check.

That's the whole setup. The agent clones the repo, drops it where its host discovers skills, and from then on loads `SKILL.md` on its own whenever a task touches DSH plugins — you never invoke it by name.

**On DSH itself** (Desktop, Web, or CLI): switch the session to **Creator** mode first, then paste the same line. Creator mode adds live runtime probes and the ability to install what you build — see [Better together](#better-together-with-dshs-creator-mode).

**On any other Agent Skills host** (Claude Code, Codex CLI, Cursor, …): the same line works — it names no directory on purpose, because the agent already knows where its host loads skills from.

## Better together with DSH's Creator mode

If you drive DSH itself, you have two things available: **DSH's built-in Creator mode** (agent preset `cordis`, which ships the `dsh-doc` skill and the `cordis_inspect_*` probes) and **this skill**. They are complementary, not competing — Creator mode is the hands, this skill is the map. Load both and the agent stops guessing.

| | DSH Creator mode (`dsh-doc` + `cordis_inspect_*`) | This skill |
|---|---|---|
| **Knows** | what the *running* installation actually exposes — live Service methods, event dispatch modes, Client slots, the mounted `packageDir` of any plugin | what the *API surface* is, compressed to 25 docs; what changed between versions; the design rules that make a plugin correct |
| **Can** | install a bundle into the current profile (`install_bundle`), enable/disable rows, read `application` / `warnings` | supply copy-ready TS templates, the 10 invariants, the 110-service seam catalog, and the cumulative migration table |
| **Blind spot** | no cross-version memory: it reads only the installed version's docs and sources | no live view: it never sees your running DSH, and cannot install anything |

**A concrete loop.** Say this in a Creator-mode session:

> Add a plugin to my profile that exports a session as Markdown.

1. Creator mode calls `cordis_inspect_query` to confirm the live `ctx.sessions` / `ctx.storage` signatures.
2. This skill supplies the `defineTool` / service skeleton and the invariants — effect-owned cleanup, `inject` instead of `ctx.get`, every tunable in `Config` — so the first draft is already conventional.
3. Creator mode installs it via `plugin_manager` `install_bundle` and reads back `application: applied`.
4. When an API looks unfamiliar, [`References/12b-migration-errors.md`](References/12b-migration-errors.md) says which release changed it, and [`References/13-upgrade-guides.md`](References/13-upgrade-guides.md) links the upstream guide.

The routing is built in, not left to luck: [`SKILL.md`](SKILL.md) §0 carries the split table, so an agent that has both skills loaded picks per task instead of guessing.

## Contents

- [Quick Start](#quick-start)
- [Better together with DSH's Creator mode](#better-together-with-dshs-creator-mode)
- [What you get](#what-you-get)
- [Why this skill](#why-this-skill)
- [Structure](#structure)
- [Install](#install)
- [Self-Verification](#self-verification)
- [FAQ](#faq)
- [Sources](#sources)
- [Related projects](#related-projects)
- [Contributing](#contributing)
- [License](#license)

## What you get

- **Mental model first**: the "revertible effects + reactive coeffects" theory of Cordis, condensed into 10 invariants any plugin author must follow.
- **Five plugin surfaces covered**: `tool` (`defineTool`), `llm` (adapter), `service` (definition + provider + consumer), `event` (dispatch modes), `bundle` (profile + manifest + Plugin Manager).
- **Templates checked against the real SDK types**: code samples were validated against the baseline SDK when written, and are the ones the maintainers ship with.
- **Cross-version memory**: a cumulative table of breaking changes per release, so an agent knows *when* an API moved instead of rediscovering it.
- **Self-verifying**: ships [`scripts/verify.sh`](scripts/verify.sh) — a one-line baseline check (version consistency + README badge cross-check + frontmatter legality + upstream URL liveness + reading budget and index integrity) that the project's own CI runs on every push.
- **Tag-pinned update check**: see `SKILL.md` §1 and [`AGENTS.md`](AGENTS.md) "Mandatory flow on entry".
- **Traceable upstream**: every topic's official-doc URLs close the last file of that topic (each split part points at its sibling).

For agent entry conventions (what an agent should do when it lands in this repo), see [`AGENTS.md`](AGENTS.md).
## Why this skill

Writing a "Hello World" DSH plugin is one line. Writing a plugin that **is right** — `defineTool` output contract honored, revertible-effect cleanup instead of manual teardown, `inject` dependency semantics, Standard-Schema configuration, correct event dispatch modes, packaging that actually installs — is what this skill encodes.

It is **first-principles based**: every rule is grounded in the academic foundation of the underlying framework (Cordis, [arXiv:2608.25512](https://arxiv.org/abs/2608.25512)) and then turned into copy-pasteable code templates. Every API statement is verified against the real SDK types at the documented baseline (`@deepseek-ai/*` 0.2.2-rc.3, cordis 4.1.0); the templates were validated against those types when written — they are not typechecked in CI, because the DSH SDK is not a public npm package.
## Structure

```
dsh-plugin-dev-skill/
├── SKILL.md                     # Index layer: routing rules, invariants, task→file index (<= 8192 chars)
├── VERSION                      # Skill version; SKILL.md §1 requires checking it on load
├── AGENTS.md                    # Convention file read by CLI agents
├── README.md                    # This file (English)
├── README.zh-CN.md              # 中文说明
├── CHANGELOG.md                 # Changelog
├── CONTRIBUTING.md              # Contribution guide
├── SECURITY.md                  # Security policy
├── LICENSE                      # MIT
├── References/                  # The operating manual (25 docs, each <= 8192 chars)
│   ├── 00-INDEX.md              # File overview, SDK baseline, upstream rename glossary
│   ├── 01-dsh-architecture.md   # DSH architecture: CLI, profile/bundle, config layers, loading
│   ├── 02-plugin-basics.md      # Plugin shapes, runtime/package map, inject/effect, Fiber, HMR
│   ├── 03-tools.md              # Tool basics: defineTool, execute contract, schema vocabulary
│   ├── 03b-tools-advanced.md    # Background jobs, execution policies, UI cards
│   ├── 03c-tools-pipeline.md    # Step admission (`when`), PTC mode, executor plugins
│   ├── 04-config.md             # Configuration & Schemastery
│   ├── 05-llm-adapter.md        # LLM adapter: StreamChunk protocol, GenerateOptions, registration
│   ├── 05b-llm-errors.md        # LLM failure codes, retryChoice, fromFailure, pi-ai 1.3.0
│   ├── 06-services.md           # Services & dependencies: consumer/provider, isolation
│   ├── 06b-events.md            # Event system, dispatch modes, common Harness events
│   ├── 07-publish.md            # Packaging, install, profile, config-layer order
│   ├── 07b-publish-advanced.md  # git install pitfalls, surface bundles, six authoring rules
│   ├── 08-capability-layering.md# Three-role capability design
│   ├── 08b-seams-core.md        # Seam catalog (1): core services
│   ├── 08c-seams-platform.md    # Seam catalog (2): platform/UI services
│   ├── 09-cordis-primer.md      # Cordis primer: concepts, dispatch, Service, Fiber, Loader
│   ├── 09b-cordis-ctx-api.md    # ctx API cheat sheet
│   ├── 10-spatiotemporal.md     # Paper summary (spatiotemporal composability)
│   ├── 11-cookbook.md           # Extension patterns (hooks/UI/protocol bridges/feature→mechanism)
│   ├── 12-mistakes.md           # Common mistakes not tied to a version
│   ├── 12b-migration-errors.md  # Version-tagged breaking changes
│   ├── 13-upgrade-guides.md     # Upgrade-guide index, official links, dsh-doc split
│   ├── 14-workflow-and-scope.md # Four-stage workflow + scope boundaries
│   └── 15-self-update.md        # This skill's own update procedure
├── scripts/
│   └── verify.sh                # Baseline check (version/frontmatter/URLs/char-budget); CI runs it on every push
└── .github/workflows/ci.yml     # GitHub Actions: verify.sh + upstream release signal
```
## Install

The [Quick Start](#quick-start) above is enough. This section is the manual reference — useful when you want a symlinked checkout, or a specific host's directory.

### As a DSH skill

The DSH skill system accepts both directory bundles (`<name>/SKILL.md`) and flat Markdown files (`<name>.md`). Discovery is **not** recursive (`**/SKILL.md` is deliberately unsupported). Local discovery roots, in priority order:

| Root | Scope |
|---|---|
| `<projectRoot>/.dsh/skills` | Project (rank 100) |
| `<projectRoot>/.agents/skills` | Project (rank 200) |
| `customSkillDirs` (host config) | Host-configured (rank 300) |
| `$DSH_HOME/skills` (i.e. `~/.dsh/skills`) | User (rank 400) |
| `$DSH_HOME/../agents/skills` (i.e. `~/.agents/skills`) | User agents home (rank 500) |
| bundled skill directory | Shipped with DSH (rank 600) |

Example — install as a user-level skill. The folder name must match the `name` in the SKILL.md frontmatter (`dsh-plugin-dev-skill`), which must be kebab-case:

```sh
# Recommended: symlink to a git checkout, so `git pull` keeps it current
git clone https://github.com/green-dalii/dsh-plugin-dev-skill.git ~/src/dsh-plugin-dev-skill
ln -s ~/src/dsh-plugin-dev-skill ~/.dsh/skills/dsh-plugin-dev-skill

# Or: plain copy (must be re-copied to update)
mkdir -p ~/.dsh/skills/dsh-plugin-dev-skill
cp SKILL.md VERSION ~/.dsh/skills/dsh-plugin-dev-skill/
cp -r References ~/.dsh/skills/dsh-plugin-dev-skill/References
```

**Keeping it up to date.** The skill ships a [`VERSION`](VERSION) file and instructs the agent to **check for a newer version as the first step after loading it** (`SKILL.md` §1): fetch the latest published tag via `git ls-remote --tags`, then read `${TAG}/VERSION` (tag-pinned, immune to `main` branch CDN cache lag), compare semantically, and if the remote is newer, update (via `git pull` on a symlinked/checkout install, or re-clone + `rsync` for a plain copy) **before** using the skill. Symlinking is the recommended install shape, because then a single `git pull` updates the loaded skill in place — DSH follows symlinked skill directories (`watchFollowSymlinks` defaults to true), and so do Claude Code and Codex. If the check is impossible (offline, no network, no write access), the agent should say so and continue with the local version rather than silently pretending it checked.

### In other agent hosts (Claude Code, Codex, Cursor, …)

This skill follows the open [Agent Skills](https://agentskills.io) standard: a folder named `dsh-plugin-dev-skill` holding `SKILL.md` (with YAML frontmatter `name`, `description`, `whenToUse`) plus a `References/` folder. Any host that loads Agent Skills can load it.

Install it exactly as in [Quick Start](#quick-start): **give your agent the repo URL and let it place the folder wherever its own host loads skills from.** No directory is named above on purpose — the agent knows its host's convention, and hardcoding one host's path only makes the instruction wrong on every other host.

If you prefer to do it by hand, clone it into your host's skills directory and keep the folder name:

```sh
git clone https://github.com/green-dalii/dsh-plugin-dev-skill.git <your-skills-dir>/dsh-plugin-dev-skill
```

Notes:

- The folder name must match the frontmatter `name` — Claude Code uses it as the command name.
- Extra frontmatter fields such as `whenToUse` are ignored by hosts that don't support them.
- DSH also reads `<repo>/.agents/skills`, so a single copy can serve both Codex and DSH.

## Self-Verification

`scripts/verify.sh` is the project's own quality gate. It checks four things:

1. **Version consistency**: `VERSION`, `SKILL.md` frontmatter `metadata.version` and the latest `CHANGELOG.md` heading must be equal; the README badges are separately cross-checked — `skill-<ver>` against `VERSION`, and the release tag in the SDK badge against `metadata.sdk-baseline`.
2. **SKILL.md frontmatter legality**: `name` is kebab-case (`^[a-z0-9]+(?:-[a-z0-9]+)*$`), `description` and `metadata.{version, upstream, sdk-baseline}` are present.
3. **Upstream URL liveness**: every URL in `*.md` that points to `deepseek-harness.github.io`, `github.com/deepseek-ai/`, `github.com/cordiverse`, `arxiv.org`, `registry.npmjs.org`, or `raw.githubusercontent.com` must return exactly `200`. Transient CDN `000` responses are retried up to twice before failing.
4. **Reading budget & index integrity**: `SKILL.md` and every `References/*.md` is at most **8,192 characters** — the `compaction-tool-result-pruner` threshold (`thresholdChars: 8192`, `headChars: 4096`, `tailChars: 1024`; identical in the `standard`, `ptc` and `cordis` presets). A skill is delivered as a tool result, so anything over the line loses its middle on context compaction. The same check asserts `SKILL.md` routes to exactly the files that exist under `References/`.

macOS bash 3 compatible. Honors `SKIP_FRONT=1`, `SKIP_VERSION=1`, `SKIP_URLS=1`, `SKIP_BUDGET=1` for partial runs.

```sh
bash scripts/verify.sh   # exits 0 on green, 1 on any drift
```
## FAQ

### What is DeepSeek Harness (DSH)?

DeepSeek Harness is an agent harness SDK in which every capability — tools, LLM adapters, filesystem access, sandboxing, persistence, and even the agent loop itself — is a plugin attached to a shared context. There is no privileged kernel to patch: you extend it by mounting plugins. Upstream repository: [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness); documentation: [deepseek-harness.github.io](https://deepseek-harness.github.io/deepseek-harness/develop/basic/).

### Do I need this skill to write a DSH plugin?

No. A minimal plugin is just a module exporting an `apply(ctx)` function, and the official docs cover that. The skill pays off when the plugin has to be *right*: canonical `defineTool` output contracts, revertible-effect cleanup instead of manual teardown, `inject` dependency semantics, Standard-Schema configuration, correct event dispatch modes, and packaging that actually installs.

### Does this replace DSH's Creator mode?

No — it stacks on it. Creator mode sees and changes your *running* installation; this skill knows the *API surface* and what changed across releases. See [Better together](#better-together-with-dshs-creator-mode) for the split and a worked example.

### What can I build with it?

Tools registered through `defineTool`, LLM adapters (`LlmAdapter.stream()`), service definitions / providers / consumers, hook plugins on `tools/*` and `agent/*` events, UI plugins, protocol bridges (ACP, SDK), background jobs, and publishable bundles or profiles.

### Which agents can load it?

Any host implementing the Agent Skills standard. The compatibility badges at the top track the ones we follow — DSH is the **officially supported target** (every API statement is verified against it), the rest load the same folder through the standard. Each host resolves skills from its own directory; you don't have to know it, because the agent does (see [Quick Start](#quick-start)).

### Is the skill content in English?

The skill body (`SKILL.md`) and reference docs are written in Chinese, matching the official DSH documentation, which is Chinese-first. Code templates, API names, and commands are language-neutral. Both an English and a Chinese README are provided.

### Which DeepSeek Harness version does it target?

`@deepseek-ai/*` **0.2.2-rc.3** together with cordis **4.1.0** — the versions every API statement was verified against. Since 0.2.0 the headline changes are the `ctx.codeRuntime` → `ctx.ptcRuntime` rename, Plugin Manager shipping with the distribution, the E2B → SSH family swap, the 0.2.1-rc.1 ~ 0.2.2-alpha.2 restructuring (executor plugins, `when`-based tool admission), and the 0.2.2-rc.3 error-contract rework (`@deepseek-ai/dsh-error`, `LLM_FAILURE_CODES`). The full delta is in [`CHANGELOG.md`](CHANGELOG.md) and [`References/12b-migration-errors.md`](References/12b-migration-errors.md).

### How do I keep the skill up to date?

Install it as a symlink to a git checkout so `git pull` updates it in place. You don't have to remember to update it: the skill checks its own version on load — it compares the local `VERSION` against the latest published tag and, if a newer release exists, updates before using itself (`SKILL.md` §1). The remote check is a single tiny file fetch and degrades gracefully offline.

### How do I report a wrong API or a broken link?

Open an issue or a pull request — see [CONTRIBUTING.md](CONTRIBUTING.md). Every topic's official documentation URLs are collected at the end of that topic's last file, which makes upstream drift easy to verify and fix.
## Sources

- Official docs (中文 / English): https://deepseek-harness.github.io/deepseek-harness/develop/basic/
- Source repository: https://github.com/deepseek-ai/deepseek-harness
- Latest tagged release: https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.2-rc.3
- Paper: *A Programming Paradigm for Spatiotemporal Composability* (the academic foundation of Cordis; arXiv:2608.25512): https://arxiv.org/abs/2608.25512

All reference docs are **condensed digests** (not verbatim copies of the official docs), organized around the goal of "developing correct, efficient, convention-compliant plugins".
## Related projects

Other projects by the same author:

| Project | What it is |
|---|---|
| [`green-dalii/dsh-shift-router`](https://github.com/green-dalii/dsh-shift-router) | A **two-tier model router for DSH**: LLM-Judge routing, multi-model fallback chains, exponential-backoff runtime failover, and task-level orchestration. Also a real-world DSH plugin built with the conventions in this skill. |
| [`green-dalii/pi-shift-router`](https://github.com/green-dalii/pi-shift-router) | The original Pi coding-agent extension that `dsh-shift-router` adapts: an LLM judge routes every agent turn to the right model — fast execution for routine work, smart reasoning for hard problems — with multi-model failover. [Homepage](https://shiftrouter.greenerai.top) |
| [`GD4AI/obsidian-llm-wiki`](https://github.com/GD4AI/obsidian-llm-wiki) | Obsidian community plugin (id `karpathywiki`) implementing Karpathy's LLM Wiki: turns notes and PDFs into a linked, LLM-powered knowledge base with entity/concept pages, graph-powered Q&A, and local-first privacy. [Homepage](https://llmwiki.greenerai.top) |
| [`green-dalii/obsidian-llm-wiki-cli`](https://github.com/green-dalii/obsidian-llm-wiki-cli) | Headless ingest CLI (npm [`karpathywiki-cli`](https://www.npmjs.com/package/karpathywiki-cli), `llm-wiki` binary) that runs the plugin's production `WikiEngine` under Node — no Obsidian renderer, zero `obsidian` imports. |
## Contributing

Issues and pull requests are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. For security-related matters, see [SECURITY.md](SECURITY.md). Before opening a PR, run `bash scripts/verify.sh` locally — CI does the same.
## License

[MIT](LICENSE) © 2026 green-dalii
