# Deepseek Harness Plugin Dev Skill

**English** | [简体中文](README.zh-CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Docs](https://img.shields.io/badge/Docs-DeepSeek%20Harness-blue)](https://deepseek-harness.github.io/deepseek-harness/develop/basic/)

A skill pack that enables **any agent** to develop **DeepSeek Harness (DSH)** plugins correctly, efficiently, and in accordance with the official conventions.

**Core deliverable**: [`SKILL.md`](SKILL.md) — an operating manual an agent can load directly, covering the mental model, copy-pasteable code templates, a step-by-step development workflow, and a verification checklist. Deeper background lives in the condensed reference docs under [`References/`](References/00-INDEX.md).

> Note: the skill itself (`SKILL.md`) and the reference docs are currently authored in Chinese (matching the official DSH documentation). Code templates and API names are language-neutral.

## Highlights

- 🧠 **First-principles based**: turns the "revertible effects + reactive coeffects" theory of Cordis (DSH's underlying framework) into actionable rules and templates
- 🧩 **Covers every plugin type**: Tools (`defineTool`), LLM adapters, service providers/consumers, hooks, configuration, packaging & publishing
- ✅ **Templates verified against the real SDK**: all sample code passes `tsc --strict` type checking and runs end-to-end against the real Cordis loader
- 🔗 **Traceable upstream updates**: every reference doc ends with the official-doc URLs, so content can be revised when upstream changes

## Structure

```
dsh-plugin-dev-skill/
├── SKILL.md                     # Main skill file: the operating manual (read this first)
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

## Install as a DSH skill (optional)

The DSH skill system accepts both directory bundles (`<name>/SKILL.md`) and flat Markdown files (`<name>.md`). Local discovery roots, in priority order:

| Root | Scope |
|---|---|
| `<projectRoot>/.dsh/skills` | Project (rank 100) |
| `<projectRoot>/.agents/skills` | Project (rank 200) |
| `$DSH_HOME/skills` (i.e. `~/.dsh/skills`) | User (rank 400) |

Example — install as a user-level skill:

```sh
mkdir -p ~/.dsh/skills/dsh-plugin-dev
cp SKILL.md ~/.dsh/skills/dsh-plugin-dev/SKILL.md
cp -r References ~/.dsh/skills/dsh-plugin-dev/References
```

The skill name must be kebab-case (`^[a-z0-9]+(?:-[a-z0-9]+)*$`).

## Sources

- Official docs (中文 / English): https://deepseek-harness.github.io/deepseek-harness/develop/basic/
- Source repository: https://github.com/deepseek-ai/deepseek-harness
- Paper: *A Programming Paradigm for Spatiotemporal Composability* (the academic foundation of Cordis): https://github.com/cordiverse/paper/blob/main/paper.pdf

All reference docs are **condensed digests** (not verbatim copies of the official docs), organized around the goal of "developing correct, efficient, convention-compliant plugins".

## Contributing

Issues and pull requests are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first. For security-related matters, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © 2026 green-dalii
