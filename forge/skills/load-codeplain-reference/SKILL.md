---
name: load-codeplain-reference
description: >-
  Loads the full `codeplain` CLI reference into context: the render command and
  its positional plain-file argument, every flag (render control, config,
  folders, test-script wiring, output copying, API, logging, headless mode),
  path-resolution rules, the CODEPLAIN_API_KEY environment variable, the
  config.yaml mapping, and the success/failure render banners. Use whenever
  running, configuring, resuming, or reasoning about a `codeplain` render or its
  config.yaml. Not for the ***plain language syntax itself (use
  load-plain-reference) or for supervising a live render (use run-codeplain).
---

# CODEPLAIN_CLI_REFERENCE.md

`codeplain` is the CLI that renders `***plain` specification files into production-ready code. It reads a `.plain` module (and everything it `import`s / `requires`), calls the codeplain API, and writes generated code under `plain_modules/` and conformance tests under `conformance_tests/`. The `.plain` specs are the source of truth; the generated code is a read-only artifact.

This reference covers the CLI surface only. For the `***plain` language itself use `load-plain-reference`; to supervise a live render use `run-codeplain`; to assemble or validate `config.yaml` use `init-config-file` / `plain-healthcheck`.

## Usage

```text
codeplain [options] filename
```

```text
usage: codeplain [-h] [--verbose] [--base-folder BASE_FOLDER]
                 [--build-folder BUILD_FOLDER]
                 [--log-to-file | --no-log-to-file]
                 [--log-file-name LOG_FILE_NAME] [--config-name CONFIG_NAME]
                 [--render-range RENDER_RANGE | --render-from RENDER_FROM]
                 [--force-render] [--unittests-script UNITTESTS_SCRIPT]
                 [--conformance-tests-folder CONFORMANCE_TESTS_FOLDER]
                 [--conformance-tests-script CONFORMANCE_TESTS_SCRIPT]
                 [--prepare-environment-script PREPARE_ENVIRONMENT_SCRIPT]
                 [--test-script-timeout TEST_SCRIPT_TIMEOUT] [--api [API]]
                 [--api-key API_KEY] [--full-plain] [--dry-run]
                 [--replay-with REPLAY_WITH] [--template-dir TEMPLATE_DIR]
                 [--copy-build] [--build-dest BUILD_DEST]
                 [--copy-conformance-tests]
                 [--conformance-tests-dest CONFORMANCE_TESTS_DEST]
                 [--render-machine-graph]
                 [--logging-config-path LOGGING_CONFIG_PATH] [--headless]
                 filename
```

## Positional argument

- **`filename`** — path to the `.plain` file to render. The directory containing this file has the **highest precedence for template loading**, so custom templates placed there override the defaults (see `--template-dir`). Render the **top module** of the dependency chain — the module not `requires`-ed by any other; its `requires`/`import` graph is pulled in automatically.

## Path resolution (read this before setting any path flag)

A path's meaning depends on **where it was written**:

- Values given **on the command line** resolve against the **current working directory**.
- Values read from **`config.yaml`** resolve against the **config file's directory**.
- **Default** values resolve against the **directory containing the `.plain` file**.
- **Absolute paths** (and paths starting with `~`) are used as-is.

## Options

### Render control

- **`--dry-run`** — preview code generation without making any changes. This is the static-validation gate; `plain-healthcheck` runs `codeplain <top>.plain --dry-run` for every top module before a real render. **Per-invocation only — never store in `config.yaml`.**
- **`--full-plain`** — full preview of the assembled `***plain` specification before code generation. Use to inspect the context of all `***plain` primitives that will be included to render the given module. **Per-invocation only — never in `config.yaml`.**
- **`--render-range RENDER_RANGE`** — render a range of functionalities (e.g. `1`, or `2,3`). A comma separates the start and end IDs; the range is inclusive of both. A single ID renders only that one functionality. Mutually exclusive with `--render-from`. **Per-invocation only — never in `config.yaml`.**
- **`--render-from RENDER_FROM`** — continue generation starting from this functionality ID (inclusive). The ID must match a functionality in the `.plain` file. This is how a run resumes after a spec fix — pass the **first functionality to re-render**. Mutually exclusive with `--render-range`. **Per-invocation only — never in `config.yaml`.**
- **`--force-render`** — force a re-render of all required modules, invalidating cached module renders. Use only when a backward dependency genuinely changed; it costs more credits.
- **`--replay-with REPLAY_WITH`** — replay a previous render. **Per-invocation only — never in `config.yaml`.**

### Configuration

- **`--config-name CONFIG_NAME`** — name of the config file to look for. It is looked up in the `.plain` file's directory and in the current working directory. Defaults to `config.yaml`. Use it for multi-part projects (one config per part) or a non-default config file name.

### Folders

- **`--base-folder BASE_FOLDER`** — base folder for the build files.
- **`--build-folder BUILD_FOLDER`** — folder for build files (generated code lands under here, per module: `plain_modules/<module>/`).
- **`--template-dir TEMPLATE_DIR`** — path to a custom template directory. Templates are searched in this order: 1) the directory containing the `.plain` file, 2) this custom template directory, 3) the built-in `standard_template_library` directory. In `config.yaml` the equivalent key is `template_dir` — set it whenever the project has import modules or templates.

### Test-script wiring

- **`--unittests-script UNITTESTS_SCRIPT`** — shell script that runs unit tests on the generated code. Receives the build folder path as its first argument (default: `plain_modules`). `config.yaml` key: `unittests-script`.
- **`--conformance-tests-folder CONFORMANCE_TESTS_FOLDER`** — folder for conformance test files.
- **`--conformance-tests-script CONFORMANCE_TESTS_SCRIPT`** — path to the conformance-tests shell script. It must accept two arguments: 1) a folder containing generated source code (e.g. `plain_modules/module_name`), and 2) a subfolder of the conformance-tests folder containing the test files (e.g. `conformance_tests/subfoldername`). `config.yaml` key: `conformance-tests-script`.
- **`--prepare-environment-script PREPARE_ENVIRONMENT_SCRIPT`** — path to a shell script that prepares the testing environment. It must accept the source-code folder path as its first argument. It runs once per render, only to warm the environment the conformance runner attaches to. `config.yaml` key: `prepare-environment-script`. If this is declared, `conformance-tests-script` must be declared too.
- **`--test-script-timeout TEST_SCRIPT_TIMEOUT`** — timeout for test scripts, in seconds. Defaults to 120 seconds. Raise it if the project's test scripts are slow.

### Output copying

- **`--copy-build`** — after a successful render, copy the rendered code in `--base-folder` to `--build-dest`.
- **`--build-dest BUILD_DEST`** — target folder for `--copy-build` (used only when `--copy-build` is set).
- **`--copy-conformance-tests`** — after a successful render, copy the conformance tests in `--conformance-tests-folder` to `--conformance-tests-dest`. Requires `--conformance-tests-script`.
- **`--conformance-tests-dest CONFORMANCE_TESTS_DEST`** — target folder for `--copy-conformance-tests` (used only when it is set).

### API

- **`--api [API]`** — alternative base URL for the API. Default: `https://api.codeplain.ai`.
- **`--api-key API_KEY`** — API key used to access the API. If not provided, the `CODEPLAIN_API_KEY` environment variable is used. **Secret — never store it in `config.yaml`.**

### Logging & output mode

- **`--verbose`, `-v`** — enable verbose output. Verbose logging captures each test script's stdout/stderr into the log file between the renderer's own wrapper lines, which is what makes a live render inspectable. Keep logging verbose.
- **`--log-to-file` / `--no-log-to-file`** — enable or disable logging to a file. Defaults to `True`; pass `--no-log-to-file` to disable.
- **`--log-file-name LOG_FILE_NAME`** — name of the log file. Defaults to `codeplain.log`. If a file already exists at the resolved path, it is **overwritten** by the current run's logs — the log is therefore per-run, and its default location is the `.plain` file's directory.
- **`--logging-config-path LOGGING_CONFIG_PATH`** — path to a logging configuration file.
- **`--headless`** — run without the TUI: no terminal output except a single render-started message; all logs are written to the log file. **Required for agent-supervised runs** — a terminal tool cannot drive the interactive TUI, so supervision reads `codeplain.log` instead.
- **`--render-machine-graph`** — render the state-machine graph. Use only on explicit request.
- **`-h`, `--help`** — show the help message and exit.

## Environment variables

- **`CODEPLAIN_API_KEY`** — the API key used when `--api-key` is not passed on the command line. Export it before rendering (or pass `--api-key`). It is a secret and must never be written into `config.yaml`.

## `config.yaml` relationship

`codeplain` reads persistent options from a `config.yaml` (or the file named by `--config-name`), looked up in the `.plain` file's directory and the current working directory. This avoids retyping stable options on every run.

- **One `config.yaml` per part of the system that has its own test scripts.** A single-stack project has one at the root; a multi-part project (e.g. a Python backend and a React frontend) has one per part, each referencing only its own scripts.
- **Established keys:** `unittests-script`, `conformance-tests-script`, `prepare-environment-script`, `template_dir`, `base-folder`, `build-folder`, plus copy/log settings. `init-config-file` is the canonical assembler and the source of truth for the full valid key set; treat it as authoritative.
- **Constraint:** if `prepare-environment-script` is declared, `conformance-tests-script` must be declared too — a prepare script only exists in service of conformance.
- **Never put in `config.yaml`:** secrets (`api-key`) and per-invocation flags (`dry-run`, `full-plain`, `render-range`, `render-from`, `replay-with`). Supply these on the command line only.
- Remember the path-resolution rule above: a script path written in `config.yaml` resolves against the config file's directory, not the working directory.

## Render output

Generated artifacts (gitignored, read-only — never edit):

- `plain_modules/<module>/` — the generated project for each `.plain` spec (implementation + unit tests).
- `conformance_tests/<module>/<functionality>/` — generated conformance tests, one subfolder per functionality.
- `codeplain.log` — the per-run log (overwritten each run).

When a run ends, `codeplain` writes a result banner (to the log, and to the terminal outside headless mode):

- **Success:** `✓ rendering succeeded` (or `rendering complete`), followed by a metadata block: render id, input file, generated code folder, functionalities count, used credits, render time.
- **Failure:** `✗ rendering failed`, followed by the same metadata block.

## Test-script exit-code contract

The three wired scripts (`unittests-script`, `conformance-tests-script`, `prepare-environment-script`) share an exit-code contract that `codeplain`, `plain-healthcheck`, and `check-plain-env` all branch on:

- **`69`** — unrecoverable error (missing toolchain, bad arguments, cannot enter the working folder, install failed).
- **`1`** — the "no tests discovered" guard in the conformance runner (and bad usage in the unit-test runner).
- **any other non-zero** — propagated verbatim from the underlying test command (a real test failure).

Author or modify these scripts only through the matching `implement-{unit-testing,conformance-testing,prepare-environment}-script` skill — never by hand.

## Common invocation patterns

```bash
# Static-validation gate before a real render (what plain-healthcheck runs)
codeplain <module>.plain --dry-run

# Full render of the top module
codeplain <module>.plain

# Multi-part project: render one part with its own config file
codeplain backend/api.plain --config-name config.yaml

# Agent-supervised render: background + headless, watch codeplain.log
nohup codeplain <module>.plain --headless > /dev/null 2>&1 &

# Resume after a spec fix: re-render from functionality N (inclusive)
codeplain <module>.plain --render-from <N>

# Re-render exactly one functionality
codeplain <module>.plain --render-range <N>

# Force a full re-render (backward dependency changed) — costs more credits
codeplain <module>.plain --force-render
```

## Common errors and signals

- **`codeplain: command not found`** — the CLI is not installed or not on `PATH`. Confirm with `command -v codeplain`.
- **`401` / `403` / `unauthorized`** — `CODEPLAIN_API_KEY` is unset or invalid; export it or pass `--api-key`. This is an API/auth problem, not a spec problem.
- **`429` / `rate limit` / `quota`** — API throttling or credit limit; not a spec problem.
- **`Functional spec too complex!`** — a single functional spec implies more than 200 lines of code; break it down (`break-down-func-spec`).
- **`missing concept` / `unknown definition` / `cyclic` / `not defined` / `cannot resolve`** — a spec-graph error (a concept used before it is defined, a cycle, or a broken `import`/`requires` chain). A `--dry-run` catches these before spending credits.
- **`Traceback (most recent call last):`** — the renderer itself crashed (a bug), not a spec error; capture the stack for a bug report.

## See also

- `load-plain-reference` — the `***plain` language syntax and authoring rules.
- `run-codeplain` — supervising a live render (monitor loop, pathologies, resume).
- `plain-healthcheck` — the pre-render dry-run gate across every top module.
- `init-config-file` — canonical `config.yaml` assembly and the full valid key set.
- `implement-{unit-testing,conformance-testing,prepare-environment}-script` — authoring the wired test scripts.
