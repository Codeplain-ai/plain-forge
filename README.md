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

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and configured

### Usage

1. Install the Plain Forge plugin in Claude Code.
2. Open your project folder and start a Claude Code session.
3. Invoke `/forge-plain` to start the QA workflow.
4. Answer the questions. Plain Forge writes the `.plain` files for you.
5. Render specs into code using the Codeplain renderer.

## Repository Structure

```
.claude/
  docs/PLAIN_REFERENCE.md    # Full ***plain language reference
  skills/                    # All skills used during spec writing
  rules/                     # Workspace rules for spec validation
  hooks/                     # Git hooks for spec checks
```

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
