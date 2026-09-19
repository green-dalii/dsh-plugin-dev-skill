# DeepSeek Harness (DSH) Plugin Development Skill

**English** | [简体中文](README.zh-CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Updated](https://img.shields.io/badge/updated-2026--09--19-informational)](CHANGELOG.md)
[![DeepSeek Harness](https://img.shields.io/badge/DeepSeek%20Harness-0.1.5--rc.2-blue)](https://github.com/deepseek-ai/deepseek-harness)
[![deepseek-harness on GitHub](https://img.shields.io/github/stars/deepseek-ai/deepseek-harness?logo=github&label=deepseek-harness)](https://github.com/deepseek-ai/deepseek-harness)
[![Docs](https://img.shields.io/badge/Docs-DeepSeek%20Harness-blue)](https://deepseek-harness.github.io/deepseek-harness/develop/basic/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**An agent skill that teaches any AI coding agent how to develop [DeepSeek Harness (DSH)](https://github.com/deepseek-ai/deepseek-harness) plugins** — correctly, efficiently, and in line with the official conventions.

Load [`SKILL.md`](SKILL.md) and the agent gets the mental model, copy-pasteable code templates, a step-by-step development workflow, and a verification checklist. Deeper background lives in 11 condensed reference docs under [`References/`](References/00-INDEX.md).

**Also known as**: DSH plugin skill, DeepSeek Harness plugin development skill, `dsh-plugin-dev-skill`.

## Contents

- [What this is (and is not)](#what-this-is-and-is-not)
- [Highlights](#highlights)
- [Structure](#structure)
- [Usage](#usage)
- [Install](#install)
  - [As a DSH skill](#as-a-dsh-skill)
  - [In other agent hosts (Claude Code, Codex)](#in-other-agent-hosts-claude-code-codex)
- [FAQ](#faq)
- [Sources](#sources)
- [Related projects](#related-projects)
- [Contributing](#contributing)
- [License](#license)

## What this is (and is not)

- **It is** a documentation-only skill pack: `SKILL.md` is the operating manual, and `References/` holds high-signal digests distilled from the official docs plus the real SDK type definitions.
- **It is not** a plugin, a library, or a fork of DeepSeek Harness — it adds no runtime dependency to your project, and you do not have to install it to write a plugin.
- **It works with** DSH itself, Claude Code, Codex CLI, and any host implementing the open [Agent Skills](https://agentskills.io) standard (a folder containing `SKILL.md` with YAML frontmatter).
- **It targets** `@deepseek-ai/*` **0.1.5-rc.2** (cordis 4.0.2) — the version every API statement was verified against.

## Highlights

- 🧠 **First-principles based**: turns the "revertible effects + reactive coeffects" theory of Cordis (DSH's underlying framework) into actionable rules and templates
- 🧩 **Covers every plugin type**: tools (`defineTool`), LLM adapters, service providers/consumers, hook plugins, configuration, packaging & publishing
- ✅ **Templates verified against the real SDK**: all sample code passes `tsc --strict` type checking and runs end-to-end against the real Cordis loader
- 🔗 **Traceable upstream updates**: every reference doc ends with the official-doc URLs, so content can be re-verified when upstream changes
- 🔄 **Self-updating**: the skill ships a [`VERSION`](VERSION) file and checks for a newer release as its first step on load (`SKILL.md` §0.1)

## Structure

```
dsh-plugin-dev-skill/
├── SKILL.md                     # Main skill file: the operating manual (read this first)
├── VERSION                      # Skill version; SKILL.md §0.1 requires checking it on load
├── llms.txt                     # Machine-readable index for LLM crawlers / answer engines
├── README.md                    # This file (English)
├── README.zh-CN.md              # 中文说明
├── CHANGELOG.md                 # Changelog
├── CONTRIBUTING.md              # Contribution guide
├── SECURITY.md                  # Security policy
├── LICENSE                      # MIT
└── References/                  # Condensed, human/agent-readable reference material
    ├── 00-INDEX.md              # Index
    ├── 01-dsh-architecture.md   # DSH architecture overview
    ├── 02-plugin-basics.md      # Plugin basics: shapes/lifecycle/effect/HMR
    ├── 03-tools.md              # Tool development reference (defineTool)
    ├── 04-config.md             # Plugin configuration & Schemastery
    ├── 05-llm-adapter.md        # LLM adapter guide
    ├── 06-framework-services-events.md  # Services & dependencies, event system
    ├── 07-publish.md            # Packaging/install/profile/config layers
    ├── 08-capability-layering.md# Three-role capability design & seam catalog
    ├── 09-cordis-primer.md      # Cordis primer & ctx API cheat sheet
    ├── 10-spatiotemporal.md     # Paper summary (spatiotemporal composability)
    └── 11-cookbook.md           # Extension patterns (hooks/UI/protocol bridges/feature→mechanism)
```

## Usage

1. **For agents**: load `SKILL.md` and follow its development workflow (recon → implement → verify → deliver); consult the corresponding file under `References/` when deeper background is needed.
2. **For humans**: read `SKILL.md` and `References/` to get a complete picture of DSH plugin development.

> Note: the skill body (`SKILL.md`) and the reference docs are authored in Chinese, matching the official DSH documentation, which is Chinese-first. Code templates, API names and command lines are language-neutral.

## Install

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

Example — install as a user-level skill. The folder name must match the `name` in the SKILL.md frontmatter (`dsh-plugin-dev-skill`), which must be kebab-case (`^[a-z0-9]+(?:-[a-z0-9]+)*$`):

```sh
# Recommended: symlink to a git checkout, so `git pull` keeps it current
git clone https://github.com/green-dalii/dsh-plugin-dev-skill.git ~/src/dsh-plugin-dev-skill
ln -s ~/src/dsh-plugin-dev-skill ~/.dsh/skills/dsh-plugin-dev-skill

# Or: plain copy (must be re-copied to update)
mkdir -p ~/.dsh/skills/dsh-plugin-dev-skill
cp SKILL.md VERSION ~/.dsh/skills/dsh-plugin-dev-skill/
cp -r References ~/.dsh/skills/dsh-plugin-dev-skill/References
```

**Keeping it up to date.** The skill ships a [`VERSION`](VERSION) file and instructs the agent to **check for a newer version as the first step after loading it** (`SKILL.md` §0.1): fetch the remote `VERSION`, compare semantically, and if the remote is newer, update (via `git pull` on a symlinked/checkout install, or re-clone + `rsync` for a plain copy) **before** using the skill. Symlinking is the recommended install shape, because then a single `git pull` updates the loaded skill in place — DSH follows symlinked skill directories (`watchFollowSymlinks` defaults to true), and so do Claude Code and Codex. If the check is impossible (offline, no network, no write access), the agent should say so and continue with the local version rather than silently pretending it checked.

### In other agent hosts (Claude Code, Codex)

This skill follows the open [Agent Skills](https://agentskills.io) standard: a folder with `SKILL.md` plus YAML frontmatter (`name`, `description`, `whenToUse`) and a supporting `References/` folder — the same shape used by Claude Code, Codex, and many other agent hosts. Install it anywhere you install agent skills.

**Option A — let your agent install it (recommended).** Just tell your agent the repo address and let it clone and install the skill itself. For example, paste this into a Claude Code session:

> Install the skill from https://github.com/green-dalii/dsh-plugin-dev-skill into `~/.claude/skills/dsh-plugin-dev-skill/` and load `SKILL.md` when I work on DeepSeek Harness plugin development.

Or into a Codex CLI session:

> Install the skill from https://github.com/green-dalii/dsh-plugin-dev-skill into `~/.agents/skills/dsh-plugin-dev-skill/`.

A generic version that works with any agent:

> Please install the skill from https://github.com/green-dalii/dsh-plugin-dev-skill into your skills directory (folder `dsh-plugin-dev-skill` containing `SKILL.md` and `References/`), then use it whenever the task involves developing DeepSeek Harness (DSH) plugins.

**Option B — manual install:**

| Agent / host | Location | Invocation |
|---|---|---|
| Claude Code (personal) | `~/.claude/skills/dsh-plugin-dev-skill/SKILL.md` | `/dsh-plugin-dev-skill`, or auto-loaded when the description matches |
| Claude Code (project) | `<repo>/.claude/skills/dsh-plugin-dev-skill/SKILL.md` | same |
| Codex CLI (user) | `~/.agents/skills/dsh-plugin-dev-skill/SKILL.md` | browse `/skills`, mention `$dsh-plugin-dev-skill` |
| Codex CLI (repo) | `<repo>/.agents/skills/dsh-plugin-dev-skill/SKILL.md` | same |
| DSH | `~/.dsh/skills/dsh-plugin-dev-skill/SKILL.md` | see [As a DSH skill](#as-a-dsh-skill) |
| Any Agent Skills host | `<skills-dir>/dsh-plugin-dev-skill/SKILL.md` | per host |

```sh
git clone https://github.com/green-dalii/dsh-plugin-dev-skill.git ~/.claude/skills/dsh-plugin-dev-skill
# or symlink it:
ln -s /path/to/dsh-plugin-dev-skill ~/.claude/skills/dsh-plugin-dev-skill
```

Notes:

- Keep the folder name `dsh-plugin-dev-skill` — it must match the frontmatter `name` (Claude Code uses it as the command name).
- Extra frontmatter fields such as `whenToUse` are ignored by hosts that don't support them.
- Bonus: DSH reads `.agents/skills` for project-level skills too, so one copy in `<repo>/.agents/skills/dsh-plugin-dev-skill/` serves both Codex and DSH.

## FAQ

### What is DeepSeek Harness (DSH)?

DeepSeek Harness is an agent harness SDK in which every capability — tools, LLM adapters, filesystem access, sandboxing, persistence, and even the agent loop itself — is a plugin attached to a shared context. There is no privileged kernel to patch: you extend it by mounting plugins. Upstream repository: [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness); documentation: [deepseek-harness.github.io](https://deepseek-harness.github.io/deepseek-harness/develop/basic/).

### Do I need this skill to write a DSH plugin?

No. A minimal plugin is just a module exporting an `apply(ctx)` function, and the official docs cover that. The skill pays off when the plugin has to be *right*: canonical `defineTool` output contracts, revertible-effect cleanup instead of manual teardown, `inject` dependency semantics, Standard-Schema configuration, correct event dispatch modes, and packaging that actually installs.

### What can I build with it?

Tools registered through `defineTool`, LLM adapters (`LlmAdapter.stream()`), service definitions / providers / consumers, hook plugins on `tools/*` and `agent/*` events, UI plugins, protocol bridges (ACP, SDK), background jobs, and publishable bundles or profiles.

### Which agents can load it?

Any host implementing the Agent Skills standard. That includes DSH (project and user skill directories), Claude Code (`~/.claude/skills/`), and Codex CLI (`~/.agents/skills/`) — see [Install](#install).

### Is the skill content in English?

The skill body and reference docs are written in Chinese, matching the official DSH documentation. Code templates, API names, and commands are language-neutral, and both an English and a Chinese README are provided.

### Which DeepSeek Harness version does it target?

`@deepseek-ai/*` **0.1.5-rc.2** together with cordis 4.0.2 — the versions every API statement was verified against, including a `tsc --strict` pass over the templates. Where the official docs run ahead of the published SDK (for example the `ctx.codeRuntime` → `ctx.ptcRuntime` seam rename), the difference is flagged in the relevant reference doc.

### How do I keep the skill up to date?

Install it as a symlink to a git checkout so `git pull` updates it in place. In addition, the skill checks its own version on load: it compares the local `VERSION` against the published one and, if a newer release exists, updates before using itself (`SKILL.md` §0.1). The remote check is a single tiny file fetch and degrades gracefully offline.

### Can an agent install the skill by itself?

Yes. Tell your agent the repository URL and ask it to install the skill into its skills directory — see [Option A](#in-other-agent-hosts-claude-code-codex) above for copy-pasteable prompts.

### How do I report a wrong API or a broken link?

Open an issue or a pull request — see [CONTRIBUTING.md](CONTRIBUTING.md). Every reference doc ends with the official documentation URLs, which makes upstream drift easy to verify and fix.

## Sources

- Official docs (中文 / English): https://deepseek-harness.github.io/deepseek-harness/develop/basic/
- Source repository: https://github.com/deepseek-ai/deepseek-harness
- Paper: *A Programming Paradigm for Spatiotemporal Composability* (the academic foundation of Cordis): https://github.com/cordiverse/paper/blob/main/paper.pdf

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

Issues and pull requests are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. For security-related matters, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © 2026 green-dalii
