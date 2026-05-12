---
name: implement-prepare-environment-script
description: >-
  Implement a prepare-environment script (Bash on macOS/Linux, PowerShell on
  Windows) for an arbitrary programming language, following the same conceptual
  pattern as the bundled Java reference script in assets/. Use when the user
  wants to add a one-time per-build setup step (install deps, pre-build
  artifacts, populate caches) for a new language (Python, Node.js, Go, Rust,
  Flutter, etc.) to a ***plain project, or wants to regenerate / adapt the
  existing Java runner.
---

# Implement Prepare Environment Script

This skill produces a single executable script that performs the **one-time per-build setup** that precedes a conformance-test run, following a consistent, language-agnostic pattern.

The reference implementation is [assets/prepare_environment_java.sh](assets/prepare_environment_java.sh) and [assets/prepare_environment_python.sh](assets/prepare_environment_python.sh). Read it first — every script you produce must be a faithful translation of that pattern into the target language's tooling **and** the user's shell environment.

## What a prepare-environment script is for

`prepare_environment_<lang>` is an **optional** sibling of [`run_conformance_tests_<lang>`](../implement-conformance-testing-script/SKILL.md). It runs **immediately before** the conformance script and exists to:

1. **Stage the build** into a working folder (the same one the conformance script will use).
2. **Pre-warm the dependency cache / build artifacts** so the conformance script can start cold without re-downloading or re-compiling anything.

When this script exists for a project, the corresponding conformance script's own dependency-install phase degrades to "activate only" (see [`implement-conformance-testing-script/SKILL.md`](../implement-conformance-testing-script/SKILL.md) → "Skipping setup when `prepare_environment` exists"). When it doesn't exist, the conformance script does the setup inline.

## How prepare-environment scripts differ from the others
 
This script shares most of its structure with its two siblings ([`run_unittests_<lang>`](../implement-unit-testing-script/SKILL.md) and [`run_conformance_tests_<lang>`](../implement-conformance-testing-script/SKILL.md)) but with these differences:

1. **One positional argument: `<build_folder>`.** No conformance tests folder — that's the conformance script's input, not this one's.
2. **No test execution step.** This script only stages and installs/builds. It never runs unit tests or conformance tests.
3. **No "no tests discovered" guard.** Same reason — no tests are run here.
4. **Side effects must be visible to the conformance script.** Anything this script does (working-folder name, dependency isolation location, installed artifacts) must match exactly what the conformance script expects to find. See [Coordination contract](#coordination-contract).

Everything else — toolchain check, build staging, dependency isolation, exit codes — is the same.

## Pick the Shell First

Before writing anything, decide which shell flavor the script must target — it depends on the **host machine running this skill**, not on the language. **Detect the host OS proactively; do not default to Bash.**

| Host OS | Emit | How to detect |
|---|---|---|
| macOS | `.sh` | `uname -s` returns `Darwin` |
| Linux (incl. WSL, CI runners) | `.sh` | `uname -s` returns `Linux` |
| Native Windows (PowerShell, cmd) | `.ps1` | `$OS` env var contains `Windows_NT`, or `uname -s` returns `MINGW*` / `MSYS*` / `CYGWIN*` (Git Bash / MSYS2 / Cygwin shells on Windows) |

Run `uname -s 2>/dev/null || echo "$OS"` if unsure — don't ask the user before checking.

If the project will be used on **both** macOS/Linux and Windows by different team members or CI runners, generate **both** `.sh` and `.ps1` versions of this script — they're mechanical translations of each other, share exit codes and isolation paths, and the orchestrator (or the user's CI) picks the right one at runtime. The corresponding `run_conformance_tests_<lang>` script must be produced in matching pairs too.

If you genuinely can't tell (e.g. running in a sandbox with no shell access), ask the user — but only after the detection above failed.

The same pattern applies to both shell flavors. Only the syntax changes.

## The Pattern

Every prepare-environment script must implement these steps **in this order**:

1. **Toolchain check.** Verify that the required language runtime / build tool (and the required version, if any) is installed. If not, print an error and exit with code `69`.
2. **Argument validation.** Require **one** positional argument: `<build_folder>`. If missing, print usage and exit with code `69`.
3. **Working directory setup.** Define a working folder at `.tmp/<lang>_<arg>` — **identical** to the path the conformance script will use. Wipe it (`rm -rf` / `Remove-Item -Recurse -Force`) and recreate it.
4. **Copy the build.** Recursively copy everything from `<build_folder>` (`$1`) into the working folder.
5. **Enter the working directory.** `cd` / `Set-Location` into it. If that fails, exit with code `69`.
6. **Install dependencies / pre-build artifacts into an isolated environment.** Set up a per-working-folder dependency location (a Python venv, a local `node_modules`, a project-scoped Maven repo, etc.) and install/resolve all dependencies into it. Where the language requires building before tests can run (Java, Rust, Go), also produce the build artifact and place it where the conformance script can find it. If any sub-step fails, exit with code `69` (do **not** propagate Maven/pip/npm exit codes — a half-prepared environment is itself an unrecoverable error). See [Dependency isolation](#dependency-isolation) for per-language specifics.

That's it. There is no step 7. Once dependencies are installed and (where applicable) the build artifact is in the local repo, this script's job is done.

## Coordination contract

This is the most important part of the skill. A prepare-environment script that doesn't agree with its conformance sibling on **where** it puts things is worse than no prepare script at all — it costs time and creates the *appearance* of a warm environment without actually warming the right one.

The two scripts must agree on:

| What | Why it matters |
|---|---|
| **Working folder path** (`.tmp/<lang>_$1`) | The conformance script `cd`s into this folder. If prepare uses a different name, the conformance script sees an empty / freshly-staged folder and re-does all the work. |
| **Dependency isolation location** (`./.venv`, `./.m2`, `./node_modules`, `./.gocache`, `./.cargo`, …) — relative to the working folder | If prepare populates `~/.m2` and conformance reads from `./.m2`, the warm cache is invisible. Always use the **project-local** path inside the working folder, in both scripts. |
| **Build artifact location** (Java/Rust/Go) | The conformance test project depends on the build's artifact. It must be findable at the exact coordinates the conformance script expects (e.g. installed into the same project-local `./.m2` for Java). |
| **Toolchain version** | If prepare runs under Java 21 and conformance runs under Java 17, classfile incompatibilities will surface at test time, not prepare time. Both scripts should perform the same toolchain check. |

When in doubt, **read the conformance script first** and mirror its assumptions exactly.

## Conventions

Shared across both shell flavors:

- **Exit codes:**
  - `69` — unrecoverable: missing argument, missing toolchain, can't enter working folder, dependency install / build failed. Treat **all** failures as unrecoverable here — there is no "soft" failure mode for prepare.
  - `0` — success.
- **Working folder naming:** `.tmp/<lang>_<arg>` where `<lang>` is a short identifier for the language (`java`, `python`, `node`, `go`, `rust`, ...). Use the *first* (and only) argument in the path.
- **Logging:** print short progress lines (`"Preparing <lang> build subfolder: ..."`, `"Copied from ... to ..."`, `"Installing <lang> dependencies into ..."`, `"Pre-build completed in X.XX seconds"`) so failures are easy to triage. Wrap noisy "preparing" lines in a `VERBOSE` check if matching the Java reference.
- **Time the dependency setup** with `date +%s.%N` (Bash) / `Get-Date` (PowerShell) and print a duration line at the end. This is the slowest phase and the whole reason this script exists; the duration tells you whether it's actually saving time.

### Dependency isolation

The dependency environment must live **inside** `$WORKING_FOLDER` so the conformance script can find it and so concurrent runs of other languages / projects can't interfere. Pick the most idiomatic isolation mechanism for the language — and make sure it matches what the conformance script reads from:

| Language | Isolation mechanism | Prepare command (run inside `$WORKING_FOLDER`) |
|---|---|---|
| Python | `venv` at `./.venv` | `python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt` |
| Node.js | local `./node_modules` (default) | `npm ci` (preferred) or `npm install` |
| Java | project-scoped Maven repo at `./.m2` | `mvn -Dmaven.repo.local="$(pwd)/.m2" install -DskipTests` (builds and installs the project's own jar into the repo so dependent test projects can resolve it) |
| Go | module cache at `./.gocache` | `GOMODCACHE="$PWD/.gocache" go mod download && GOMODCACHE="$PWD/.gocache" go build ./...` |
| Rust | cargo home at `./.cargo` | `CARGO_HOME="$PWD/.cargo" cargo build --tests` (compiles deps + tests in one shot) |
| Flutter | pub cache at `./.pub-cache` | `PUB_CACHE="$PWD/.pub-cache" flutter pub get && flutter precache` |

Notes:

- **Java/Rust/Go must compile, not just download.** The conformance script will time-out / re-compile from scratch if you only resolve metadata. Use `mvn install`, `cargo build --tests`, `go build ./...` (not just `dependency:resolve` / `cargo fetch` / `go mod download`).
- **Python and Node.js only need to install** — they're interpreted/JIT-compiled at test time, so `pip install` / `npm ci` is sufficient.
- **Always pass the isolation flag/env var.** `mvn` without `-Dmaven.repo.local`, `cargo` without `CARGO_HOME`, etc., write to the user's home directory instead of `$WORKING_FOLDER`. The conformance script will look in the wrong place and the warming was wasted.
- **Treat install failures as `exit 69`.** Unlike the conformance script (which propagates the test command's exit code), prepare has no notion of "the user's tests legitimately failed" — every failure here means the environment isn't usable, period.

### Bash specifics

- **Shebang:** `#!/bin/bash`.
- **File naming:** `prepare_environment_<lang>.sh`, placed in `assets/`.
- **Argument:** `$1`.
- **Make it executable:** `chmod +x assets/prepare_environment_<lang>.sh`.
- **`cd` failure check:** use the `cd ... 2>/dev/null` + `[ $? -ne 0 ]` pattern from the reference. Put the success log line *after* the failure check, not before — otherwise it lies on failure.

### PowerShell specifics

- **No shebang.** Use a `param([Parameter(Mandatory=$true)][string]$BuildFolder)` block at the top instead.
- **File naming:** `prepare_environment_<lang>.ps1`, placed in `assets/`.
- **Exit codes:** use `exit 69` etc. (PowerShell honors them just like Bash).
- **Toolchain check:** prefer `Get-Command <tool> -ErrorAction SilentlyContinue` and, where a specific version is needed, parse the tool's `--version` output.
- **Filesystem:** use `Test-Path`, `Remove-Item -Recurse -Force`, `New-Item -ItemType Directory`, `Copy-Item -Recurse`, `Set-Location`. Quote paths to handle spaces.
- **No `chmod` step needed.** If execution policy is likely to block the script, mention `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` to the user — don't bake it into the script.

## Workflow

1. **Detect the host OS** to pick the script flavor. Run `uname -s 2>/dev/null || echo "$OS"` and apply the rules in [Pick the Shell First](#pick-the-shell-first): `Darwin`/`Linux` → `.sh`, `Windows_NT`/`MINGW*`/`MSYS*`/`CYGWIN*` → `.ps1`. If the project targets both macOS/Linux **and** Windows (multi-OS team or CI), plan to produce **both** `.sh` and `.ps1` files — repeat steps 3–7 for each.
2. Confirm the target **language**, **dependency manifest** (`pom.xml`, `requirements.txt` / `pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, ...), and — critically — **read the corresponding `run_conformance_tests_<lang>` script first** if one already exists, so you know what isolation paths and toolchain versions to mirror. Ask if any is unclear.
3. Read [assets/prepare_environment_java.sh](assets/prepare_environment_java.sh) to refresh the exact structure. Note: that reference still has divergences from the contract above (see Anti-Patterns) — follow the contract, not the bugs.
4. Translate each of the six pattern steps into the equivalent commands for the target language **and** shell. The toolchain check and dependency install/build are the language-specific parts; the rest is mechanical translation between Bash and PowerShell syntax.
5. Pick the dependency-isolation mechanism from the [Dependency isolation](#dependency-isolation) table. **Verify it matches the path used by the corresponding `run_conformance_tests_<lang>` script.**
6. Save the new script to the appropriate `test_scripts/` location (e.g. `test_scripts/prepare_environment_<lang>.sh` / `.ps1`). For Bash, `chmod +x` it.
7. **Reconcile the conformance script (see next section).** This is mandatory whenever a matching `run_conformance_tests_<lang>` already exists in the project.
8. After both scripts are in place, do a paired re-read: open prepare and conformance side by side and confirm they agree on working folder name, isolation path, and toolchain version.

## Reconcile the existing conformance script

Adding a `prepare_environment_<lang>` script changes the contract for the corresponding `run_conformance_tests_<lang>` script — anything prepare now handles must be **removed** from conformance, otherwise prepare's work is wiped (by re-staging) or duplicated (by re-installing). Run this reconciliation **every time** this skill is used.

### Step-by-step

1. **Look for an existing conformance script** in the project. Check the conventional locations (`test_scripts/run_conformance_tests_<lang>.sh` / `.ps1`, or wherever the project's `config.yaml` points its `conformance-tests-script:` key).
2. **If it doesn't exist → stop. Nothing to reconcile.** The conformance script will be generated later by [`implement-conformance-testing-script`](../implement-conformance-testing-script/SKILL.md), which already knows about the activate-only variant.
3. **If it does exist → patch it.** Identify and remove the steps that prepare now owns:

| Step in conformance | If prepare exists, you must... |
|---|---|
| Staging block (`rm -rf .tmp/<lang>_$1` + `mkdir -p` + `cp -R $1/* .tmp/...`) | **Remove entirely.** Replace with a guard: `if [ ! -d ".tmp/<lang>_$1" ]; then echo "Error: build folder missing — run prepare_environment_<lang>.sh first."; exit 69; fi` |
| Dependency install / pre-build (`pip install`, `mvn install -DskipTests`, `npm ci`, `cargo build --tests`, etc.) | **Remove entirely.** Replace with a guard that the isolation location exists (`.venv/bin/activate` for Python, `.m2/` for Java, `node_modules/` for Node, etc.) and exit `69` if missing. |
| Activation step (Python `source .venv/bin/activate`, Java `-Dmaven.repo.local=$(pwd)/.m2`) | **Keep.** Without it the test command can't see the prepared deps. |
| Test execution + "no tests discovered" guard + exit-code propagation | **Keep unchanged.** |

4. **Verify the conformance script's exit codes still follow [`implement-conformance-testing-script`](../implement-conformance-testing-script/SKILL.md)** — the new "missing prepared environment" guard should exit `69` (unrecoverable invocation error), the no-tests guard should still exit `1`, and the test command's exit code should still propagate.
5. **Run a smoke check**: `prepare_environment_<lang>.sh <build_folder> && run_conformance_tests_<lang>.sh <build_folder> <conformance_tests_folder>` should succeed end-to-end. If conformance fails with "missing prepared environment" right after a successful prepare, the two scripts disagree on either the working-folder path or the isolation location — go back to [Coordination contract](#coordination-contract).

### When to skip this reconciliation

- **The conformance script doesn't exist yet.** Nothing to reconcile.
- **The conformance script already shows no signs of inline staging or install.** It was previously generated as the activate-only variant — leave it alone.
- **The user explicitly asks to keep prepare and conformance independent** (e.g. so conformance can run standalone without prepare). Document this clearly in a comment at the top of both scripts and skip the reconciliation. Note that this loses all the speedup prepare was meant to provide.

## Anti-Patterns

- **Don't write to the user's global dependency cache** (`~/.m2`, system-wide `pip`, `~/.cargo`, `~/.npm`, etc.). The conformance script reads from the project-local cache; a global write is invisible to it and pollutes the user's home dir.
- **Don't use a different working folder name than the conformance script.** They must match exactly. If you change one, change the other.
- **Don't run tests** — not unit tests, not conformance tests, not smoke tests. Prepare's contract is "set up the environment"; running tests belongs to its siblings.
- **Don't propagate non-`69` exit codes from `mvn` / `pip` / `npm`.** A failed install means the environment isn't usable. Treat every failure as `exit 69` so the orchestrator can tell "prepare failed" apart from "tests failed".
- **Don't skip the toolchain check**, even when "everyone has it installed" — exit code `69` is what the calling system relies on to detect a missing runtime, and prepare is usually the *first* script to run, so it's the cheapest place to surface a missing JDK / Python / Node.
- **Don't print the "moved to ..." line before the `cd` success check.** The reference script does this and it lies on failure. Put the log *after* the guard, or print "attempting to enter ..." instead.
- **Don't reuse the source folder in place.** Always copy into `.tmp/<lang>_<arg>` first; the conformance script relies on this isolation.
- **Don't change the exit-code contract between Bash and PowerShell variants.** The `.sh` and `.ps1` for the same language must use identical exit codes for identical failure modes.
- **Don't write a cross-shell hybrid** (e.g. a `.sh` that detects PowerShell, or vice versa). Ship one script per shell, named with the appropriate extension.
- **Don't forget to time the install.** Without the duration log, there's no way to tell whether prepare is actually saving wall-clock time vs. doing the same work the conformance script would have done inline.
- **Don't leave an existing `run_conformance_tests_<lang>` script untouched after generating prepare.** If the conformance script still does its own staging and install, prepare's work is wiped (by the `rm -rf`) or duplicated (by re-running install) on every run — defeating the purpose of this skill entirely. Always run the [Reconcile the existing conformance script](#reconcile-the-existing-conformance-script) step.
- **Don't default to Bash without checking the host OS.** A `.sh` script on native Windows (outside Git Bash / WSL) won't even run, and a `.ps1` script on macOS/Linux is equally useless. Always run the detection in [Pick the Shell First](#pick-the-shell-first) before deciding the file extension. If the project supports both, produce both files — and remember to reconcile the matching conformance script in **both** flavors too.
