# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`plain-forge` is an **npm-distributed installer CLI**. Its job is to copy a tree of authoring content (skills, rules, docs) into an AI coding agent's directory (`.claude/`, `.codex/`, `.forgecode/`, or `.agents/`) so that agent can help users write `***plain` specs for the [codeplain](https://codeplain.ai) renderer.

There are two distinct kinds of content here, and they almost never change together:

- **The CLI** (`bin/cli.mjs`) — the install/update/uninstall machinery. This is the only executable code in the repo.
- **The payload** (`forge/skills/`, `forge/rules/`) — Markdown skills and rules that get copied verbatim onto disk. Editing a skill is editing documentation/prompts, not program logic.

## Commands

```bash
npm test                  # run the full test suite (node --test over test/**/*.test.mjs)
node --test test/cli.test.mjs                       # run one test file
node --test --test-name-pattern "compareVersions" test/cli.test.mjs   # run tests matching a name

node bin/cli.mjs install --agent claude --scope project   # exercise the CLI locally
node bin/cli.mjs update
node bin/cli.mjs uninstall --agent claude --scope project
```

There is **no build step.** Install copies `forge/` straight to disk. The `build`/`clean` scripts in `package.json` (and the `runtimes/**` glob in `tsconfig.json`) reference `bin/forge-build.ts` and a `runtimes/` directory that do not exist — they are stale; ignore them. `tsx`/`typescript` are devDependencies but unused; there are no runtime dependencies.

## Architecture of the CLI (`bin/cli.mjs`)

A single ~700-line ESM file, pure Node stdlib, no deps. It exports its internals at the bottom so `test/cli.test.mjs` can unit-test them directly (alongside spawning the CLI as a subprocess for end-to-end checks). Keep that export list in sync when adding testable helpers.

The whole design centers on the **install manifest** at `<agent-dir>/.plain-forge/manifest.json`, which records exactly which files plain-forge wrote. This is what lets `update` and `uninstall` touch only plain-forge's own files and never the user's or third-party skills sharing the same directory.

- `AGENTS` maps an agent name → its directory (`.claude`, etc.); `SCOPES` is `project` (cwd) vs `global` ($HOME). `CONTENT_DIRS` = `skills`, `rules`, `docs` — note `forge/docs/` may not exist; `copyTreeTracked` silently skips a missing source dir, so `docs` is effectively optional.
- **install** (`cmdInstall`): refuses if a manifest OR a signature install already exists; otherwise `writeContent` copies the tree and `writeManifest` records it.
- **update** (`cmdUpdate`): `detectInstalls` scans both scopes × all agents; `isUpToDate`/`compareVersions` skip installs whose manifest version ≥ package version; re-copies, then **prunes** files in the old manifest but not the new copy (`collectPruneCandidates`), confirming each deletion unless `--yes`.
- **uninstall** (`cmdUninstall`): deletes exactly the manifest's files, then the manifest, then empties upward. **Refuses** if there's no manifest (can't tell which files are ours).
- **Legacy detection**: installs predating manifests are recognized by `hasForgeSignature` — all of `FORGE_SIGNATURE_SKILLS` present. Legacy installs are refreshed without pruning and gain a manifest going forward.

Two non-obvious invariants the code documents in comments and tests enforce:
- Non-TTY runs never delete anything without `--yes` (`promptConfirm` returns false when stdin isn't a TTY).
- `isInvokedDirectly` realpath-resolves both `argv[1]` and `import.meta.url` so the CLI still runs when invoked through a symlinked bin (npx / global install) but stays dormant on `import` from tests.

When changing prune/uninstall/detection logic, update the manifest format and the legacy-signature list together — a mismatch silently strips or orphans users' installs.

## The `forge/` payload

`forge/skills/` holds ~29 skills (each a directory with `SKILL.md` and frontmatter `name`/`description`); `forge/rules/` holds the `***plain` spec-writing rules installed as workspace instructions. This content is the product — the README documents what each skill does. When editing skills, you are writing the prompts/instructions the downstream agent follows; match the existing one-question-at-a-time, write-immediately authoring style described in the skills themselves. The skills operate on `.plain` spec files and treat generated code under `plain_modules/` as a read-only artifact — never a place to edit.

`package.json` ships only `bin/cli.mjs` and `forge/` to npm (see `files`), so anything outside those (README, tests, assets) is dev-only and not delivered to users.
