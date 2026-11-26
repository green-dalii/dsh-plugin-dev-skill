# AGENTS.md

> Convention file read by CLI agents (Claude Code, Codex CLI, Cursor, DSH skill loader, etc.).
> Humans contributing to this repository should read `CONTRIBUTING.md` instead.

## What this repository is

This is a **documentation-only skill pack** for the **DeepSeek Harness (DSH) Plugin Dev Skill**
(id `dsh-plugin-dev-skill`). There is no runtime code here — the deliverable is a single
`SKILL.md` that an AI coding agent loads into its context window when developing a DSH plugin,
plus the operating manual in `References/`. Verify with `bash scripts/verify.sh`.

## Mandatory flow on entry

1. **Run `SKILL.md` §1 first**: read the local `VERSION`, fetch the latest tag from
   `https://github.com/green-dalii/dsh-plugin-dev-skill`, and update this repository if the
   remote is newer. Use the tag-pinned raw URL form
   `https://raw.githubusercontent.com/green-dalii/dsh-plugin-dev-skill/${TAG}/VERSION`
   (substitute the latest tag for `${TAG}`),
   not the `main` branch URL, to avoid raw.githubusercontent.com CDN cache lag right after a release.
2. **State the SDK baseline**: every API statement in `SKILL.md` and `References/` is verified
   against the version pair `metadata.sdk-baseline` (in `SKILL.md` frontmatter) and `cordis`
   at the version shipped by that baseline (currently `4.2.0-alpha.1`; the `4.1.0` API facts remain valid). If you write a code template, target that pair.
3. **Run `bash scripts/verify.sh`** before claiming a change is complete. It checks:
   - `SKILL.md` YAML frontmatter is legal (kebab-case `name`, `description`, full `metadata`),
   - the version triple `VERSION` / `SKILL.md` `metadata.version` / `CHANGELOG.md` heading
     agrees,
   - official docs URLs return 200 (with CDN retry),
   - `SKILL.md` and every `References/*.md` is at most **8,192 characters**, and `SKILL.md`
     routes to exactly the files present under `References/`.

## What you may modify

| Path | Allowed change |
|---|---|
| `SKILL.md` | Yes — this is the **index layer** (routing rules, invariants, task→file table). Keep it under 8,192 characters. Bump the frontmatter `metadata.version` and add a `CHANGELOG.md` entry in the same edit; if a change does not fit, put it in `References/` and add a route. |
| `References/*.md` | Yes — the operating manual. Each file's top line states the SDK baseline it was last checked against; keep it in sync. **Never let one exceed 8,192 characters: split instead.** |
| `VERSION` | Single-line version. Must match `SKILL.md` `metadata.version` and the newest `CHANGELOG.md` heading. |
| `CHANGELOG.md` | Append a new `[X.Y.Z]` block under `[Unreleased]`. Follow [Keep a Changelog](https://keepachangelog.com/) conventions — record *what* changed, not *why*. The "why" goes here in `AGENTS.md` §Design decisions. |
| `README.md` / `README.zh-CN.md` | Yes — keep badges (`updated-YYYY--MM--DD`, `DeepSeek Harness-<sdk version>`, `skill-<version>`) and the file tree in sync with `SKILL.md` and `VERSION`. |
| `scripts/verify.sh` | Yes — but treat changes here as touching the project's CI gate. Verify locally before pushing. |
| `AGENTS.md` | Yes — this file (incl. Design decisions below). |
| `examples/` (deleted in 0.6.3) | No directory exists. If you think you need one, see Design decisions below. |
| `LICENSE` / `SECURITY.md` / `.github/` | No — without an explicit user request. |

## What you must NOT do

- **Invent API names**: if a method / event / config key isn't in `SKILL.md` or `References/`,
  it likely doesn't exist. Cross-check by reading the official DSH source code at
  `https://github.com/deepseek-ai/deepseek-harness` (or the doc at
  `https://deepseek-harness.github.io/deepseek-harness/`) before writing it down.
- **Quote upstream prose verbatim into `References/`**: the references are condensed digests,
  not copies. Keep the URL back to the source.
- **Mirror upstream `upgrade-guide/*.md` into the repo**: this repository is small and meant
  to be loaded into a context window. Upstream guides are linked from
  `References/13-upgrade-guides.md` as URLs; if the link is ever broken, fix the URL. Local
  copies of upstream prose are not kept in sync.
- **Edit the SDK baseline silently**: changing `metadata.sdk-baseline` is a release-level decision;
  record it in `CHANGELOG.md`.
- **Add a `llms.txt`-style file**: this repository is not a public docs site crawled by answer
  engines; CLI agents read `SKILL.md` directly. If you think you need one, ask the user first.

## When upstream DSH changes

1. **Detect**: run `SKILL.md` §1 update check, or watch the DSH repo's `tags` for new
   `dsh-vX.Y.Z-*` releases.
2. **Inspect**: read the new `docs/upgrade-guide/<version>/<name>/guide.md` files on
   `https://github.com/deepseek-ai/deepseek-harness` (master branch for alpha/rc; tag-pinned
   raw URLs otherwise).
3. **Filter for plugin-dev relevance**: of the ~12 upgrade guides per minor cycle, typically
   only 3–6 do. The rest are about DeepSeek account UI, Desktop keyboard shortcuts, internal
   seams, etc. — don't widen `SKILL.md` to cover them.
4. **Apply**: edit `References/` with the substantive changes and add a row to
   `References/12b-migration-errors.md`; reference the upstream guide by URL in
   `References/13-upgrade-guides.md`. Add to `SKILL.md` only if the rule belongs in the
   ten invariants or the routing table.
5. **Verify**: `bash scripts/verify.sh` must pass before declaring the sync done.

## Design decisions

Recorded here so they survive across releases; CHANGELOG.md only logs *what* changed.

- **`SKILL.md` is an index layer; one file never exceeds 8,192 characters** (since 0.9.0):
  DSH's `compaction-tool-result-pruner` is configured with `thresholdChars: 8192`,
  `headChars: 4096`, `tailChars: 1024` in the `standard`, `ptc` and `cordis` presets alike,
  and it keeps only the head and tail of any over-budget **tool result**. A skill reaches the
  model as a tool result, so at 56,012 characters the old `SKILL.md` (6.8x the threshold) lost
  roughly 91% of its middle on every context compaction — a correctness bug, not a style issue.
  Upstream reached the same conclusion independently: their `dsh-doc/SKILL.md` is 4.6 KB and
  routes to `references/`, and their architecture note (`2026-09-21-creator-skills-progressive-
  disclosure`, archived) cites this exact 8192-character threshold as the reason to move
  recipes out of the leading file. Consequences: `SKILL.md` now carries only routing rules,
  the ten invariants, a version-evolution summary, a task→file index and a pre-delivery
  checklist; `References/` grew from 12 to 25 numbered docs, split rather than rewritten
  (`03`/`03b`/`03c`, `05`/`05b`, `06`/`06b`, `07`/`07b`, `08`/`08b`/`08c`, `09`/`09b`, plus
  new `12`/`12b`/`13`/`14`/`15`). `scripts/verify.sh` gates the budget so it cannot regress.
  **Do not "improve" a doc by letting it grow past 8,192 characters — split it.**

- **No `llms.txt`** (since 0.6.3): this repository is a GitHub docs-style pack loaded into a
  CLI agent's context window, not a public docs site crawled by answer engines. `llms.txt`'s
  target audience (crawlers / answer engines) does not actively `GET` it; the file's 14
  tag-pinned raw URLs must be hand-maintained on every release for zero observed benefit.
  CLI agents read `SKILL.md` directly.
- **`AGENTS.md` exists, `CONTRIBUTING.md` exists, neither subsumes the other** (since 0.6.3):
  `AGENTS.md` is for CLI agents (terse, declarative, table-driven); `CONTRIBUTING.md` is for
  human contributors (narrative, social). They share no overlap beyond a single "sync checklist"
  idea, expressed differently in each.
- **No local mirror of upstream upgrade guides** (since 0.6.3): previously kept under
  `References/_upstream-upgrade-notes/` (12 files, ~20 KB). Removed because (a) nothing in
  `SKILL.md` or `References/` references them by path — only `References/13-upgrade-guides.md`
  mentions upstream guides, and it does so by URL; (b) keeping verbatim upstream text contradicts the
  "References are condensed digests, not copies" rule that `References/*.md` follow; (c) the
  same CDN cache lag that motivates tag-pinned URLs applies to *every* DSH upstream link in
  `SKILL.md`, so mirroring only the upgrade guides is selective local redundancy.
  The 12 guides' substantive changes are folded into `References/12b-migration-errors.md`,
  `References/07b-publish-advanced.md` or the relevant `References/*.md` section — readers
  either see the rule there or follow the `References/13-upgrade-guides.md` link to upstream
  text. No content is lost.
- **No `examples/` directory** (since 0.6.3): previously kept `examples/hello-tool/` as a
  copy-pasteable starter (4 files, ~3.3 KB). Removed because (a) every piece of information in
  it is already in `References/03-tools.md` (the `defineTool` template) and
  `References/07b-publish-advanced.md` (the bundle packaging template), down to file tree,
  `package.json` fields, `cordis.patch.yml` shape, and `src/index.ts` content — no agent that
  has read those files needs to look at examples; (b) the
  examples couldn't typecheck on CI because the DSH SDK is not a public npm package, which
  required an explicit "this isn't typechecked" disclaimer in both the example README and in
  this file — that disclaimer was a workaround for a project-shape mismatch (we'd built
  illustrative skeletons in a pack that should be documentation-only); (c) every SDK-baseline
  bump required a peer-version sync in `examples/hello-tool/package.json`, dragging
  maintenance work onto a file that adds no value once `SKILL.md` is solid. If a future
  contributor wants to add an `examples/`, they should first argue why `SKILL.md` couldn't
  carry that information.
- **UI-layer breaking renames live in `References/14-workflow-and-scope.md` only, not in the manual body** (since 0.7.0, relocated in 0.9.0):
  the 0.2.1-rc.1 ~ 0.2.2-alpha.2 cycle renamed a lot of Client-UI surfaces (context menus,
  Slot paths, `fileDrag` injection, web file download, reasoning `rawText`). `SKILL.md` has
  always declared Host/UI plugin work out of scope, so these changes are **summarized in
  `References/14-workflow-and-scope.md` §2 "覆盖范围边界"** with pointers to the upstream
  guides instead of getting their own sections. Expanding the body's scope would trade a maintained, opinionated boundary for an
  unbounded surface area; a reader who needs the exact rule follows the guide.

## Pointers

- `SKILL.md` — the index layer (read first): routing rules, invariants, task→file table.
- `References/00-INDEX.md` — file overview, SDK baseline, upstream rename glossary.
- `CHANGELOG.md` — full version history (what changed).
- `CONTRIBUTING.md` — human contribution guide.
- `scripts/verify.sh` — baseline check (run by CI and locally before any release).