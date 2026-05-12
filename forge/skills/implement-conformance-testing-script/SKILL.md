---
name: implement-conformance-testing-script
description: >-
  Implement a conformance-test runner script (Bash on macOS/Linux, PowerShell on
  Windows) for an arbitrary programming language, in one of two variants:
  install-inline (when no prepare_environment_<lang> script exists) or
  activate-only (when one does). Use when the user wants to add a
  conformance-test runner for a new language (Node.js, Go, Rust, Flutter, etc.)
  to a ***plain project, or wants to regenerate / adapt one of the existing
  runners.
---

# Implement Conformance Testing Script

This skill produces a single executable script that runs the **conformance tests** for a generated build folder, following a consistent, language-agnostic pattern.

The reference implementations are:

- [assets/run_conformance_tests_java.sh](assets/run_conformance_tests_java.sh) — Java, install-inline variant.
- [assets/run_conformance_tests_python.sh](assets/run_conformance_tests_python.sh) — Python, install-inline variant.

Read both before writing anything — every script you produce must be a faithful translation of the same pattern into the target language's tooling **and** the user's shell environment.

## How conformance scripts differ from unit-test scripts

A conformance script is structurally very close to a unit-test script (see the sibling skill [`implement-unit-testing-script`](../implement-unit-testing-script/SKILL.md)) but with two important differences:

1. **Two positional arguments instead of one.** A conformance script takes both the **build folder** (source under test) and a **separate conformance tests folder** (the tests to execute against that build).
2. **Tests are loaded from outside the working folder.** The build is staged into `.tmp/<lang>_<arg>` and the script `cd`s into it, but the test command is pointed at the *original* `$current_dir/<conformance_tests_folder>`. Tests are never copied into the staging area.

Everything else — toolchain check, build staging, dependency isolation, exit codes — is the same.

## Variant decision: install-inline vs. activate-only

**Before writing anything, decide which variant to emit.** Both variants share toolchain check, arg validation, cwd capture, test execution, and exit-code handling — they differ only in the middle (steps 4–7 of [the pattern](#the-pattern) below).

| Look for an existing | Emit |
|---|---|
| `prepare_environment_<lang>.sh` / `.ps1` in the project's `test_scripts/` folder (or wherever `config.yaml`'s `prepare-environment-script:` key points) | **Activate-only variant.** Verifies the prepared env, activates it, and runs tests. **Does not** stage the build or install deps — prepare already did. |
| Nothing — no prepare script | **Install-inline variant.** Stages the build, installs deps, and runs tests in one shot. |

**Why this matters:** if you emit the install-inline variant alongside an existing prepare script, prepare's work is wiped (by the script's `rm -rf .tmp/<lang>_$1`) or duplicated (by re-running install) on every run — defeating prepare's whole purpose. Conversely, emitting activate-only without a prepare script means the "verify prepared environment" check fails on every run because nothing has populated the working folder. See [Anti-Patterns](#anti-patterns).

## Pick the Shell First

Before writing anything, decide which shell flavor the script must target — it depends on the user's environment, not on the language:

- **Bash (`.sh`)** — macOS, Linux, WSL, CI runners on Linux. Default unless the user is on native Windows.
- **PowerShell (`.ps1`)** — native Windows / PowerShell-only environments.

If you can't tell from the project (no obvious OS hints, no existing scripts), ask the user.

The same pattern applies to both. Only the syntax changes.

## The Pattern

Steps **1–3** and **step 8** are identical in both variants. Steps **4–7** differ — pick the subsection below that matches the variant you decided on.

### Common steps (both variants)

1. **Toolchain check.** Verify that the required language runtime / build tool (and the required version, if any) is installed. If not, print an error and exit with code `69`.
2. **Argument validation.** Require **two** positional arguments: `<build_folder>` and `<conformance_tests_folder>`. If either is missing, print usage and exit with code `69`.
3. **Capture original cwd.** Store `pwd` in a variable (`current_dir` / `$PWD`) **before** changing directories — the test command in step 8 needs it to resolve the conformance tests folder.

### Steps 4–7 — install-inline variant (no prepare script)

4. **Working directory setup.** Define a working folder at `.tmp/<lang>_<arg1>`. Wipe it (`rm -rf` / `Remove-Item -Recurse -Force`) and recreate it.
5. **Copy the build.** Recursively copy everything from `<build_folder>` (`$1`) into the working folder. **Do not** copy the conformance tests — they stay where they are.
6. **Enter the working directory.** `cd` / `Set-Location` into it. If that fails, exit with code `69`.
7. **Install dependencies into an isolated environment.** Set up a per-working-folder dependency location (a Python venv, a local `node_modules`, a project-scoped Maven repo, etc.) and install/resolve all dependencies into it. If the install command fails, propagate its exit code immediately and **do not** proceed to step 8. See [Dependency isolation (install-inline)](#dependency-isolation-install-inline).

### Steps 4–7 — activate-only variant (prepare script exists)

4. **Verify the prepared environment.** Both:
   - Check that the working folder `.tmp/<lang>_<arg1>` exists.
   - Check that the language's isolation location inside it exists (e.g. `.venv/bin/activate` for Python, `.m2/` for Java, `node_modules/` for Node, `.gocache/` for Go, `.cargo/` for Rust).

   If either check fails, print a helpful error (`"Error: prepared environment missing — did you run prepare_environment_<lang>.<sh|ps1> first?"`) and exit `69`. **Do not silently fall back to creating it inline** — that would mask a real misconfiguration and turn this script into the install-inline variant in disguise.
5. **Enter the working directory.** `cd` / `Set-Location` into `.tmp/<lang>_<arg1>`. If that fails, exit `69`.
6. **Activate the prepared dependency environment.** Per-language:
   - Python: `source .venv/bin/activate` (must succeed; exit `69` on failure).
   - Java: set `MAVEN_LOCAL_REPO="$(pwd)/.m2"` so it can be passed as `-Dmaven.repo.local="$MAVEN_LOCAL_REPO"` to `mvn` in step 8.
   - Node.js / Go / Rust: nothing to activate explicitly — the test command in step 8 just needs to receive the same isolation flag/env var that prepare used (`./node_modules` is found by default; pass `GOMODCACHE` / `CARGO_HOME`).
7. *(There is no step 7 in this variant — install was prepare's job. Skip straight to step 8.)*

### Common step 8 (both variants)

8. **Run the conformance tests.** Invoke the language's standard test command, **pointed at `$current_dir/<conformance_tests_folder>`** (the original cwd from step 3 + the second arg). The script's final exit code is whatever the test command returns — except for the "no tests discovered" case below.

### "No tests discovered" detection

The Python reference script grep's the test runner output for `"Ran 0 tests in"` and exits `1` if no tests ran. Replicate the equivalent check for the target language wherever that language's test runner silently passes when given an empty test set:

- Python `unittest`: `"Ran 0 tests in"`
- Node.js `jest`: `"No tests found"`
- Go `go test`: `"no test files"` / `"no tests to run"`
- Rust `cargo test`: `"running 0 tests"`
- Java `mvn test`: usually fails loudly already; no extra check needed.

A silently-passing zero-test run is the most dangerous failure mode of a conformance runner — always guard against it. **This applies to both variants.**

## Conventions

Shared across both shell flavors **and** both variants:

- **Exit codes:**
  - `69` — unrecoverable invocation error: missing argument, missing toolchain, can't enter working folder, can't create venv (install-inline), or prepared environment missing/broken (activate-only). Matches the reference scripts' `UNRECOVERABLE_ERROR_EXIT_CODE`.
  - `1` — "no tests discovered" guard tripped (see above).
  - Any other non-zero code — propagated from the underlying test command.
- **Working folder naming:** `.tmp/<lang>_<arg1>` where `<lang>` is a short identifier for the language (`java`, `python`, `node`, `go`, `rust`, ...). Use the *first* argument (the build folder) in the path, never the conformance tests folder.
- **Logging:** print short progress lines (`"Preparing <lang> build subfolder: ..."`, `"Activating prepared virtual environment..."`, `"Running <lang> conformance tests..."`) so failures are easy to triage. Wrap noisy "preparing" lines in a `VERBOSE` check if matching the Python reference.
- **Capture `current_dir` before `cd`.** This is the single most common bug in hand-written conformance scripts: forgetting that the conformance tests folder argument is relative to the *invocation* directory, not the working folder.

### Dependency isolation (install-inline)

This section applies to **install-inline scripts only.** For activate-only scripts, the isolation location is set up by prepare; you just need to point the test command at it — see [Activating a prepared environment](#activating-a-prepared-environment-activate-only).

The dependency environment must live **inside** `$WORKING_FOLDER` so the test run can't be polluted by — or pollute — the user's global caches. Pick the most idiomatic isolation mechanism for the language:

| Language | Isolation mechanism | Install command (run inside `$WORKING_FOLDER`) | Test command (point at `$current_dir/$2`) |
|---|---|---|---|
| Python | `venv` at `./.venv` | `python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt` | `python -m unittest discover -b -s "$current_dir/$2"` (or `pytest "$current_dir/$2"`) |
| Node.js | local `./node_modules` (default) | `npm ci` (preferred) or `npm install` | `npx jest --rootDir "$current_dir/$2"` |
| Java | project-scoped Maven repo at `./.m2` | `mvn -Dmaven.repo.local=./.m2 install -DskipTests` (build + install artifact so the test pom can resolve it) | `mvn -f "$current_dir/$2/pom.xml" -Dmaven.repo.local="$(pwd)/.m2" test` |
| Go | module cache at `./.gocache` | `GOMODCACHE="$PWD/.gocache" go mod download` (optional pre-warm) | `GOMODCACHE="$PWD/.gocache" go test "$current_dir/$2/..."` |
| Rust | cargo home at `./.cargo` | `CARGO_HOME="$PWD/.cargo" cargo fetch` (optional pre-warm) | `CARGO_HOME="$PWD/.cargo" cargo test --manifest-path "$current_dir/$2/Cargo.toml"` |

Notes:

- **Always pass the isolation flag/env var to both the install command and the test command.** They must agree on where deps live, otherwise the test command will silently fall back to the global cache.
- **Python is the only ecosystem where the venv is mandatory** to satisfy "into a virtual environment" literally. The others use language-native equivalents that achieve the same isolation.
- **Propagate the install exit code immediately.** In Bash: `<install cmd> || exit $?`. In PowerShell: check `$LASTEXITCODE` and `exit $LASTEXITCODE` if non-zero.
- **Time the dependency setup** with `date +%s.%N` (Bash) / `Get-Date` (PowerShell) and print `"Requirements setup completed in X.XX seconds"`. If this number is large, that's the signal to add a `prepare_environment_<lang>` script (and switch this script to the activate-only variant).

### Activating a prepared environment (activate-only)

This section applies to **activate-only scripts only.** The isolation location was created by prepare; conformance just needs to attach to it and pass the right flags to the test command.

| Language | Verify exists in step 4 | Activate in step 6 | Test command in step 8 (point at `$current_dir/$2`) |
|---|---|---|---|
| Python | `.tmp/<lang>_$1/.venv/bin/activate` | `source .venv/bin/activate` (after `cd`-ing into the working folder) | `python -m unittest discover -b -s "$current_dir/$2"` |
| Node.js | `.tmp/<lang>_$1/node_modules/` | (nothing) | `npx jest --rootDir "$current_dir/$2"` |
| Java | `.tmp/<lang>_$1/.m2/` | `MAVEN_LOCAL_REPO="$(pwd)/.m2"` | `mvn -f "$current_dir/$2/pom.xml" -Dmaven.repo.local="$MAVEN_LOCAL_REPO" test` |
| Go | `.tmp/<lang>_$1/.gocache/` | `export GOMODCACHE="$(pwd)/.gocache"` | `go test "$current_dir/$2/..."` |
| Rust | `.tmp/<lang>_$1/.cargo/` | `export CARGO_HOME="$(pwd)/.cargo"` | `cargo test --manifest-path "$current_dir/$2/Cargo.toml"` |

Notes:

- **Verify, don't recreate.** If `.venv` is missing, exit `69` with a clear "did you run prepare_environment first?" message — do **not** silently fall back to creating it inline. That would silently degrade a misconfigured project into the install-inline path and mask the real problem.
- **Match prepare's isolation paths exactly.** If prepare puts the venv at `.venv` and you look for it at `venv`, the verify step will always fail. Read [`implement-prepare-environment-script`](../implement-prepare-environment-script/SKILL.md) for the canonical paths.
- **Don't time anything in this variant.** The slow phase is prepare; conformance just runs the tests. Adding a duration log here is misleading — it makes the script look like it's doing the install when it isn't.

### Bash specifics

- **Shebang:** `#!/bin/bash`.
- **File naming:** `run_conformance_tests_<lang>.sh`, placed in `assets/` (skill reference) or `test_scripts/` (target project).
- **Arguments:** `$1` = build folder, `$2` = conformance tests folder.
- **Make it executable:** `chmod +x` the produced script.
- **`cd` failure check:** the reference scripts use the `cd ... 2>/dev/null` + `[ $? -ne 0 ]` pattern. Keep it.

### PowerShell specifics

- **No shebang.** Use a `param([Parameter(Mandatory=$true)][string]$BuildFolder, [Parameter(Mandatory=$true)][string]$ConformanceTestsFolder)` block at the top instead.
- **File naming:** `run_conformance_tests_<lang>.ps1`.
- **Exit codes:** use `exit 69` etc. (PowerShell honors them just like Bash).
- **Toolchain check:** prefer `Get-Command <tool> -ErrorAction SilentlyContinue` and, where a specific version is needed, parse the tool's `--version` output.
- **Filesystem:** use `Test-Path`, `Remove-Item -Recurse -Force`, `New-Item -ItemType Directory`, `Copy-Item -Recurse`, `Set-Location`. Quote paths to handle spaces.
- **Capture original cwd:** `$currentDir = (Get-Location).Path` **before** any `Set-Location` call.
- **No `chmod` step needed.** If execution policy is likely to block the script, mention `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` to the user — don't bake it into the script.

## Workflow

1. **Decide the variant.** Look in the project for `prepare_environment_<lang>.sh` / `.ps1` (check `test_scripts/`, then any `prepare-environment-script:` key in `config.yaml`). If present → emit **activate-only**. If absent → emit **install-inline**. See [Variant decision](#variant-decision-install-inline-vs-activate-only).
2. Confirm the target **language**, **shell flavor** (Bash or PowerShell), and **dependency manifest** (`pom.xml`, `requirements.txt` / `pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, ...). Ask if any is unclear.
3. Read [assets/run_conformance_tests_java.sh](assets/run_conformance_tests_java.sh) and [assets/run_conformance_tests_python.sh](assets/run_conformance_tests_python.sh) to refresh the exact structure. Both are install-inline references — for activate-only, follow steps 4–7 of [the activate-only variant](#steps-47--activate-only-variant-prepare-script-exists) and the [Activating a prepared environment](#activating-a-prepared-environment-activate-only) table.
4. Translate each step into the equivalent commands for the target language **and** shell. The toolchain check, dependency install/activate, and test invocation are the language-specific parts; the rest is mechanical translation between Bash and PowerShell syntax.
5. Pick the right per-language row:
   - **Install-inline:** [Dependency isolation (install-inline)](#dependency-isolation-install-inline) table — use the same flag/env var in steps 7 and 8.
   - **Activate-only:** [Activating a prepared environment](#activating-a-prepared-environment-activate-only) table — use the matching verify, activate, and test-command columns in steps 4, 6, and 8.
6. Add the language-appropriate "no tests discovered" guard from [No tests discovered detection](#no-tests-discovered-detection).
7. Save the new script. For Bash, `chmod +x` it.
8. **For activate-only scripts only**: smoke-test by running `prepare_environment_<lang>.<sh|ps1> <build> && run_conformance_tests_<lang>.<sh|ps1> <build> <tests>`. If the conformance script errors with "prepared environment missing" right after a successful prepare, the two scripts disagree on either the working-folder path or the isolation location — fix that before declaring done.

## Anti-Patterns

- **Don't emit the install-inline variant when a `prepare_environment_<lang>` script already exists.** The conformance script's `rm -rf .tmp/<lang>_$1` will wipe everything prepare did, and the inline install will redo it from scratch on every run. Always run the [Variant decision](#variant-decision-install-inline-vs-activate-only) check first.
- **Don't emit the activate-only variant when no prepare script exists.** The "verify prepared environment" check will fail on every run because nothing has populated the working folder.
- **Don't silently fall back from activate-only to install-inline** when the prepared environment is missing. Exit `69` with a clear error so the misconfiguration is visible. Silent fallback hides the real bug and produces inconsistent behavior between runs.
- **Don't copy the conformance tests folder into `.tmp/`.** Only the build folder is staged (and only in install-inline). The test folder is read in place from `$current_dir/$2`.
- **Don't compute the test path after `cd`.** Capture `current_dir` first; otherwise `$2` will be resolved relative to the working folder and silently miss the tests.
- **Don't skip the "no tests discovered" check.** A conformance suite that finds zero tests and exits `0` is the worst possible failure mode — it looks like success in CI.
- **Don't skip the toolchain check**, even when "everyone has it installed" — exit code `69` is what the calling system relies on to detect a missing runtime.
- **Don't reuse the source folder in place** (install-inline). Always copy into `.tmp/<lang>_<arg1>` first; the renderer relies on this isolation.
- **Don't change the exit-code contract.** Other parts of the system branch on `69` and `1` specifically — and these codes must be identical between the Bash and PowerShell variants.
- **Don't write a cross-shell hybrid** (e.g. a `.sh` that detects PowerShell, or vice versa). Ship one script per shell, named with the appropriate extension.
- **Don't install dependencies into the user's global location** (`~/.m2`, system-wide `pip`, `~/.cargo`, etc.) in the install-inline variant. Always isolate inside `$WORKING_FOLDER` so concurrent runs and other projects can't interfere.
- **Don't run the test command without first verifying the install / activation succeeded.** A failed install (or missing prepared env) followed by a "test" run produces misleading errors that look like test failures.
