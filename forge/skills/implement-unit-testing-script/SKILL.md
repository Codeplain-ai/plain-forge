---
name: implement-unit-testing-script
description: >-
  Implement a unit-test runner script (Bash on macOS/Linux, PowerShell on
  Windows) for an arbitrary programming language, following the same conceptual
  pattern as the bundled Java reference script in assets/. Use when the user
  wants to add a testing script for a new language (Python, Node.js, Go, Rust,
  etc.) to a ***plain project, or wants to regenerate / adapt the existing
  Java runner.
---

# Implement Unit Testing Script

This skill produces a single executable script that runs the unit tests for a generated build folder, following a consistent, language-agnostic pattern.

The reference implementation is [assets/run_unittests_java.sh](assets/run_unittests_java.sh). Read it first — every script you produce must be a faithful translation of that pattern into the target language's tooling **and** the user's shell environment.

## Pick the Shell First

Before writing anything, decide which shell flavor the script must target — it depends on the user's environment, not on the language:

- **Bash (`.sh`)** — macOS, Linux, WSL, CI runners on Linux. Default unless the user is on native Windows.
- **PowerShell (`.ps1`)** — native Windows / PowerShell-only environments.

If you can't tell from the project (no obvious OS hints, no existing scripts), ask the user.

The same seven-step pattern applies to both. Only the syntax changes.

## The Pattern

Every testing script must implement these steps **in this order**:

1. **Toolchain check.** Verify that the required language runtime / build tool (and the required version, if any) is installed. If not, print an error and exit with code `69`.
2. **Argument validation.** Require exactly one positional argument: the source build folder name. If missing, print usage and exit with code `1`.
3. **Working directory setup.** Define a working folder at `.tmp/<lang>_<arg>`. If it exists, wipe its contents; otherwise create it.
4. **Copy the build.** Recursively copy everything from the source folder into the working folder.
5. **Enter the working directory.** `cd` / `Set-Location` into it. If that fails, exit with code `2`.
6. **Install dependencies into an isolated environment.** Set up a per-working-folder dependency location (a Python venv, a local `node_modules`, a project-scoped Maven repo, etc.) and install/resolve all dependencies into it. If the install command fails, propagate its exit code immediately and **do not** proceed to step 7. See [Dependency isolation](#dependency-isolation) for per-language specifics.
7. **Run the tests.** Invoke the language's standard test command (e.g. `mvn test`, `pytest`, `npm test`, `go test ./...`, `cargo test`), pointed at the same isolated environment from step 6. The script's final exit code is whatever the test command returns.

## Conventions

Shared across both shell flavors:

- **Exit codes:**
  - `1` — bad usage (missing argument).
  - `2` — filesystem problem (couldn't enter the working folder).
  - `69` — required toolchain / runtime is not installed.
  - Any other non-zero code — propagated from the underlying test command.
- **Working folder naming:** `.tmp/<lang>_<arg>` where `<lang>` is a short identifier for the language (`java`, `python`, `node`, `go`, `rust`, ...).
- **Logging:** print short progress lines (`"Copied from ... to ..."`, `"Installing dependencies into ..."`, `"Running <lang> unittests in ..."`) so failures are easy to triage.

### Dependency isolation

The dependency environment must live **inside** `$WORKING_FOLDER` so the test run can't be polluted by — or pollute — the user's global caches. Pick the most idiomatic isolation mechanism for the language:

| Language | Isolation mechanism | Install command (run inside `$WORKING_FOLDER`) | Test command |
|---|---|---|---|
| Python | `venv` at `./.venv` | `python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt` (or `pyproject.toml` / `uv sync` / `poetry install`) | `./.venv/bin/pytest` (or `./.venv/bin/python -m pytest`) |
| Node.js | local `./node_modules` (default) | `npm ci` (preferred) or `npm install` | `npm test` |
| Java | project-scoped Maven repo at `./.m2` | `mvn -Dmaven.repo.local=./.m2 dependency:resolve` (optional pre-warm) | `mvn -Dmaven.repo.local=./.m2 test` |
| Go | module cache at `./.gocache` | `GOMODCACHE="$PWD/.gocache" go mod download` (optional pre-warm) | `GOMODCACHE="$PWD/.gocache" go test ./...` |
| Rust | cargo home at `./.cargo` | `CARGO_HOME="$PWD/.cargo" cargo fetch` (optional pre-warm) | `CARGO_HOME="$PWD/.cargo" cargo test` |

Notes:

- **Always pass the isolation flag/env var to both the install command and the test command** — they must agree on where deps live, otherwise the test command will silently fall back to the global cache.
- **Python is the only ecosystem where the venv is mandatory** to satisfy "into a virtual environment" literally. The others use language-native equivalents that achieve the same isolation.
- **Pre-warming is optional for Java/Go/Rust** — their test commands will fetch deps on demand. Doing it as a separate step makes failures easier to diagnose and gives a clean "install failed vs test failed" signal.
- **Don't activate the venv** in Bash via `source .venv/bin/activate` — call `./.venv/bin/<tool>` directly. It's more portable and avoids subshell weirdness. In PowerShell, use `& .\.venv\Scripts\<tool>.exe` similarly.
- **Propagate the install exit code immediately.** In Bash: `<install cmd> || exit $?`. In PowerShell: check `$LASTEXITCODE` and `exit $LASTEXITCODE` if non-zero.

### Bash specifics

- **Shebang:** `#!/bin/bash`.
- **File naming:** `run_unittests_<lang>.sh`, placed in `assets/`.
- **Argument:** `$1`.
- **Make it executable:** `chmod +x assets/run_unittests_<lang>.sh`.

### PowerShell specifics

- **No shebang.** Use a `param([Parameter(Mandatory=$true)][string]$Subfolder)` block at the top instead.
- **File naming:** `run_unittests_<lang>.ps1`, placed in `assets/`.
- **Exit codes:** use `exit 69` etc. (PowerShell honors them just like Bash).
- **Toolchain check:** prefer `Get-Command <tool> -ErrorAction SilentlyContinue` and, where a specific version is needed, parse the tool's `--version` output.
- **Filesystem:** use `Test-Path`, `Remove-Item -Recurse -Force`, `New-Item -ItemType Directory`, `Copy-Item -Recurse`, `Set-Location`. Quote paths to handle spaces.
- **No `chmod` step needed.** If execution policy is likely to block the script, mention `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` to the user — don't bake it into the script.

## Workflow

1. Confirm the target **language**, **shell flavor** (Bash or PowerShell), and **dependency manifest** (`pom.xml`, `requirements.txt` / `pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, ...). Ask if any is unclear.
2. Read [assets/run_unittests_java.sh](assets/run_unittests_java.sh) to refresh the exact structure.
3. Translate each of the seven steps above into the equivalent commands for the target language **and** shell. The toolchain check, dependency install, and test invocation are the language-specific parts; the rest is mechanical translation between Bash and PowerShell syntax.
4. Pick the dependency-isolation mechanism from the [Dependency isolation](#dependency-isolation) table and use it consistently in both step 6 and step 7.
5. Save the new script to `assets/run_unittests_<lang>.sh` or `assets/run_unittests_<lang>.ps1`. For Bash, `chmod +x` it.

## Anti-Patterns

- Don't skip the toolchain check, even when "everyone has it installed" — exit code `69` is what the calling system relies on to detect a missing runtime.
- Don't reuse the source folder in place. Always copy into `.tmp/<lang>_<arg>` first; the renderer relies on this isolation.
- Don't change the exit-code contract. Other parts of the system branch on `1`, `2`, and `69` specifically — and these codes must be identical between the Bash and PowerShell variants.
- Don't write a cross-shell hybrid (e.g. a `.sh` that detects PowerShell, or vice versa). Ship one script per shell, named with the appropriate extension.
- Don't install dependencies into the user's global location (`~/.m2`, system-wide `pip`, `~/.cargo`, etc.). Always isolate inside `$WORKING_FOLDER` so concurrent runs and other projects can't interfere.
- Don't run the test command without first verifying the install step succeeded. A failed install followed by a "test" run produces misleading errors that look like test failures.
