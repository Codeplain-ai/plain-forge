# Phase 4 — Validate and hand off

Two halves. First **the agent** validates every spec end-to-end with a `codeplain` dry-run so the user never wastes a real render — or any debugging time — on a fixable static error. Only after that passes does the agent **hand off** the render command (plus any side-channel commands) to the user.

## 4a. Identify the render target

Find the **last module in the dependency chain** — the module that is not `requires`-ed by any other module. If there is only one module, use it. Call this module `<module>`.

- Chain `base.plain → features.plain → integrations.plain` → render target is `integrations.plain`.
- Single module `my_app.plain` → render target is `my_app.plain`.

## 4b. Build the final `config.yaml` with `init-config-file`

Finalize the project's `config.yaml` file(s) before validation. Phase 3 may have written provisional entries as scripts were generated; **this** is where they are consolidated into the canonical form the renderer expects. Invoke the `init-config-file` skill. It:

- enumerates every part of the project (one `config.yaml` per part — single-stack → root config; multi-part → one config per part),
- assembles only the **valid** config keys derived from the `codeplain` CLI parser,
- emits a clean YAML file per part (script paths first, then template/build folders, then copy/log settings),
- verifies every `*-script` value resolves to a real file on disk,
- refuses to write secrets (`api-key`) or per-invocation flags (`dry-run`, `full-plain`, `render-range`, `render-from`, `replay-with`) into the config.

If `init-config-file` stops because a precondition isn't met (e.g. a `prepare-environment-script` exists but no conformance script does), resolve the gap with the user before continuing — do **not** hand a known-broken config to `plain-healthcheck`.

## 4c. Validate the project with `plain-healthcheck`

Run the `plain-healthcheck` skill — the single source of truth for "is this project ready to render?". Do **not** run the dry-run inline. It:

- inventories every `.plain` module and identifies every top module,
- validates every `config.yaml` (existence, parseability, script paths actually pointing at files in `test_scripts/`, no mixed stacks), and
- runs `codeplain <top>.plain --dry-run` for **every** top module with the correct `--config-name` for multi-part projects.

The skill runs the full detect → fix → re-run loop itself (syntax errors, undefined concepts, broken `import` / `requires` chains, cyclic definitions, missing templates, complexity violations, conflicting reqs, config drift, missing scripts) and returns only once everything passes or a gap genuinely needs the user. Then:

- **`PASS`** → move on to step 4d.
- **`FAIL`** → do **not** ask the user to render. Work through the numbered list it produced (each item references a specific `.plain` file, `config.yaml`, or script), resolve each one with the appropriate edit skill, and re-run `plain-healthcheck` until it returns `PASS`. Any item the skill could not auto-resolve will name the concrete question to put to the user.
- **Environment failure** (e.g. `codeplain` not on PATH, `CODEPLAIN_API_KEY` not set) → `plain-healthcheck` surfaces this as a clearly-marked environment failure. Tell the user exactly what's missing and how to fix it before continuing. Do not pretend the healthcheck passed.

## 4d. Present the render command

Only after the dry-run passes, tell the user their specs are ready and present the render command:

```
codeplain <module>.plain
```

- Chain `base.plain → features.plain → integrations.plain` → `codeplain integrations.plain`.
- Single module `my_app.plain` → `codeplain my_app.plain`.

Also remind the user of any **side-channel commands** they may want to run themselves per the Phase 3 testing strategy — for example `./test_scripts/run_unittests.sh <module>`, `./test_scripts/prepare_environment.sh <module>`, or `./test_scripts/run_conformance_tests.sh <module> <conformance_tests_folder>`. Mention only the scripts that were actually generated in Phase 3.
