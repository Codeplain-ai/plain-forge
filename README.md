<p align="center">
  <img src="assets/plain-forge.png" alt="plain-forge" width="600" />
</p>

# plain-forge

A conversational spec-writing tool that runs in any AI coding agent (Claude Code, Codex, OpenCode, and more) and is built on the [***plain](https://plainlang.org) specification language. Describe what you want to build in plain English, and plain-forge guides you through a structured interview to produce complete `.plain` spec files — which then generate production-ready code via the [Codeplain](https://codeplain.ai) renderer.

## How It Works

The main entry point is `forge-plain`. It turns a conversation into ***plain specs through four phases:

1. **What are we building?** — Walk through the product: description, users, scope, core entities, key features, user flows, business rules, and (if applicable) UI behavior. Produces the `***definitions***` and `***functional specs***` for each module.
2. **What technologies should it use?** — Pick the stack and architecture: language, frameworks, data storage, external services, project structure, and any other stack-wide constraints. Produces the `***implementation reqs***`.
3. **How should testing be done?** — Decide the testing strategy: framework, test types in scope, conformance/acceptance tests, environment-preparation scripts, layout, and execution. Produces the `***test reqs***`, any `***acceptance tests***`, the runnable scripts under `test_scripts/`, and the `config.yaml`(s) wiring them in. plain-forge then probes your machine to confirm everything those scripts need is actually installed.
4. **Validate and hand off** — plain-forge identifies the final module in the dependency chain and runs `codeplain <module>.plain --dry-run` itself to catch any static errors (syntax, undefined concepts, broken `import`/`requires` chains, complexity violations, conflicts). It fixes the `.plain` files until the dry-run passes, then hands you the exact `codeplain <module>.plain` command (plus any test scripts) so the real render starts from a clean spec.

Each phase is **incremental**, not a single long questionnaire. plain-forge walks one topic at a time, runs an **ask → author → review** loop on every topic — structured questions, immediate edits to the `.plain` files (and `test_scripts/` / `config.yaml` in Phase 3), then snippet-by-snippet confirmation — and only moves on once every flagged snippet is explicitly approved.

## Getting Started

plain-forge ships as a set of skills, rules, and docs that plug into your AI coding tool of choice. Install it once, then invoke `forge-plain` (or `add-feature` to add a feature to an existing ***plain project) from any project.

### Install with `npx plain-forge install` (recommended)

The primary install path. Works for every supported runtime and is the only installer that ships **all** plain-forge content (skills, rules, **and** docs) — the other methods below are limited or agent-specific.

```bash
npx plain-forge install
```

This prompts you to pick an agent and a scope using an arrow-key menu. You can also pass both flags non-interactively:

```bash
npx plain-forge install --agent claude --scope project
```

**Agent options:**

| `--agent` | Installs into | Use when |
|-----------|---------------|----------|
| `claude` | `.claude/` | You use Claude Code |
| `codex` | `.codex/` | You use the OpenAI Codex CLI |
| `forgecode` | `.forgecode/` | You use ForgeCode |
| `universal` | `.agents/` | You want a runtime-neutral layout that any agent reading from `.agents/` can pick up |

**Scope options:**

| `--scope` | Installs into | Use when |
|-----------|---------------|----------|
| `project` | `./<agent-dir>/` in the current working directory | You want plain-forge in just this project |
| `global` | `~/<agent-dir>/` in your home directory | You want plain-forge available in every project on the machine |

Each install writes three subfolders under the chosen directory:

```
<agent-dir>/
  skills/    # every plain-forge skill
  rules/     # spec-writing rules (loaded as workspace instructions)
  docs/      # shared reference docs
```

Re-running `npx plain-forge install` overwrites the destination silently, so it doubles as the upgrade path — `npx plain-forge@latest install` pulls the newest release every time.

### Alternative install paths (skills only — no rules or docs)

These work but only install the skill files. Rules and docs do **not** travel with them, so use them only if you have a reason not to use `npx plain-forge install`.

#### `npx skills` CLI

```bash
npx skills add Codeplain-ai/plain-forge --skill '*' --agent claude-code
```

Replace `--agent claude-code` with `codex` or `opencode` to target a different runtime, or repeat the flag for several at once.

#### Claude Code native plugin flow

Requires the [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code). Inside a Claude Code session, run the following **three commands** one after the other:

```text
/plugin marketplace add Codeplain-ai/plain-forge
/plugin install plain-forge@plain-forge
/reload-plugins
```

Without the reload the skills won't appear in the current session.

#### Codex native plugin flow

Requires the [OpenAI Codex CLI](https://developers.openai.com/codex/cli/reference). From your shell:

```bash
codex plugin marketplace add Codeplain-ai/plain-forge
```

Then, inside Codex, open the plugin directory, pick the `plain-forge` marketplace, and install the plugin from there. (Codex's CLI does not currently expose a `codex plugin install` equivalent.)

## Usage

### Prerequisites

1. Open your project folder and start a session in your favorite AI coding agent (Claude Code, OpenCode, Codex, …).
2. Make sure the plain-forge skills are available in that session.

### Starting a new project

1. Invoke `forge-plain` to launch the structured QA workflow.
2. Answer the questions. plain-forge writes the `.plain` files for you as you go through the four phases.
3. Render the specs into code (see [Rendering specs](#rendering-specs) below).

### Starting a new project — incremental workflow

If you'd rather skip the full upfront interview and build the specs feature-by-feature, use this lighter loop:

1. Invoke `init-plain-project`. It asks just for the base technology, the project kind, and whether conformance testing is enabled, then scaffolds the project skeleton: `template/base.plain` with the base `***implementation reqs***` and `***test reqs***`, a stub top-level `<project>.plain` (frontmatter only — no functional specs, no concepts), the unit-test script, an optional conformance-test script, an optional prepare-environment script, and a `config.yaml` wired to whichever scripts were generated. No `codeplain --dry-run` is run.
2. From there, either:
   - **Converse with the agent.** Just describe the next feature in plain English; the agent will invoke `add-feature` for you and run its one-question-at-a-time loop until the feature is on disk.
   - **Invoke `add-feature` manually** whenever you want to drive the loop yourself.
3. Repeat step 2 for each feature you want to add. The specs grow incrementally and `plain-healthcheck` is run as the final automated step of every `add-feature` pass.
4. Render the specs into code (see [Rendering specs](#rendering-specs) below).

### Adding a feature to an existing project

1. Invoke `add-feature`.
2. Describe the feature in plain English. plain-forge runs the same **ask → author → review** loop scoped to that feature and updates the relevant `.plain` file(s).
3. Re-render to regenerate the code (see [Rendering specs](#rendering-specs)).

### Rendering specs

Once your `.plain` files are ready (and `plain-healthcheck` is green), render the specs into code with the [Codeplain](https://codeplain.ai) renderer:

```bash
codeplain <module>.plain
```

plain-forge prints the exact command (with the right final module name) at the end of Phase 4.

#### Supervised render (experimental)

If you'd rather have plain-forge babysit the run from your AI coding agent, invoke `run-codeplain`. It launches the renderer for you, tails `codeplain.log`, watches generated code appear under `plain_modules/`, and surfaces what's happening in plain English. If it detects a pathology (stuck conformance loop, complexity error, missing concept, render failure), it asks for approval to stop the renderer, hands off to the right spec-edit skill (`debug-specs`, `resolve-spec-conflict`, `break-down-func-spec`, …), and resumes the render from the last completed functionality via `--render-from`.

This is an **experimental** feature — the default and most reliable way to render is still the manual `codeplain <module>.plain` invocation above.

### Debugging specs

Hit a bug in the rendered app, a failing test, or behavior that doesn't match what you specified?

1. Invoke `debug-specs`. plain-forge reads the generated code in `plain_modules/` (and the failing tests, if any), traces the issue back to the responsible `.plain` spec, and diagnoses the root cause — **ambiguous spec**, **missing spec**, **conflicting specs**, **incorrect spec**, or a **missing implementation req**.
2. plain-forge applies the fix in the `.plain` file(s) only and summarizes what changed.
3. Re-render to regenerate the code (see [Rendering specs](#rendering-specs)).

> **Important:** Never edit generated code under `plain_modules/` or `conformance_tests/` directly — your changes will be overwritten on the next render. Always fix the spec and re-render.


## Repository Structure

plain-forge keeps a single canonical source of truth under `forge/` and uses tiny per-runtime adapters to regenerate the directory layout each AI tool expects. The generated outputs are committed so existing install commands keep working — no build step is needed for end users.

```
forge/                       # canonical, runtime-neutral content
  skills/                    # all skills used during spec writing
  rules/                     # workspace rules for spec validation
  docs/                      # shared docs (PLAIN_REFERENCE.md, etc.)

runtimes/                    # per-runtime adapters
  claude/
    build.ts                 # generates .claude/ + .claude-plugin/ from forge/
    templates/               # Claude-specific files: settings.json, hook script, plugin manifests
  codex/
    build.ts                 # generates .codex-plugin/ and .agents/plugins/ (manifest points at forge/skills/)
    templates/               # Codex-specific files: plugin.json, marketplace catalog
  opencode/
    build.ts                 # generates .opencode/ from forge/
    templates/               # OpenCode-specific files: package.json, .gitignore

bin/
  forge-build.ts             # orchestrator: runs every runtimes/*/build.ts
  lib.ts                     # shared symlink/copy helpers

# Generated outputs (committed, do not edit by hand):
.claude/                     # Claude Code plugin layout
.claude-plugin/              # Claude Code plugin manifests
.codex-plugin/               # Codex plugin manifest (its "skills" field points at forge/skills/)
.agents/plugins/             # Codex marketplace catalog
.opencode/                   # OpenCode plugin layout
```

### Contributing

After editing anything under `forge/` or `runtimes/*/templates/`, regenerate the runtime outputs:

```bash
npm install        # required after every fresh clone (node_modules/ is gitignored)
npm run build      # regenerate runtime outputs for Claude, Codex, OpenCode
npm run clean      # remove generated outputs and rebuild from scratch
```

If `npm run build` errors with `sh: tsx: command not found`, it means `node_modules/` is missing — run `npm install` first.

The build is idempotent — re-running it produces no `git diff`.

## Available Skills

### Core Workflow

| Skill | Description |
|-------|-------------|
| `forge-plain` | End-to-end QA interview that produces complete `.plain` spec files for a new project |
| `init-plain-project` | Lightweight project initializer — scaffolds `template/base.plain` (base impl + test reqs), a stub top-level module, the testing scripts, and `config.yaml`. No functional specs, no concepts, no dry-run. Pair with `add-feature` to grow the project feature-by-feature. |
| `add-feature` | Interview the user about a single feature, then write all the specs for it |
| `run-codeplain` | **Experimental.** Launch a `codeplain` render and supervise it end-to-end — tails `codeplain.log`, watches generated code appear, detects pathologies (stuck conformance loops, complexity errors, missing concepts, render failures), and on approval stops the renderer, hands off to the right spec-edit skill, and resumes with `--render-from`. The default render path is still the manual `codeplain <module>.plain` command. |

### Spec Authoring

| Skill | Description |
|-------|-------------|
| `add-functional-spec` | Add a single feature spec to `***functional specs***` |
| `add-functional-specs` | Add multiple feature specs to `***functional specs***` in one pass (same per-spec checks as `add-functional-spec`) |
| `add-implementation-requirement` | Add a non-functional requirement to `***implementation reqs***` |
| `add-test-requirement` | Add a testing requirement to `***test reqs***` |
| `add-concept` | Define a new concept in `***definitions***` |
| `add-acceptance-test` | Add verification criteria under a functional spec |
| `add-resource` | Link an external file (schema, API spec) to a spec |
| `add-template` | Create or include a reusable Liquid template |

### Module Management

| Skill | Description |
|-------|-------------|
| `create-import-module` | Create a shared template module (definitions + reqs, no functional specs) |
| `create-requires-module` | Create a module that depends on a previously built module |
| `refactor-module` | Split a large module into smaller modules connected via a requires chain |
| `consolidate-concepts` | Gather scattered concept definitions into a single shared import module |

### Analysis and Quality

| Skill | Description |
|-------|-------------|
| `init-config-file` | Build / finalize the project's `config.yaml` file(s) from the decisions made in Phase 3. Knows the full set of valid keys derived from the `codeplain` CLI, refuses to write secrets or per-invocation flags, and produces one config per part of the project. Run at the end of `forge-plain` (just before `plain-healthcheck`) and any time the testing surface changes. |
| `plain-healthcheck` | Verification gate: validates every `config.yaml`, confirms each `*-script` field points at a real file in `test_scripts/`, and dry-runs every top module. Run whenever anything in the project is finalized — at the end of `forge-plain`, at the end of `add-feature`, after `debug-specs`, and after any single-skill edit that touches the renderable surface. |
| `check-plain-env` | Read the project's `.plain` files, `test_scripts/`, `config.yaml`(s), and `resources/`, then probe the host for every requirement **the package manager can't install**: language toolchains (`python` + `pip`, `node` + `npm`, JDK + `mvn`, Go, Rust, .NET, etc.), external services (Postgres, Redis, Docker, ...), system binaries that language packages wrap (`ffmpeg`, `tesseract`, `pdftoppm`, browser binaries, ...), hardware / drivers / accelerators (NVIDIA driver → CUDA toolkit → cuDNN → framework-sees-GPU chain), `codeplain` itself, and credential env vars. Does **not** probe individual language packages — `pip install -r requirements.txt` (and equivalents) handle those when the test scripts run. Emits a `PASS` / `WARN` / `FAIL` report with OS-specific install commands for any gaps. Read-only — never installs anything. Run on first-time setup, before rendering on a new machine, after adding a new tech to a project, or any time `command not found` shows up in test output. |
| `analyze-if-func-spec-too-complex` | Check if a spec exceeds the 200-line complexity limit |
| `analyze-func-specs` | Check a batch of specs (2+) against each other in one call and return every conflicting pair |
| `analyze-2-func-specs` | Legacy: check exactly two specs for conflicts (prefer `analyze-func-specs`) |
| `break-down-func-spec` | Split an overly complex spec into smaller specs (each ≤ 200 LOC) |
| `resolve-spec-conflict` | Resolve a conflict between two functional specs |

### Debugging and Testing

| Skill | Description |
|-------|-------------|
| `debug-specs` | Investigate a bug by tracing generated code back to specs and fixing only the `.plain` files |
| `implement-unit-testing-script` | Generate a per-language unit-test runner (`run_unittests_<lang>.sh` / `.ps1`) |
| `implement-conformance-testing-script` | Generate a per-language conformance-test runner; picks the install-inline or activate-only variant based on whether `prepare_environment_<lang>` exists |
| `implement-prepare-environment-script` | Generate a per-language one-time setup script (`prepare_environment_<lang>.sh` / `.ps1`) that stages the build and pre-warms dependencies so conformance tests start cold; reconciles any existing conformance script to remove its now-redundant install step |
