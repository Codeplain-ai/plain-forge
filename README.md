<p align="center">
  <img src="assets/plain-forge.png" alt="Plain Forge" width="600" />
</p>

# plain-forge

A conversational spec-writing tool powered by [Claude Code](https://claude.ai/claude-code) and the [***plain](https://plainlang.org) specification language. Describe what you want to build in plain English, and Plain Forge guides you through a structured interview to produce complete `.plain` spec files — which then generate production-ready code via the [Codeplain](https://codeplain.ai) renderer.

## How It Works

Plain Forge turns a conversation into software specs through four phases:

1. **What are we building?** — Define the product, users, and scope.
2. **What technologies?** — Choose language, framework, storage, and testing tools.
3. **How does it work?** — Detail entities, features, user flows, and business rules.
4. **Write the specs** — Plain Forge produces `.plain` files from your answers.

Each phase uses structured questions to eliminate ambiguity. You confirm the output of each phase before moving on.

## Getting Started

Plain Forge ships as a set of skills that plug into your AI coding tool of choice. Install it once, then invoke `/forge-plain` (or `/add-feature`) from any project.

### Install with the `skills` CLI (any runtime)

The fastest way to add Plain Forge to whatever runtime you have installed locally:

```bash
npx skills add https://github.com/Codeplain-ai/plain-forge
```

The `skills` CLI walks you through an interactive setup. When it asks:

```
◇  Installation method
│  Copy to all agents
```

pick **Copy to all agents** so the skills are installed into every runtime (Claude Code, Codex, OpenCode) you have on the machine.

To skip the prompts and install into specific runtimes non-interactively:

```bash
npx skills add https://github.com/Codeplain-ai/plain-forge --agent opencode --agent codex --agent claude
```

If you'd rather use the native install flow for a specific runtime, the per-tool instructions below still work.

### Install in Claude Code

Requires the [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and configured. Run the following inside any Claude Code session:

```text
/plugin marketplace add Codeplain-ai/plain-forge
/plugin install plain-forge@plain-forge
```

The first command registers this repository as a plugin marketplace; the second installs the `plain-forge` plugin from it. All Plain Forge skills become available in that session.

### Install in Codex

Requires the [OpenAI Codex CLI](https://developers.openai.com/codex/cli/reference) installed and signed in. Run the following from your shell:

```bash
codex plugin marketplace add Codeplain-ai/plain-forge
```

This registers the repository as a Codex marketplace and exposes the `plain-forge` plugin in Codex's plugin directory. Open the plugin directory inside Codex, pick the `plain-forge` marketplace, and install the plugin from there.

### Install in OpenCode

Plain Forge also ships an OpenCode-compatible skill set under `.opencode/`. To use it, point OpenCode at this repository — for example by telling the agent:

> "Use the skills in `github.com/Codeplain-ai/plain-forge` (the `.opencode/` directory)."

OpenCode picks up the skills automatically once the repo is in its context.

### Usage

1. Open your project folder and start a session in Claude Code or OpenCode.
2. Make sure the plugin is available
2. Invoke `/forge-plain` to start the QA workflow for a new project, or `/add-feature` to add a feature to an existing one.
3. Answer the questions. Plain Forge writes the `.plain` files for you.
4. Render specs into code using the [Codeplain](https://codeplain.ai) renderer.

## Repository Structure

Plain Forge keeps a single canonical source of truth under `forge/` and uses tiny per-runtime adapters to regenerate the directory layout each AI tool expects. The generated outputs are committed so existing install commands keep working — no build step is needed for end users.

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
| `/forge-plain` | End-to-end QA interview that produces complete `.plain` spec files for a new project |
| `/add-feature` | Interview the user about a single feature, then write all the specs for it |

### Spec Authoring

| Skill | Description |
|-------|-------------|
| `/add-functional-requirement` | Add a feature spec to `***functional specs***` |
| `/add-implementation-requirement` | Add a non-functional requirement to `***implementation reqs***` |
| `/add-test-requirement` | Add a testing requirement to `***test reqs***` |
| `/add-concept` | Define a new concept in `***definitions***` |
| `/add-acceptance-test` | Add verification criteria under a functional spec |
| `/add-resource` | Link an external file (schema, API spec) to a spec |
| `/add-template` | Create or include a reusable Liquid template |

### Module Management

| Skill | Description |
|-------|-------------|
| `/create-import-module` | Create a shared template module (definitions + reqs, no functional specs) |
| `/create-requires-module` | Create a module that depends on a previously built module |
| `/refactor-module` | Split a large module into smaller modules connected via a requires chain |
| `/consolidate-concepts` | Gather scattered concept definitions into a single shared import module |

### Analysis and Quality

| Skill | Description |
|-------|-------------|
| `/analyze-if-func-spec-too-complex` | Check if a spec exceeds the 200-line complexity limit |
| `/analyze-2-func-specs` | Check two specs for conflicts |
| `/break-down-func-spec` | Split an overly complex spec into smaller specs (each ≤ 200 LOC) |
| `/resolve-spec-conflict` | Resolve a conflict between two functional specs |

### Debugging and Testing

| Skill | Description |
|-------|-------------|
| `/debug-specs` | Investigate a bug by tracing generated code back to specs and fixing only the `.plain` files |
| `/implement-testing-scripts` | Create run_unittests, run_conformance_tests, and prepare_environment scripts for a language |
