---
name: run-codeplain
description: >-
  Launch a `codeplain` render and supervise it end-to-end. Tails the log file,
  watches generated code appear under `plain_modules/`, and inspects the live
  TUI/process. Detects pathologies (stuck conformance loops, complexity errors,
  missing concepts, render failures), and — with user approval — stops the
  renderer, hands off to a spec-edit skill, and resumes with `--render-from`.
  Use whenever the user wants to actually render specs (not just dry-run) and
  wants supervision of the run.
---

# Run Codeplain

Always use the skill `load-plain-reference` to retrieve the ***plain syntax rules — but only if you haven't done so yet.

## What this skill is

A **supervisor** around a live `codeplain` render. The renderer itself is the codeplain CLI; this skill does not generate code. It:

1. Launches `codeplain <module>.plain` (or attaches to an in-flight run).
2. Watches three signal sources in a tight loop, in priority order:
   - **`codeplain.log`** — the primary signal. Everything the renderer is doing, deciding, retrying, or failing at gets written here. This is the file you stare at.
   - the generated **code outputs** under `plain_modules/<module>/` and `conformance_tests/<module>/` — a secondary signal, used to corroborate or contradict what the log says.
   - the **process / TUI** itself (alive? exited? exit code?) — a tertiary signal, used only to know whether to keep monitoring.
3. Surfaces what is happening to the user in plain English, in near-real-time.
4. On pathology, stops the renderer (with user approval), hands off to the right edit skill, and resumes from the last completed functionality.

This skill is **read-mostly**. It does not modify `.plain` files itself — it delegates to `debug-specs`, `resolve-spec-conflict`, `break-down-func-spec`, `add-implementation-requirement`, etc. The only files it writes are control files: it may `kill` a process, and it shells out to `codeplain` again to resume.

**The log is the ground truth.** The TUI is opaque to the agent; the filesystem moves slowly and only on completed steps; but `codeplain.log` updates the moment the renderer takes any action — API call, retry, fix attempt, test run, abort. If the log and the filesystem disagree, trust the log. If the log and the TUI disagree (per the user's description), trust the log.

## When to use

- The user says "render it", "let's run codeplain", "kick off the render", "render `<module>.plain`", or similar.
- The user already has a render going in another terminal and wants you to babysit it.
- After `forge-plain` / `add-feature` / `debug-specs` / `plain-healthcheck` finished and the next move is the real render.

Do **not** use this skill for:

- A dry-run gate — that is `plain-healthcheck`.
- Authoring or editing specs — that is `forge-plain`, `add-feature`, `debug-specs`, or the specific `add-*` / `resolve-*` / `break-down-*` skills.

## Pre-flight (always do this first)

Before launching anything:

1. **Confirm the target.** Ask the user which top module they want rendered if it is not unambiguous from the conversation. The argument is the path to a `.plain` file (e.g. `agent_harness.plain`, `backend/api.plain`).
2. **Run `plain-healthcheck` if it hasn't been run since the last spec edit.** A real render that fails on something a dry-run would have caught burns credits. If healthcheck FAILs, stop here and surface the failures — do not start the render.
3. **Verify the environment.**
   - `codeplain` is on `PATH` (`command -v codeplain`).
   - `CODEPLAIN_API_KEY` is exported, **or** the user will pass `--api-key`.
   - The governing `config.yaml` for the chosen module exists (use the pairing rule from `plain-healthcheck`: same-directory config wins; root `config.yaml` is the fallback).
4. **Decide on flags with the user.** Default to a minimal command line; mention these knobs only if they apply:
   - `--config-name <name>` — multi-part project, or non-default config file name.
   - `--render-range <range>` / `--render-from <id>` — partial render, or resume from a previous run.
   - `--force-render` — invalidate cached module renders.
   - `--template-dir <path>` — templates outside `template/` and not pinned in config.
   - `--copy-build` / `--build-dest` — copy generated code somewhere outside `plain_modules/`.
   - `--copy-conformance-tests` / `--conformance-tests-dest` — same for conformance tests.
   - `--test-script-timeout <seconds>` — if test scripts are slow.
   - `--api-key <key>` / `--api <url>` — only if the env var route is not in use.
   - `--render-machine-graph` — only on explicit request.
   - `--headless` — see "Launch mode" below.

   Do **not** prompt for flags the user did not signal interest in; the empty command line is the right default.

5. **Locate and reset the log file.** By default it is `codeplain.log` in the same directory as the `.plain` file. If `--log-file-name` was overridden, the override resolves based on **where it was written**: a relative value on the CLI resolves against the invocation directory; a relative value in `config.yaml` resolves against the config file's directory; absolute and `~` paths are used as-is. **The file is overwritten** at the start of each run (per the `--log-file-name` help text). So:
   - Before launch, note the **absolute path** of the log file and its current size (`wc -c <path>`) — this lets you detect the moment the new run truncates and starts writing.
   - After launch, every log read must be against this same path. Re-derive it (using the resolution rule above) if the user passes `--log-file-name`, sets `log-file-name` in `config.yaml`, or runs from a different working directory.
   - The log is **per-run**: every byte you read during this run was written by this run. You don't have to worry about stale lines from prior runs.

6. **Read every test script referenced by the governing `config.yaml`.** This is non-negotiable. The scripts are the contract between the renderer and the project; you cannot judge what the renderer is "fixing" without knowing what `pass` and `fail` actually mean in this project. For each of `unittests-script`, `prepare-environment-script`, and `conformance-tests-script` (those that are declared), read the script end-to-end **before** launching, and write down for yourself:

   - **Which framework is invoked** (e.g. `vitest`, `jest`, `pytest`, `go test`, `cargo test`, `phpunit`, etc.) and any framework flags (`--noEmit`, `--reporter=verbose`, custom configs).
   - **What "pass" means**, exit-code-wise. Some scripts combine multiple checks (e.g. `unit_testing_typescript.sh` here runs `tsc --noEmit` *and* `vitest`, and its final exit code is the worst of the two — so a type error alone fails the unit-test gate).
   - **What "fail" means**, including any failures that the script deliberately downgrades to warnings (e.g. `prepare_environment_typescript.sh` here treats a failed `npm run build` as a non-fatal warning). Failures the script swallows are failures the renderer will **never see**, so a spec defect that depends on them will silently slip through.
   - **Where the scripts materialize their working environment** (current-convention scripts stage into the system temp directory, e.g. `/tmp/typescript_<build_folder_basename>/`; older scripts used project-local folders like `.tmp/typescript_<build_folder>/`, `build/`, `target/`). This is where the renderer's iteration actually runs; if you need to look at what is breaking, this is the directory — not `plain_modules/<module>/` directly.
   - **How conformance tests are discovered and staged** (glob, naming convention, alias setup, etc.). Some scripts stage tests into the source tree (this repo flattens `conformance_tests/<module>/<fname>/` into `src/<module>/`); some run them in place; some require a specific file extension. This tells you exactly which conformance test file is in play for a given functionality.
   - **Toolchain prerequisites** the script asserts (Node version, Python version, specific binaries). If any are missing on the user's machine, stop now and tell them — the renderer will burn credits on phantom failures otherwise.

   Keep this synthesis short (5–10 bullets, project-specific). It is the single most important reference for the classifier in [Spec-deviation classification](#spec-deviation-classification). The healthcheck only checks that the scripts *exist* and are *referenced correctly*; this step is the only place that reads what they actually *do*.

## Launch always in `--headless` mode

The agent must always launch the renderer in the background and supervise it via the log file and filesystem. The terminal tool **cannot** drive an interactive TUI, so TUI mode is incompatible with agent-launched rendering. Always use `--headless`:

```bash
nohup codeplain <module>.plain --headless <other-flags> > /dev/null 2>&1 &
echo $!  # capture the PID
```

Record the PID. Confirm `codeplain.log` starts growing within a few seconds; if it doesn't, the launch failed — check the user's shell / API key and re-try.

## Log monitoring contract

The monitor loop in Phase 1 leans almost entirely on `codeplain.log`. Before describing the loop, here is exactly how to read this file efficiently and what to look for. Treat this section as the reference the loop calls into.

### How to read the log incrementally

The log grows monotonically during a run — only ever appended to, never rewritten — and can reach thousands of lines on a long render. Never re-read it whole on each pass. Track the **last byte offset** you read and read only the new bytes since then.

Keep two pieces of state across iterations:

- `LOG_PATH` — absolute path to `codeplain.log` (captured during pre-flight).
- `LOG_OFFSET` — number of bytes you have already consumed. Starts at `0` for a fresh run.

Each monitor pass:

```bash
SIZE=$(wc -c < "$LOG_PATH")
if [ "$SIZE" -gt "$LOG_OFFSET" ]; then
    tail -c +$((LOG_OFFSET + 1)) "$LOG_PATH"   # new bytes only
    LOG_OFFSET=$SIZE
fi
```

If `SIZE < LOG_OFFSET`, the file was truncated — a new run has started or somebody rotated the log. Reset `LOG_OFFSET=0` and re-read from the top.

If you cannot keep shell state between tool calls, the equivalent is: `wc -c` the file each pass to get the new size, remember the previous size in your own conversation state, and pass the byte range to `tail -c +<offset+1>` or `dd skip=<offset> bs=1`. Either way, **never** read the whole file on a routine pass — only when you need backstory (e.g. you just detected an error and want context from earlier).

### Catalog of log patterns to recognize

All patterns below are taken from the actual codeplain runtime. Treat them as the canonical signal vocabulary.

| Pattern (regex / substring) | Meaning | Loop action |
| --------------------------- | ------- | ----------- |
| `^INFO:codeplain:[-]+$` followed by `Module: <name>` and `Rendering functionality <N>:` | A new functionality is starting. The block ends at the next `-----` line. | Update `CURRENT_MODULE` and `CURRENT_FUNCTIONALITY`. Reset `ATTEMPT_COUNTER` to 0. Report to the user. |
| `Running unit tests script .* \(attempt: <N>\)` | Unit tests starting, possibly a retry. | If `<N>` climbs past 1, flag as warning; past 3, treat as Pathology G. |
| `\[#79FC96\]All Unit Tests scripts have passed successfully.\[/#79FC96\]` | Unit tests green. | Routine. Note the functionality is past the unit-test gate. |
| `Refactoring the generated code...` | Refactor pass between unit tests and conformance. | Routine. |
| `Implementing conformance tests...` / `Implementing test requirements:` | Conformance phase starting for the current functionality. | Routine. |
| `Running testing environment preparation script .* for build folder` | `prepare-environment-script` is running. | Routine. |
| `\[#79FC96\]All Testing Environment Preparation scripts have passed successfully.\[/#79FC96\]` | Env prep green. | Routine. |
| `Running conformance tests script .* for conformance_tests/<m>/<fname> \(functionality <N> in module <m>\)` | Conformance tests starting for functionality `<N>`. | Note `<fname>` — that is the on-disk folder where the latest conformance test lives. |
| `Running conformance tests attempt <N>.` | Conformance retry loop. **Watch `<N>` carefully.** | Increment `ATTEMPT_COUNTER = <N>`. At `>=5`, trigger Pathology A. |
| `Fixing conformance test for functionality <N> in module <m>.` | Renderer is patching its own conformance test between attempts. | On its own, routine. Combined with climbing `<N>`, smoking gun for Pathology A. |
| `Functional spec too complex!` | Single spec implies >200 LOC. Renderer aborts. | Pathology B. |
| Substrings: `missing concept`, `unknown definition`, `cyclic`, `not defined`, `cannot resolve` | Spec graph error. Renderer aborts. | Pathology C. |
| Substrings: `conflict`, `conflicting`, `contradicts` | Spec conflict surfaced. | Pathology D. |
| `Traceback (most recent call last):` followed by a Python stack | Renderer itself crashed (not a spec error). | Stop monitoring; surface the stack to the user verbatim; this is a bug report case, not a spec edit. |
| `\[#FF6B6B\]✗ rendering failed` | Renderer aborted. Followed by `render id`, `input file`, `generated code folder`, `functionalities`, `used credits`, `render time`. | Capture the whole failure block. Run is over — go to Phase 4 (failure branch). |
| `\[#79FC96\]✓ rendering succeeded` (or `rendering complete`) followed by the same metadata block | Renderer finished successfully. | Capture the success block. Run is over — go to Phase 4 (success branch). |
| `429` / `rate limit` / `quota` / `unauthorized` / `403` / `401` | API problem, not a spec problem. | Stop monitoring; tell the user the API rejected the request and surface the line. |
| **No new bytes for > 2 min while the process is alive** | API stall or wedged renderer. | Pathology E. |

Where a column says "Pathology X", see Phase 2 for the response.

### Three pieces of state to maintain across the loop

The pathologies in Phase 2 can only be detected if you carry state between iterations. Keep these three variables in your working memory across passes:

1. **`CURRENT_FUNCTIONALITY`** — the integer ID of the functionality currently being rendered. Updated whenever you see `Rendering functionality <N>:`.
2. **`LAST_COMPLETED_FUNCTIONALITY`** — the highest functionality ID whose conformance tests passed cleanly (i.e. no `Fixing conformance test` immediately after, and either the next `Rendering functionality <N+1>:` line appeared or the run succeeded). This is the value you'll pass to `--render-from <N+1>` on resume.
3. **`ATTEMPT_COUNTER`** — the most recent `Running conformance tests attempt <N>` value for `CURRENT_FUNCTIONALITY`. Reset to 0 when `CURRENT_FUNCTIONALITY` changes.

A single-line summary of these three values is what you'll show the user on each pass.

### Useful one-liners

Use these as cheap, idempotent ways to interrogate the log. Each is safe to run on any pass.

- Latest functionality the renderer started:
  ```bash
  grep -E "Rendering functionality [0-9]+:" codeplain.log | tail -n 1
  ```
- Current conformance attempt counter:
  ```bash
  grep -E "Running conformance tests attempt [0-9]+\." codeplain.log | tail -n 1
  ```
- All errors so far:
  ```bash
  grep -E "^(ERROR|CRITICAL|WARNING):codeplain:|✗ rendering failed|Functional spec too complex|Traceback" codeplain.log
  ```
- Time the last log line was written (proxy for liveness):
  ```bash
  stat -f %m codeplain.log   # macOS — epoch mtime
  ```

## Reading test-script output

The renderer drives three external shell scripts during a run — `unittests-script`, `prepare-environment-script`, and `conformance-tests-script` (whichever are declared in the project's `config.yaml`). Each script wraps a real test framework (vitest, jest, pytest, tsc, etc.) and writes verbose output. It reads the output those scripts produce while the renderer is iterating. Three places to look, in priority order:

### 1. Inline in `codeplain.log` (the primary source)

With verbose logging on (the default — `--verbose` is `disabled`), codeplain captures each script's stdout/stderr and writes it into `codeplain.log` between its own wrapper lines:

```
INFO:codeplain:Running unit tests script .../unit_testing_typescript.sh. (attempt: 1)
... script output here: vitest summaries, FAIL lines, tsc diagnostics ...
INFO:codeplain:[#79FC96]All Unit Tests scripts have passed successfully.[/#79FC96]
```

So when you do the incremental log read in Phase 1, you are simultaneously reading the **renderer wrapper lines** ("running", "passed", "fixing") *and* the **raw framework output** sandwiched between them. The wrapper says *whether* the script passed; the framework output says *why* it failed and *what* the renderer is reacting to. Both are needed.

What to extract from the framework output — stay framework-agnostic, look for these shapes:

- **Counts**: `<N> passed`, `<M> failed`, `<K> skipped`. Climbing failure count between attempts means the renderer is making things worse.
- **Individual test names that failed**: lines beginning with `×`, `FAIL`, `✗`, `× should ...`, `FAIL src/.../foo.test.ts > <name>`. The *same* test failing across attempts is the smoking gun for an under-specified spec.
- **Assertion bodies**: `expected X, got Y`. The values reveal exactly what the test expects vs what the implementation produced — the cleanest input to the classifier below.
- **Compile / type errors** (when the script wraps a type-checker): `error TS<NNNN>`, `cannot find module`, `is not assignable to`. A unit-test gate that keeps re-failing on the same type error means the implementation req or the type-level spec is wrong, not the code.
- **Stack traces**: which file under the prepared working folder threw, and at which line. Map the file back to `plain_modules/<module>/src/...` to find the code the spec is supposed to be governing.
- **"No test files found" / "No tests collected"**: the script ran but discovered nothing. Almost always a path/glob mismatch in the staged working folder, not a spec problem. Treat as Pathology F.

Always set the logs to be verbose in `config.yaml`. 

### 2. Renderer memory under `plain_modules/<module>/.memory/`

The renderer writes structured JSON notes about its own iteration there. The most useful is `conformance_test_memory/<issue_id>.json`, with fields like:

```json
{
  "functionality": "Agent CLI",
  "initial_issue_summary": "...what was failing at the start...",
  "fix_attempt_summary": "...what the renderer changed...",
  "current_issue_summary": "...what is still wrong now...",
  "resolution_status": "UNRESOLVED",
  "key_learnings": "...the renderer's own diagnosis of why..."
}
```

This is the renderer telling you, in its own words, what it tried and what is stuck. A `resolution_status: "UNRESOLVED"` is a hard signal that the loop is not converging — read the `key_learnings` field; it usually pinpoints the ambiguity in the spec or the limit of what the renderer can infer.

Refresh these files on each pass while a retry loop is active — the renderer rewrites them between attempts.

## Spec-deviation classification

This is the most important active judgment the skill makes. Once a functionality enters a retry loop (unit-test or conformance), the renderer iterates — changing source code, and sometimes changing its own conformance tests — trying to satisfy the test-script output. **Not every iteration is honest.** Each iteration must be classified before deciding whether to let the renderer continue, stop and fix the spec, or stop and fix the test script.

The inputs to the classifier are:

1. The **spec** that governs the failing functionality — the functional spec and its acceptance test(s) in the `.plain` file.
2. The **test-script output** for the most recent attempt, from `codeplain.log` per the section above.
3. The renderer's own **`.memory/conformance_test_memory/<id>.json`** for this functionality (when present).
4. The newest **conformance test file** the renderer just edited under `conformance_tests/<module>/<fname>/`.
5. The newest **implementation file(s)** the renderer just edited under `plain_modules/<module>/`.

With these in hand, place the current iteration into one of four buckets:

### Bucket 1 — Honest convergence (let it continue)

Signals:

- Failure count is **going down** across attempts (e.g. 5 failed → 3 failed → 1 failed).
- The set of failing test names is shrinking and is a *subset* of the previous attempt's failures.
- The conformance test file is **unchanged** between attempts — only the implementation is changing.
- `key_learnings` in memory (if present) reads as legitimate technical reasoning about the framework / language / library, not about reinterpreting the spec.

Action: let the renderer keep going, up to the threshold (5 conformance attempts / 3 unit-test attempts). Report progress to the user with the per-attempt failure count.

### Bucket 2 — Spec under-specification (stop and fix the spec)

Signals — any one of these is enough:

- The **same test** fails every attempt with the **same assertion**, and the assertion checks something the functional spec **does not explicitly say** (e.g. exact exit code, exact error wording, specific status field).
- `current_issue_summary` in memory describes a question the spec does not answer (e.g. "unclear whether `--help` should exit 0 or 2").
- The renderer's `fix_attempt_summary` keeps oscillating between two opposite interpretations of the same requirement (regex variant A this attempt, variant B next attempt, A again the attempt after).
- The conformance test file is being rewritten between attempts in a way that **changes which behavior is being asserted**, not just how it is asserted.

Action: stop the renderer (SIGINT). Hand off to `debug-specs`. The spec must be tightened so there is only one valid behavior to converge on. Then resume with `--render-from <N>` for the offending functionality.

### Bucket 3 — Renderer is drifting away from the spec (stop immediately)

The dangerous case. Signals:

- The renderer **rewrote a conformance test to weaken the assertion** — the test now accepts behavior the original spec does not allow. Compare the latest conformance test file to the previous attempt's; an assertion that loosened a `===` to a `>=`, removed an `expect`, or wrapped behavior in a `try/catch` to swallow failures is a drift signal.
- The renderer **deleted code that implemented a requirement** to make a test pass (a `try/catch` that now silently returns 0, a feature flag short-circuit, a hard-coded return value matching the test). Visible by diffing `plain_modules/<module>/src/...` across attempts.
- The renderer's `key_learnings` reads like rationalization rather than diagnosis (e.g. "adjusted assertion to match observed behavior", "removed strict check that was causing failures").
- Failure count is going **up** between attempts.

Action: stop the renderer **immediately**, don't wait for the threshold. The fix must be applied to the `.plain` file (the spec was probably not specific enough and the renderer chose the path of least resistance):
   - If it happened during the **conformance testing phase**, the `***test reqs***` need to be tightened.
   - If it happened during the rendering of a **functional requirement**, the functional specs, definitions, or `***impl reqs***` need to change.
   - If it happened during **acceptance testing**, the acceptance test definitions need to be tightened.

Do nothing on the generated-code side; the broken code under `plain_modules/` will be overwritten on resume. **Never** hand-edit it.

Then resume with `--render-from <N>` (or `--force-render` if the drift contaminated earlier functionalities). Re-running `plain-healthcheck` first is mandatory.

### Bucket 4 — The test script itself is the source of the failure (Pathology F)

Signals:

- Test-script output shows a **toolchain** error (`vitest: command not found`, `python: No module named pytest`, Node version too old).
- Output is `No test files found` / `no tests collected` while the conformance tests do exist on disk — a glob/path/staging bug in the script.
- The script is failing **before** running any framework command at all (`die: prepared environment missing`, missing argument, etc.).
- The failure mode is identical across functionalities, not specific to the spec being rendered.

Action: This is **not** a spec problem and the spec should stay as is. Stop the renderer and investigate why the script fails:
- If it's a bug in the script (e.g., pathing issue, syntax error, missing environment variable load), attempt to fix the script directly, or hand off to the matching `implement-*-testing-script` skill.
- If it's a missing host dependency (e.g., Python or Node is not installed, or a required global package is missing), inform the user and ask them to install it.
- **Before resuming the renderer**, test the script by running it manually exactly as the renderer would. If the same infrastructure/script issue persists, the fix didn't work. If the script now runs (even if it reports legitimate test failures), the fix was successful.

### Classifier discipline

- Run the classifier **only** when a retry loop is actually in progress (`ATTEMPT_COUNTER >= 2`). For a first attempt that just failed, there isn't enough data yet — the renderer hasn't done a fix pass.
- Show your classification reasoning to the user before acting on Bucket 2 or Bucket 3. State the bucket, the concrete evidence ("test `should exit 0 on --help` has failed 3 attempts; spec text does not specify exit code"), and the proposed hand-off skill. Get their go-ahead before SIGINT.
- If two buckets seem to apply, prefer Bucket 4 → Bucket 3 → Bucket 2 → Bucket 1 in that order. A script bug shadows everything; a drift is worse than under-specification; under-specification is worse than honest iteration.

## Phase 1 — Monitor loop

Run the loop until one of these terminal conditions holds: the process exits successfully, the process exits with failure, or you (with the user's approval) kill it.

On each iteration, in this order:

### 1a. Read the new log bytes (primary)

Using the incremental read recipe above, pull only the bytes appended since the last pass. Walk the new text against the pattern catalog and update `CURRENT_FUNCTIONALITY`, `LAST_COMPLETED_FUNCTIONALITY`, and `ATTEMPT_COUNTER`. Because verbose mode is on by default, this chunk also contains the **raw test-script output** (vitest summaries, tsc errors, stack traces) sandwiched between the renderer's wrapper lines — capture failure counts, failing test names, and key assertion text. Note any pathology hits, but don't act on them yet; finish the pass first so the report is consistent.

If there are **no new bytes**, note the elapsed time since the last log activity (`stat` mtime works). Hitting 2 minutes of silence with the process alive triggers Pathology E.

### 1b. Is the process alive?

- Mode A: `ps -p <pid>` (or `kill -0 <pid>`). If gone, capture the exit code via `wait`, or fall back to the log's final block (success / failure banner).
- Mode B: `pgrep -fl codeplain` should still return the run. If not, the user already stopped it (or it finished).

If the process is gone but you haven't yet seen a `✓` or `✗` banner in the log, do one more incremental read — the banner is the very last thing codeplain writes, and the process exits immediately after.

### 1c. Inspect the filesystem (corroboration only)

This is a secondary signal — it confirms what the log already said. Don't go on a fishing trip here.

For the current module, the renderer drops generated code into `plain_modules/<module>/` and conformance tests into `conformance_tests/<module>/<functionality_name>/`. Each pass, inspect what is new:

- New files under `plain_modules/<module>/src/` confirm the functionality is being implemented.
- New folders under `conformance_tests/<module>/` confirm the functionality has reached the conformance phase.
- Files that were rewritten between passes are the renderer's "fix" attempts — diffing them across iterations is what reveals whether the renderer is converging or thrashing.

Read **only the newest** file(s) (the ones that changed since last pass), and read them to understand *what the renderer chose to do*, not just *that* it did something. This is the first line of defense against "the spec is ambiguous and the renderer guessed wrong" — you can often spot the wrong guess in the generated code long before tests fail.

Generated code under `plain_modules/` and `conformance_tests/` is **read-only**. Never edit it. Edits go in the `.plain` files.

### 1d. Cadence

Poll every 10–30 seconds. Faster than 10s is noisy and wastes tool calls; slower than 30s makes the user feel ignored. Tighten the cadence (down to 5s) when something looks off — climbing `ATTEMPT_COUNTER`, a new error keyword in the latest log chunk, an unexpectedly quiet log. Loosen the cadence (out to 60s) during long, healthy "rendering functionality N" stretches where the log is moving steadily and nothing alarming has appeared.

The log read is cheap (incremental), so the bottleneck is the user-facing report, not the I/O. Prefer to err on the tighter side.

### 1e. Report to the user

After each pass, give the user a **short** status line — one or two sentences, built from the three state variables. Examples:

- `Functionality 3/? in flight; unit tests just passed, conformance prep starting.` (after a `Implementing conformance tests...` line)
- `Functionality 4 is on conformance attempt 4 of an open loop; unit tests still green. One more attempt and I'll flag it.` (`ATTEMPT_COUNTER = 4`)
- `No new log lines in 95s; PID 12345 still alive. Likely an API call in flight.` (silent log, alive process)
- `Last completed: functionality 2. Currently rendering functionality 3.` (resume-readiness summary)

Do not dump the raw log unless the user asks for it. When you do dump it, paste only the relevant block (e.g. the failure banner with the surrounding 10 lines), not the entire file.

## Phase 2 — Pathologies and intervention

These are the patterns that justify stopping the renderer. For each, the workflow is the same: **detect → confirm with the user → stop → diagnose → fix the specs → resume**.

### Pathology A — Conformance loop that won't converge

Symptom: `Running conformance tests attempt <N>` keeps climbing for the **same** functionality, with `Fixing conformance test for functionality <N>` between attempts. Unit tests stay green; only the conformance step fails.

Threshold: **5 attempts on the same functionality** is the heuristic. The renderer will keep going (the real `codeplain.log` in this repo shows it climbing to 10), but each attempt costs credits and rarely converges if it hasn't by 5.

Do **not** treat hitting the threshold as the diagnosis. From `ATTEMPT_COUNTER >= 2` onwards, run the [Spec-deviation classification](#spec-deviation-classification) classifier each pass. The bucket it returns is the diagnosis:

- **Bucket 1** — keep going until the threshold; report the per-attempt failure count.
- **Bucket 2** — stop now (regardless of how close to the threshold you are); hand off to `debug-specs` / `add-implementation-requirement` / inline spec edit. The spec is under-specified.
- **Bucket 3** — stop **immediately**, do not wait for the threshold; the renderer is drifting. Tighten the spec or acceptance test before resuming.
- **Bucket 4** — the test script is the problem; route to Pathology E instead.

### Pathology B — `Functional spec too complex!`

The renderer rejected a spec because it would imply >200 LOC. Stop is automatic — the renderer aborts. Hand off to `break-down-func-spec`.

### Pathology C — Missing concept / unknown definition / import error

The renderer can't resolve a reference. Stop is automatic. Hand off to `add-concept` (or fix the `import` / `requires` chain). Re-run `plain-healthcheck` before resuming — a dry-run will catch this faster next time.

### Pathology D — Conflicting specs

Renderer surfaces a conflict, or you can see two specs in the same module that contradict each other in the generated code. Hand off to `resolve-spec-conflict`.

### Pathology E — Test scripts themselves are broken

Symptom: log shows the unit-test or conformance-test **script** itself failing (non-zero exit, syntax error, missing dependency) on every attempt, rather than the renderer's code failing the tests. The fix is **not** a spec change — it is a `test_scripts/` change. Stop and hand off to the matching `implement-*-testing-script` skill, or have the user repair the script directly.

**Special case — stale scripts after a renderer upgrade (doubled paths).** The renderer now passes the build folder and conformance-tests folder to the scripts as **absolute paths**; older test scripts built paths by concatenating those arguments (`.tmp/$1`, `python_$1`, `$current_dir/$2`). The tell is a test-log path that contains the project root **twice**, e.g.:

```
ImportError: Start directory is not importable
/Users/x/project//Users/x/project/conformance_tests/module/spec
```

The render then gets stuck "fixing" tests that can never pass. The fix is never a spec edit: stop the render and regenerate the affected scripts via the matching `implement-*-testing-script` skill (current convention: system-temp working folder from `basename "$1"`, `$2` resolved to absolute before any `cd`).

### Pathology F — Unit-test retry loop

Less common than the conformance loop, but the same shape: `Running unit tests script ... (attempt: <N>)` with `<N>` climbing for the same functionality. Threshold: **3 attempts**. From `ATTEMPT_COUNTER >= 2` onwards, run the same [Spec-deviation classification](#spec-deviation-classification) classifier and act on the bucket it returns. The most common root causes for unit-test loops are an implementation req that doesn't match the unit-test scaffolding (Bucket 2), or test reqs / framework usage that the renderer is satisfying by weakening assertions (Bucket 3). Hand-off is typically `add-implementation-requirement` or `debug-specs`.

### How to actually stop the renderer

Always **SIGINT first**, never SIGKILL unless SIGINT fails:

```bash
kill -INT <pid>
```

SIGINT lets codeplain flush the log and close out the run cleanly. Wait ~5s, then check `ps -p <pid>`. If still alive, repeat once. Only after a second SIGINT has failed should you escalate to `kill -TERM <pid>` and, last resort, `kill -9 <pid>`.

After the process is gone, do **one** final incremental read of the log — the renderer often writes a closing block on shutdown (`✗ rendering failed` with render id, input file, used credits, render time). Capture it; it's the most useful single artifact for the user.

The value of `LAST_COMPLETED_FUNCTIONALITY` you've been tracking is what you'll feed `--render-from` on resume (as `<N+1>`). If you weren't tracking it carefully, recover it now with:

```bash
grep -E "Rendering functionality [0-9]+:" codeplain.log | tail -n 1
```

and subtract 1 if the last functionality didn't reach a clean conformance pass.

## Phase 3 — Fix + resume

1. **Hand off to the right edit skill.** Don't do the spec edit inside this skill — invoke the dedicated one (`debug-specs`, `resolve-spec-conflict`, `break-down-func-spec`, `add-implementation-requirement`, `add-concept`, `add-functional-spec`, etc.). Pass it concrete evidence: the offending log lines, the file paths under `plain_modules/` you read, and the spec the user agreed is wrong.
2. **Re-run `plain-healthcheck`** after the fix. If it FAILs, do not resume — fix the next thing first.
3. **Resume with `--render-from`.** If the last fully-completed functionality was `<N>`, resume with the next one:

   ```bash
   codeplain <module>.plain --headless --render-from <N+1> <same-other-flags-as-before>
   ```

   `--render-from` includes its argument, so the value passed is the **first functionality you want re-rendered**, not the last one that already passed. If nothing completed, omit `--render-from` and start over from the beginning. If only a single functionality needs re-rendering and the rest are fine, prefer `--render-range <N>` instead.

4. **Re-enter the monitor loop** in Phase 1.

If the fix required regenerating a module's earlier output (e.g. a definition change that ripples backwards), use `--force-render` instead of `--render-from`. Confirm this trade-off with the user — it costs more credits.

## Phase 4 — Wrap up

When the renderer exits successfully:

1. Read the success banner from the log: render id, generated code folder, functionalities count, used credits, render time. Report it to the user verbatim — these are the numbers they actually care about.
2. List the top-level files/folders that appeared (or changed) under `plain_modules/<module>/` and `conformance_tests/<module>/` so the user knows where to look.
3. Remind the user of the **side-channel commands** they may want to run themselves, based on the config:
   - `./test_scripts/<unittests-script>` for unit tests,
   - `./test_scripts/<prepare-environment-script>` to set up the test env,
   - `./test_scripts/<conformance-tests-script>` for conformance tests.
   Only mention the scripts the project's `config.yaml` actually declares.
4. If `--copy-build` was set, confirm the build was copied to `--build-dest`. If `--copy-conformance-tests` was set, same for `--conformance-tests-dest`.

When the renderer exits with a failure that wasn't intercepted by Phase 2 (e.g. transient API error, auth failure), report the failure block from the log and ask the user whether to retry (`--render-from` from the last completed ID) or to investigate.

## Anti-patterns

- **Editing generated code to "fix" a render.** Never. Generated files under `plain_modules/` and `conformance_tests/` exist as evidence only; they are overwritten every render. All fixes go in `.plain` files.
- **Reading the test scripts' source code to understand what's failing.** Don't. The scripts run real frameworks (vitest, pytest, etc.) and the *output* of those frameworks — captured in `codeplain.log` and in `.memory/conformance_test_memory/*.json` — is what tells you what is failing and why. Reading the script source tells you nothing the log doesn't already say.
- **Treating every conformance loop as under-specification.** Run the classifier. The renderer sometimes drifts (Bucket 3) by silently weakening its own tests; that is the opposite problem and the fix is different.
- **Re-reading the whole log on every pass.** It grows. Track the byte offset and read only what was appended since the last pass. Full reads are reserved for "I just saw an error and need backstory."
- **Trusting the filesystem over the log.** The filesystem only updates when a step completes; the log updates the moment any step *starts*, retries, or fails. When they disagree, the log is right.
- **Letting a conformance loop run indefinitely.** Each attempt costs credits and the renderer will keep going past any reasonable point (this repo's `codeplain.log` climbed to attempt 10 before bailing). The threshold is 5; surface it to the user immediately.
- **Re-running the whole module after a small fix.** Use `--render-from <N+1>` or `--render-range <N>`. Only fall back to `--force-render` when a backward dependency genuinely changed.
- **Trying to read the TUI.** You can't see it. Use the log file and filesystem; ask the user to paste the TUI's test panel if the log is missing verbose output.
- **Dumping raw log into chat on every pass.** Summarize from the three state variables (`CURRENT_FUNCTIONALITY`, `LAST_COMPLETED_FUNCTIONALITY`, `ATTEMPT_COUNTER`) plus a classifier verdict when a loop is in progress. The user wants signal, not transcript.
- **Skipping `plain-healthcheck` because "dry-run passed earlier".** Specs drift; configs drift. Re-run it before every real render and after every fix.
- **`kill -9` as a first move.** Always SIGINT first — codeplain needs to flush its log and clean up.

## Validation checklist

- [ ] Target `.plain` file and governing `config.yaml` were confirmed before launch
- [ ] `plain-healthcheck` is PASS as of the latest spec state
- [ ] `CODEPLAIN_API_KEY` is set, or `--api-key` was supplied
- [ ] Launch mode (`--headless` agent-launched vs. user-launched TUI) was chosen with the user
- [ ] Renderer PID is known (or, in Mode B, confirmed alive via `pgrep`)
- [ ] Log file path is known and is observed to be growing
- [ ] Log path was captured during pre-flight and a byte offset is being tracked across passes
- [ ] Monitor loop reads only the new bytes of `codeplain.log` each pass (no full re-reads on routine passes)
- [ ] `CURRENT_FUNCTIONALITY`, `LAST_COMPLETED_FUNCTIONALITY`, and `ATTEMPT_COUNTER` are maintained across passes
- [ ] Filesystem inspection is used only to corroborate log signals, not as the primary signal
- [ ] Status reports to the user are short (≤2 sentences) and signal-driven, not transcript dumps
- [ ] Test-script output (failure counts, failing test names, assertion bodies, stack traces) is being extracted from the verbose log chunks each pass
- [ ] When `ATTEMPT_COUNTER >= 2`, the spec-deviation classifier ran and returned a bucket (1–4) before any stop/continue decision
- [ ] If a classifier verdict caused a stop, the bucket and concrete evidence (failing test name + spec gap, or the diff that showed drift) was shown to the user before SIGINT
- [ ] `.memory/conformance_test_memory/<id>.json` was read (if present) to capture `current_issue_summary` and `resolution_status`
- [ ] Pathologies (loop / complexity / missing concept / conflict / stall / broken test script / drift) are recognized and acted on
- [ ] Renderer was stopped with SIGINT (escalating only on failure) — not SIGKILL by default
- [ ] Spec fixes were delegated to the right edit skill, not done inside this skill
- [ ] Resumes use `--render-from <N+1>` (or `--render-range`) — `--force-render` only with user approval
- [ ] On success, final render id / credits / time were reported and side-channel test commands were surfaced
- [ ] No generated code under `plain_modules/` or `conformance_tests/` was modified
