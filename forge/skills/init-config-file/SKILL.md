---
name: init-config-file
description: >-
  Build / finalize the `config.yaml` file(s) that the `codeplain` renderer
  consumes. Pulls together every decision made during Phase 3 of `forge-plain`
  (script paths, template directory, build folders, copy/dest behavior, log
  settings) and emits one canonical `config.yaml` per part of the project.
  Run this at the **end of `forge-plain`** (just before `plain-healthcheck`),
  at the end of `add-feature` whenever the testing surface or template
  directory changed, and any time the user wants to regenerate / consolidate
  a project's `config.yaml`.
---

# Init Config File

Always use the skill `load-codeplain-reference` to retrieve the full `codeplain` CLI reference (every flag, the `config.yaml` mapping, and the secrets / per-invocation keys that must never be written to config) — but only if you haven't done so yet. This skill assembles `config.yaml` from the valid CLI-derived keys, so the CLI reference is required.

This skill is the **single authoritative writer** of `config.yaml` for a ***plain project. Anything that ends up in `config.yaml` should go through this skill. The renderer (`codeplain`) reads each key listed below into the same argparse namespace it uses for CLI flags — so a value set in `config.yaml` is exactly equivalent to passing the corresponding `--flag` on the command line.

## When to run

- **End of `forge-plain` Phase 3 / start of Phase 4** — after every test-script decision is locked in (unit tests, conformance tests, prepare-environment), before delegating to `plain-healthcheck`.
- **End of `add-feature`** — only when Phase 3 of the feature touched the testing surface (new script generated, script removed, template directory introduced).
- **End of any single-skill workflow that finalizes a script or template** — e.g. after `implement-unit-testing-script`, `implement-conformance-testing-script`, `implement-prepare-environment-script`, `add-template`, or `create-import-module`.
- **On demand** — when the user asks "rebuild my config", "what valid keys are there", or you discover the config file is hand-edited / inconsistent.

If you only fixed a typo inside a `.plain` file and the testing surface didn't move, you do **not** need to re-run this skill — go straight to `plain-healthcheck`.

## What this skill does

1. Determines **how many** `config.yaml` files the project needs (one per part — see [Per-part split](#per-part-split)).
2. For each config, gathers the decided values from the current project state (existing scripts under `test_scripts/`, the template directory, the build/dest folder choices).
3. Emits a clean, alphabetically-grouped `config.yaml` containing **only** keys that are actually in use, using the canonical key names from the [Valid keys reference](#valid-keys-reference).
4. Verifies that every `*-script` value points at a file that exists on disk under `test_scripts/` (or wherever the user placed it), using the same resolution rule the renderer uses: an absolute path (or a `~` path) is used as-is; a relative path in `config.yaml` resolves against the **config file's directory**. There is no other fallback — the renderer fails fast with a `FileNotFoundError` when a script path doesn't resolve to an existing file.
5. Hands off to `plain-healthcheck` for the full validation pass.

## What this skill does NOT do

- It does **not** generate testing scripts. Use `implement-unit-testing-script`, `implement-conformance-testing-script`, or `implement-prepare-environment-script` first; this skill only wires them in.
- It does **not** decide *whether* the user wants conformance tests, a prepare-environment script, copy-build, etc. Those decisions belong to `forge-plain` Phase 3. This skill only **records** them.
- It does **not** invent values for keys whose decisions weren't made — it leaves them out (the renderer falls back to its default) rather than guessing.
- It does **not** write secrets. `api-key` belongs in the `CODEPLAIN_API_KEY` environment variable, never in `config.yaml`.

## Valid keys reference

The canonical list of keys is derived from the `codeplain` CLI argparse parser. Every key below corresponds to exactly one `--flag` and is read by the renderer through `update_args_with_config`. **No other keys are valid** — the renderer rejects unknown keys with `parser.error(f"Invalid argument: {key}")`.

YAML keys use the **dashed** form (e.g. `unittests-script`, not `unittests_script`) to mirror the CLI flag spelling. The only exception that has historically appeared with underscores is `template_dir`; prefer `template-dir` for new configs but accept either when reading an existing file.

### Keys you typically include

These keys reflect choices made in Phase 3 of `forge-plain` and are the bread and butter of a project's `config.yaml`:

| Key | Type | Default | When to include |
|---|---|---|---|
| `unittests-script` | path (string) | — | **Required.** Every project gets a unit-test runner. A relative path resolves against the config file's directory; the renderer fails fast if the file doesn't exist. |
| `conformance-tests-script` | path (string) | — | Include when the user opted into conformance testing in Phase 3. |
| `prepare-environment-script` | path (string) | — | Include only when both (a) the user opted into a prepare-environment script and (b) `conformance-tests-script` is also set. Setting prepare without conformance is a hard `plain-healthcheck` failure. |
| `test-script-timeout` | int (seconds) | `120` | Include only when the user explicitly raised/lowered the default. |
| `template-dir` | path (string) | — | Include whenever the project has an `import` module or a custom template directory (e.g. `template/`). Required for projects with shared templates. |
| `logging-config-path` | path (string) | `logging_config.yaml` | Points at a **separate** YAML file consumed by Python's `logging.config.dictConfig`. This is the only knob that lets the user actually change log **levels** for the renderer and its dependencies. See [Logging configuration](#logging-configuration) below. Include the key explicitly whenever the project ships a non-default logging config; leave it out only when the user is happy with the renderer's defaults (`INFO` root, `WARNING` for `git`, `ERROR` for `transitions`). |
| `conformance-tests-folder` | string | `conformance_tests` | Include only when the user picked a non-default folder name. |
| `build-folder` | string | `plain_modules` | Include only when the user picked a non-default folder name. Must differ from `build-dest`. |
| `build-dest` | string | `dist` | **Always include with the value `dist`.** This skill pins the copy destination explicitly so every project's `config.yaml` has the same, predictable target folder for the post-render copy. Even though `dist` matches the renderer's default, we still write it out so the choice is visible in the file and protected against future default changes. Must differ from `build-folder`. |
| `base-folder` | string | — | Include when the user wants build output rooted somewhere other than the project root. |

### Keys you occasionally include

These are useful but the defaults are almost always fine. Only include them when the user explicitly changed the default during Phase 3:

| Key | Type | Default | Notes |
|---|---|---|---|
| `copy-build` | bool | `true` | The renderer copies the rendered code to `build-dest` after a successful render. Set to `false` only when the user doesn't want this. |
| `copy-conformance-tests` | bool | `false` | Requires `conformance-tests-script` to also be set. |
| `conformance-tests-dest` | string | `dist_conformance_tests` | Target folder for the conformance-test copy. Must differ from `conformance-tests-folder`. |
| `log-to-file` | bool | `true` | Disable only when the user explicitly does not want a log file. Controls whether logs are mirrored to disk — it does **not** set the log level (that's `logging-config-path`'s job). |
| `log-file-name` | string | `codeplain.log` | If `log-to-file` is `false`, this key must be left out. A relative value set here resolves against the config file's directory; when the key is left out entirely, the default resolves against the `.plain` file's directory. |
| `render-machine-graph` | bool | `false` | Include only when the user wants the state-machine graph rendered. |
| `headless` | bool | `false` | Include only when the project is meant to run in CI / non-interactive mode by default. |
| `force-render` | bool | `false` | Almost never belongs in `config.yaml`; prefer the CLI flag for one-off forced renders. |
| `verbose` | bool | `false` | Almost never belongs in `config.yaml`; prefer the CLI flag for one-off verbose runs. |
| `api` | URL (string) | `https://api.codeplain.ai` | Include only when the user is pointing at a non-default API endpoint. |

### Keys you must NEVER include

These flags are **per-invocation** or **secret**. Putting them in `config.yaml` is always wrong:

| Key | Why it doesn't belong |
|---|---|
| `api-key` | Secret. Belongs in the `CODEPLAIN_API_KEY` environment variable. Never in a file the user might commit. |
| `dry-run` | Per-invocation. `plain-healthcheck` runs the dry-run explicitly; pinning it in the config would make a real render impossible. |
| `full-plain` | Per-invocation preview. Mutually exclusive with `dry-run`. |
| `render-range` | Per-invocation. Selects a slice of functionalities to (re)render. |
| `render-from` | Per-invocation. Mutually exclusive with `render-range`. |
| `replay-with` | Internal / debugging flag. |
| `config-name` | Refers to the config file itself — the renderer ignores it when reading the config. |
| `filename` | The `.plain` file to render is always passed positionally on the CLI. |

If the user asks to put any of these in `config.yaml`, refuse and explain why.

## Logging configuration

Log **levels** are not controlled directly by `config.yaml` — they live in a separate YAML file that the renderer feeds to Python's `logging.config.dictConfig`. The `config.yaml` key `logging-config-path` is the pointer that wires the two together.

### How the renderer assembles logging

From `setup_logging` in the `codeplain` source:

1. The renderer first installs a set of **baseline levels**:
   - root logger → `INFO`
   - `LOGGER_NAME` (the renderer's own logger) → `INFO`
   - `git` → `WARNING`
   - `transitions` → `ERROR`
   - `transitions.extensions.diagrams` → `ERROR`
2. **If** `args.logging_config_path` resolves to an existing file on disk, the renderer loads that YAML and calls `logging.config.dictConfig(...)` on it. This overlays anything from step 1 — the user can raise, lower, or add levels for any logger they care about, add handlers, change formatters, etc.
3. The renderer then attaches its own handlers (TUI handler unless `headless`, file handler if `log-to-file`, crash buffer otherwise). Whatever **level** the root logger ended up at after step 2 is the level those handlers respect.

In other words: `logging-config-path` is the **only** knob that changes the levels. `log-to-file` and `log-file-name` only control *whether and where* logs are written — not *what* gets written.

### Default behavior

- The CLI default value for `logging-config-path` is `logging_config.yaml`, resolved against the **`.plain` file's directory** (like every defaulted path parameter). If a file by that name exists next to the plain file, it will be loaded automatically — even without `logging-config-path` being set in `config.yaml`. A value set in `config.yaml` resolves against the config file's directory; a value passed on the CLI resolves against the invocation directory.
- If the file does not exist, the renderer silently keeps the baseline levels from step 1 above (no warning).
- If the file exists but fails to parse / apply, the renderer warns (`Failed to load logging configuration from …`) and falls back to the baseline.

This means **the mere presence of a `logging_config.yaml` file is itself a config decision.** When you assemble a project's `config.yaml`, you have three cases:

| Situation | What to do |
|---|---|
| The user is happy with the baseline levels and the project has no `logging_config.yaml` on disk. | Leave `logging-config-path` out of `config.yaml`. |
| The user wants custom levels and is fine with the file being named `logging_config.yaml` next to the `.plain` file. | Create that file (see [Recommended logging config](#recommended-logging-config) below). Leaving `logging-config-path` out of `config.yaml` is fine — the default points at it already — but explicitly setting `logging-config-path: logging_config.yaml` is also acceptable and makes the dependency visible to anyone reading the config. |
| The user wants the logging config file to live somewhere non-default (different filename or directory). | Create the file at the chosen path and set `logging-config-path: <that path>` in `config.yaml`. |

When in doubt, ask the user: "Do you want to change the default log levels (INFO for the renderer, WARNING for git, ERROR for transitions), or stick with the defaults?" Only generate / pin the file when they say yes.

### Recommended logging config

When the user does want custom levels, write a minimal `dictConfig`-style YAML file. Example with two common knobs (verbose renderer logs, plus suppression of a chatty third-party logger):

```/dev/null/logging_config.yaml.example#L1-15
version: 1
disable_existing_loggers: false
formatters:
  default:
    format: "%(levelname)s:%(name)s:%(message)s"
handlers:
  console:
    class: logging.StreamHandler
    formatter: default
    level: DEBUG
loggers:
  codeplain:
    level: DEBUG
  urllib3:
    level: WARNING
root:
  level: INFO
  handlers: [console]
```

Guidelines for what to put in this file:

- Always set `version: 1` — `dictConfig` requires it.
- Set `disable_existing_loggers: false` unless the user explicitly wants to silence loggers that were created before `dictConfig` ran. The renderer creates several before it loads this file, and disabling them by default leads to confusing dead silence.
- Only override levels the user actually asked about. Don't preemptively add every logger the codebase touches — that creates ongoing maintenance for no benefit.
- Don't put the `LoggingHandler` / `CrashLogHandler` / `FileHandler` here — the renderer attaches those itself after `dictConfig` runs. Adding them here will cause duplicate log lines.
- This file is **not** validated by `plain-healthcheck`. If you change it, ask the user to confirm by reading it back to them.

## Per-part split

The rule, which mirrors what `forge-plain` Phase 3 already establishes, is **one `config.yaml` per part of the system that has its own testing scripts**:

- **Single-stack project** (e.g. one Python service) → one `config.yaml` at the project root.
- **Multi-part project** (e.g. Python backend + React frontend) → one `config.yaml` per part, placed next to the part's top module (e.g. `backend/config.yaml`, `frontend/config.yaml`). Each config references only its own scripts; **never mix stacks in a single config**.
- A part's split should follow the module boundaries from Phase 1 / Phase 2: if a module has its own language, framework, and test scripts, it gets its own `config.yaml` next to that module.

Before emitting anything, state the planned split to the user (e.g. "I'll emit `backend/config.yaml` and `frontend/config.yaml`") if there is more than one part.

## Workflow

### Step 1 — Inventory

1. List every `.plain` file in the repo and identify the top modules (modules not `requires`-ed by anything else) — same procedure as `plain-healthcheck` Step 1.
2. For each top module, determine which part it belongs to (single-stack → one part; multi-part → one part per top module).
3. List every script under `test_scripts/` and group them by part (e.g. `*_python.sh` belongs to the backend part, `*_js.sh` belongs to the frontend part).
4. Identify the template directory (typically `template/`) and any custom resource directories (typically `resources/`).
5. Read any **existing** `config.yaml` in each part's directory — preserve any user-set fields not listed in [Valid keys reference](#valid-keys-reference) only with the user's explicit approval, and warn that unknown keys will be rejected by the renderer.

### Step 2 — Assemble per-part values

For each part:

1. Start from an empty key set.
2. Add `unittests-script: test_scripts/run_unittests_<lang>.<sh|ps1>` — required. If the script doesn't exist yet, stop and tell the caller to run `implement-unit-testing-script` first.
3. If the part has a conformance script on disk → add `conformance-tests-script: …`.
4. If the part has a prepare-environment script on disk → first verify `conformance-tests-script` is also being added; if not, stop and surface this to the user (offer to either generate the missing conformance script via `implement-conformance-testing-script` or drop the prepare-environment script).
5. If the project has shared templates → add `template-dir: template` (or whatever path the user used).
6. **Always add `build-dest: dist`.** This skill pins the copy destination on every config it writes, regardless of what Phase 3 said about it. If Phase 3 explicitly asked for a different `build-dest`, stop and surface the conflict to the user — do not silently honor the override.
7. For every other key in [Valid keys reference](#valid-keys-reference), include it **only** if Phase 3 produced a non-default decision for that key.
8. Cross-validate the assembled key set:
   - `build-dest` is set to `dist`.
   - `build-folder` ≠ `build-dest` (in particular, `build-folder` is never `dist`).
   - `conformance-tests-folder` ≠ `conformance-tests-dest`.
   - `copy-conformance-tests: true` requires `conformance-tests-script`.
   - `log-file-name` is set ⇒ `log-to-file` is not `false`.
   - All `*-script` paths resolve on disk (absolute / `~` paths as-is; relative paths against the config file's directory — no other fallback; the renderer fails fast on a missing script).
   - No script path crosses stacks (e.g. `backend/config.yaml` must not reference `run_unittests_js.sh`).

### Step 3 — Emit `config.yaml`

For each part, write a clean YAML file:

- One key per line, in the order they appear in [Valid keys reference](#valid-keys-reference) (script paths first, then template/build folders, then copy/log settings).
- Use dashed key names. Quote string values only when YAML requires it.
- No comments inside the file — keep it machine-parseable. If the user needs a comment, put it in the surrounding spec or README.
- Idempotent: re-running this skill on an unchanged project produces a byte-for-byte identical file.

Example for a single-stack Python project with conformance testing and a prepare-environment script:

```/dev/null/config.yaml.example#L1-5
unittests-script: test_scripts/run_unittests_python.sh
conformance-tests-script: test_scripts/run_conformance_tests_python.sh
prepare-environment-script: test_scripts/prepare_environment_python.sh
template-dir: template
build-dest: dist
```

Example for a multi-part project (`backend/config.yaml`):

```/dev/null/config.yaml.example#L1-4
unittests-script: test_scripts/run_unittests_python.sh
conformance-tests-script: test_scripts/run_conformance_tests_python.sh
template-dir: ../template
build-dest: dist
```

### Step 4 — Hand off

Tell the caller exactly which file(s) were written and invoke `plain-healthcheck` to validate the project end-to-end. Do **not** declare success on your own — `plain-healthcheck` is the source of truth for "is this project ready to render?".

## Anti-patterns

- **Inventing values for keys the user never decided on.** Leave them out and let the renderer use its default.
- **Mixing stacks in one config.** `backend/config.yaml` referencing a JS script is always a bug — split into per-part configs instead.
- **Putting `api-key`, `dry-run`, `full-plain`, `render-range`, `render-from`, `replay-with`, `config-name`, or `filename` in `config.yaml`.** All of these are per-invocation or secret; the renderer treats them as command-line concerns.
- **Emitting `prepare-environment-script` without `conformance-tests-script`.** A prepare-environment script only makes sense in service of conformance tests; without one, `plain-healthcheck` will fail.
- **Hand-merging into an existing config.yaml without re-running this skill.** If the user edited the config manually, re-run the skill to re-derive a clean canonical version (after confirming any custom fields with the user).
- **Reading the renderer's API key from a project file.** Always rely on `CODEPLAIN_API_KEY`.

## Validation Checklist

- [ ] One `config.yaml` exists per part of the system (single-stack → root; multi-part → per part).
- [ ] Every `config.yaml` has at minimum `unittests-script`.
- [ ] Every `*-script` value points at a file that exists on disk.
- [ ] No `config.yaml` declares `prepare-environment-script` without also declaring `conformance-tests-script`.
- [ ] No `config.yaml` mixes stacks (every script in it targets the same language).
- [ ] `build-dest` is set to `dist` in every emitted `config.yaml`.
- [ ] `build-folder` ≠ `build-dest`; `conformance-tests-folder` ≠ `conformance-tests-dest`.
- [ ] `copy-conformance-tests: true` only when `conformance-tests-script` is set.
- [ ] `log-file-name` only when `log-to-file` is not `false`.
- [ ] No forbidden keys (`api-key`, `dry-run`, `full-plain`, `render-range`, `render-from`, `replay-with`, `config-name`, `filename`).
- [ ] `template-dir` set whenever the project has shared templates or import modules.
- [ ] `plain-healthcheck` returned `PASS` after the config(s) were written.
