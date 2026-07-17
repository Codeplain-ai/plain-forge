---
name: load-plain-reference
description: >-
  Loads the applicable ***plain authoring rules and operational references for the current task.
  Covers section ownership, concepts, modules, resources, integrations, rendering, testing, and
  codeplain CLI behavior without loading unrelated guidance. Use when authoring, editing, reviewing,
  or debugging .plain files, or before invoking another skill that reads or writes .plain content.
---

# Load the ***plain reference

Load only the rules and references required for the current task. Files under `../../rules/` are
the source of truth for `.plain` syntax and authoring constraints. Do not restate or override them.

## 1. Account for rules already loaded

- In Claude Code, applicable `.claude/rules/*.md` files are loaded natively. Do not read those rule
  files again.
- In another agent, do not reread a rule whose full content is already present in the current
  context.
- Otherwise, read the applicable files from the routing table below before inspecting or changing
  `.plain` content.

## 2. Load applicable authoring rules

All paths are relative to this `SKILL.md`.

| Task or content | Rule files |
|---|---|
| Definitions or concept usage | `../../rules/definitions.md` |
| Functional specs or acceptance tests | `../../rules/func-specs.md` |
| Implementation requirements or unit tests | `../../rules/impl-reqs.md` |
| Test requirements or conformance tests | `../../rules/test-reqs.md` |
| `import` modules | `../../rules/import-modules.md` |
| `requires` modules | `../../rules/requires-modules.md` |
| `required_concepts` | `../../rules/required-concepts.md` |
| `exported_concepts` | `../../rules/exported-concepts.md` |
| Linked files or `resources/` | `../../rules/linked-resources.md` |
| Any `.plain` text or example | `../../rules/bullet-continuation.md` |

For a whole-file review or a task spanning several sections, load the union of the applicable rule
files. Do not load every rule by default.

## 3. Load integration rules only for integration work

For an integration spec, always read:

- `../../rules/integrations.md`

Then read the rule matching the integration shape:

- Embedded integration: `../../rules/integration-embedded.md`
- Standalone integration: `../../rules/integration-standalone.md`
- Embedded integration test scripts: `../../rules/integration-embedded-testing.md`

Do not load integration rules for ordinary non-integration specs.

## 4. Load operational references only when needed

Authoring rules remain authoritative if a reference appears to conflict with them.

| Need | Reference |
|---|---|
| Project layout, source-of-truth model, templates, or comments | `references/project-model.md` |
| Rendering order, generated artifacts, conformance workflow, or test scripts | `references/rendering-and-testing.md` |
| `codeplain` path resolution or CLI options | Invoke `load-codeplain-reference` |

## 5. Continue with the task

After loading the applicable material, return to the invoking skill or user request. Keep generated
code read-only and route every correction back to the appropriate `.plain` source.
