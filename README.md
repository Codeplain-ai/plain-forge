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

plain-forge ships as a set of skills that plug into your AI coding tool of choice. Install it once, then invoke `forge-plain` (or `add-feature` to add a feature to an existing ***plain project) from any project.

### Install with the `skills` CLI (any runtime)

The fastest way to add plain-forge is the `skills` CLI. The `--all` flag installs **every** plain-forge skill at once:

```bash
npx skills add Codeplain-ai/plain-forge --all
```

#### Install into a specific runtime

If you only use one runtime, pass `--agent` to target just that one (you can repeat the flag to pick several):

```bash
# Just Claude Code
npx skills add Codeplain-ai/plain-forge --all --agent claude-code

# Just Codex
npx skills add Codeplain-ai/plain-forge --all --agent codex

# Just OpenCode
npx skills add Codeplain-ai/plain-forge --all --agent opencode

# Any combination, non-interactive
npx skills add Codeplain-ai/plain-forge --all --agent opencode --agent codex --agent claude-code
```

If you'd rather use the native install flow for a specific runtime, the per-tool instructions below still work.

### Install in Claude Code

Requires the [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and configured. Run the following inside any Claude Code session:

```text
/plugin marketplace add Codeplain-ai/plain-forge
/plugin install plain-forge@plain-forge
```

The first command registers this repository as a plugin marketplace; the second installs the `plain-forge` plugin from it. All plain-forge skills become available in that session.

### Install in Codex

Requires the [OpenAI Codex CLI](https://developers.openai.com/codex/cli/reference) installed and signed in. Run the following from your shell:

```bash
codex plugin marketplace add Codeplain-ai/plain-forge
```

This registers the repository as a Codex marketplace and exposes the `plain-forge` plugin in Codex's plugin directory. Open the plugin directory inside Codex, pick the `plain-forge` marketplace, and install the plugin from there.

### Install in OpenCode

plain-forge also ships an OpenCode-compatible skill set under `.opencode/`. To use it, point OpenCode at this repository — for example by telling the agent:

> "Use the skills in `github.com/Codeplain-ai/plain-forge` (the `.opencode/` directory)."

OpenCode picks up the skills automatically once the repo is in its context.

## Usage

### Prerequisites

1. Open your project folder and start a session in your favorite AI coding agent (Claude Code, OpenCode, Codex, …).
2. Make sure the plain-forge skills are available in that session.

### Starting a new project

1. Invoke `forge-plain` to launch the structured QA workflow.
2. Answer the questions. plain-forge writes the `.plain` files for you as you go through the four phases.
3. Render the specs into code with the [Codeplain](https://codeplain.ai) renderer:

   ```bash
   codeplain <module>.plain
   ```

   plain-forge prints the exact command (with the right final module name) at the end of Phase 4.

### Adding a feature to an existing project

1. Invoke `add-feature`.
2. Describe the feature in plain English. plain-forge runs the same **ask → author → review** loop scoped to that feature and updates the relevant `.plain` file(s).
3. Re-render with `codeplain <module>.plain` to regenerate the code.

### Debugging specs

Hit a bug in the rendered app, a failing test, or behavior that doesn't match what you specified?

1. Invoke `debug-specs`. plain-forge reads the generated code in `plain_modules/` (and the failing tests, if any), traces the issue back to the responsible `.plain` spec, and diagnoses the root cause — **ambiguous spec**, **missing spec**, **conflicting specs**, **incorrect spec**, or a **missing implementation req**.
2. plain-forge applies the fix in the `.plain` file(s) only and summarizes what changed.
3. Re-render with `codeplain <module>.plain` to regenerate the code.

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
| `add-feature` | Interview the user about a single feature, then write all the specs for it |

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
