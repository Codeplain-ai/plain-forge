---
description: Rules for authoring ***plain specs for REST API integrations embedded into an existing host codebase
globs: "**/*.plain"
---

# Rules for **embedded** integration specs

When an integration `.plain` module is **embedded** — meaning the generated code in `plain_modules/` is consumed in-process by an existing host codebase as a library / module — these rules apply on top of the shared rules in [`integrations.md`](integrations.md). If anything below contradicts a guess made from memory, the rules here win.

Embedded means: the host codebase already exists, has its own language / framework / dependency manager / packaging layout, and the integration must conform to all of that without negotiation.

## The host codebase dictates the tech stack (hard rule)

- Language, framework, dependency manager, packaging layout, coding standards, error model, logging library, and architecture are **inherited** from the host — they are **never chosen** by the integration spec
- Do not re-ask the user about any of these in any phase — they are facts to be discovered from the host's manifest files (`pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, `pom.xml`, …) and source tree
- If a Phase 3 (`forge-plain`) tech-stack question seems to push back on a host rule, treat the host as ground truth and rewrite the question
- Implementation reqs added in Phase 3 are **transcribed** from the host stack verbatim — host language and exact version, host framework + version, dependency manager and manifest path, packaging layout, host conventions the contract must follow, and every host-package version the contract pins

## Discover before you ask

Run host discovery **before** the first Phase 1 question. Treat the results as ground truth for everything that follows.

1. **Locate the host's `.plain` setup (if any).** Look for an existing `.plain` file or directory, a `config.yaml` declaring `plain_source_dir` / `plain_modules_dir` / `resources_dir` / `test_scripts_dir`, a `plain_modules/`, a `resources/`, and a `test_scripts/`. If the host already has a `.plain` setup, **adopt it verbatim**: the new integration module lands inside the existing `plain_source_dir` and `requires` the relevant base module (use `create-requires-module`). Do not create a parallel layout.
2. **Read every existing integration in the host.** For each one, extract: intent and scope, host base class / interface / protocol the integration subclasses or implements, package path and naming convention, configuration pattern (env vars, settings module, secret manager), error / exception hierarchy, logging / metrics / tracing conventions, testing pattern (live vs recorded vs mocked, fixture location, conformance-test layout). The new integration must follow the same patterns unless the user explicitly opts out.
3. **Capture findings in the `host-codebase` concept.** Cite the existing integration by file path so the reasoning is auditable. The concept holds, as facts:
   - Host codebase root (absolute or project-relative path)
   - Host language and exact version (from the manifest file)
   - Dependency manager and manifest file path (pip + `requirements.txt`, Poetry, uv, npm, pnpm, yarn, Go modules, Cargo, Maven, Gradle, …)
   - Package / module path inside the host where the integration will be consumed
   - Fully qualified import path of any host class / interface / struct / protocol the integration must conform to (e.g. `host_project.integrations.base.IntegrationContract`)
   - Host conventions (custom base classes, Pydantic major version, sync vs. async style, exception hierarchy, dependency-injection seams, logging library)
   - Target generated-class fully qualified name under `plain_modules/` (e.g. `plain_modules.integrations.<provider>.Client`) and the host base class it should subclass
4. **Only ask the user what the codebase cannot tell you.** The user's time goes into the third-party API itself (provider, docs, endpoints, edge cases, webhooks) and authentication / credentials. Everything else is a deduction. If a deduction is ambiguous (two existing integrations subclass two different base classes), surface the ambiguity with a single-question `AskUserQuestion` that quotes both code locations — the question is about resolving a conflict the host already contains, not about asking the user to design the integration.

## Reference host symbols by fully qualified import path

- Every host class, interface, struct, exception, or type alias that appears in a spec must be written with its full dotted / slashed import path (e.g. `host_project.integrations.base.IntegrationContract`, `@host/integrations#Contract`) and tagged in the spec text as **"imported from the host codebase; do not redefine"**
- The renderer is allowed to redefine **only** symbols the host does not provide and the contract schema does not capture
- Naming the symbol by FQN is not optional decoration — it tells the renderer where the type comes from, which prevents a duplicate definition under `plain_modules/`

## Link host files at their original path — never copy them into `resources/`

The integration's `.plain` module lives **inside the host codebase** (per the "adopt the host's `.plain` setup verbatim" step). That means host source files are already reachable as linked resources via their host-relative paths. The integration spec references them **in place**; it never duplicates them under `resources/host/`.

- Every host file the integration touches (base classes, configuration modules, registries, exception classes, lifecycle hooks) is referenced from the relevant spec using `***linked resource***` syntax with the **path as it exists in the host codebase** — e.g. `[base.py](host_project/integrations/base.py)` if the `.plain` module sits next to `host_project/`
- **Do NOT copy host files into `resources/host/`.** A copy creates a second source of truth that drifts the moment the host file is edited; the rendered code will then disagree with whatever the host actually ships
- **Do NOT add host files via the `add-resource` skill's default copy behavior** when that behavior would duplicate the file — point at the existing host path directly
- **Never inline a host file's contents** into a spec
- **Never describe a host symbol's shape from memory** — the renderer reads the linked file's bytes at its host path and that is the source of truth
- This still obeys the broader [`linked-resources.md`](linked-resources.md) rules: a directory is not a valid link, a URL is not a valid link, a binary is not a valid link. Only the *location* changes — host files live where the host put them, not under `resources/`

### What still belongs under `resources/`

This rule applies to **host source code only**. Other artifacts still live under `resources/` exactly like in a non-embedded project:

- **Contract schemas authored by the integration** — `resources/contract/<entry-point>.schema.json`
- **Configuration schema** — `resources/config.schema.json`
- **Captured probe responses** (from the live-API cross-check) — `resources/fixtures/<endpoint>.<case>.json`
- **Static lookup tables** the integration owns — `resources/error-map.yaml`, `resources/retry-policy.yaml`, etc.

The rule of thumb: if the host wrote it and ships it, link it where the host put it. If the integration is authoring it for the first time, it goes under `resources/`.

## The contract spec declares inheritance, not duplication

- The entry-point class / interface / struct in the contract spec must `subclass` / `implements` / `embeds` the host symbol by its full import path
- The spec describes only the **integration-specific additions and overrides** — never restates the parent's fields or methods
- The additions and overrides are themselves expressed in the linked schema under `resources/contract/` (JSON Schema or OpenAPI), with `allOf` / `$ref` extending the host's schema rather than duplicating fields
- If a host base class adds fields the integration shouldn't redeclare, the contract schema's `allOf` chain captures that explicitly

## Renderer directives go in the spec, shapes go in the schema

Each contract spec carries the language-specific glue that the schema can't express:

- Target generated-class fully qualified name (e.g. `plain_modules.integrations.<provider>.Client`)
- Target file path under `plain_modules/`
- Host base class import path to subclass / implement
- Host-package version pins (e.g. `pydantic ~= 2.5`, `fastapi ^0.110`)
- Framework-specific decorators or metaclasses (`model_config`, `@Depends`, …)

The renderer reads the directives from the spec and the shapes from the linked schema, then emits the host-language class. The spec must **not** also contain a class body or a field list — that creates two sources of truth and they will drift.

## Single source of truth for the host root

- The `host-codebase` concept holds the host root path as a **fact**
- Test scripts, `prepare_environment`, configuration-loading specs, and any other spec that needs the host location reads it from **that one fact** (via the env var declared in the configuration concept)
- Never hardcode the host path in any spec, script, or runtime config

## No host-overlapping reqs

- Implementation reqs added in any phase must not contradict the host codebase — same language, same dependency manager, same packaging layout, same error hierarchy, same logging library
- If two reqs are in tension (one from the host, one newly authored), the host wins; rewrite or drop the newly authored req
- Do not author a req that re-declares something the host already enforces — that's a maintenance burden with no benefit

## Test-script wiring — merge `plain_modules` into the host, run tests there

Embedded integrations are tested **inside a working copy of the host codebase** with the generated `plain_modules/` overlaid on top. Both `run_unittests_<lang>` and `run_conformance_tests_<lang>` follow this pattern — neither uses `PYTHONPATH` / `NODE_PATH` tricks to stitch two trees together at import time. The host *is* the runtime environment; the generated module is dropped into it and exercised as if it had always lived there.

This matters because the integration's generated code references host symbols by their full import path (e.g. `from host_project.integrations.base import IntegrationContract`). Those imports only resolve cleanly when the test process is rooted in the host's package layout — anything else creates path edge cases that bite later in conformance failures.

### The merge step (used by both `prepare_environment` and `run_unittests`)

Both scripts stage their own working copy under `.tmp/<lang>_<arg>/` per the shared testing-script rules (input folders are read-only). Inside that working folder:

1. **Copy the host codebase into the working folder.** Use a recursive copy (`rsync -a --delete`, `cp -R`, or `robocopy`) so each test run starts from a clean, identical host tree
2. **Overlay `plain_modules/<module>/` into the host's package tree at the target package path** recorded in the `host-codebase` concept (e.g. `plain_modules/integrations/<provider>/` → `<host_copy>/host_project/integrations/<provider>/`). Use a copy that overwrites — the generated module replaces any same-named files in the host copy
3. **Install dependencies inside the merged tree.** The host's own manifest (`pyproject.toml` / `package.json` / `go.mod` / …) drives the install. The integration's extra dependencies are layered on top by either (a) the renderer having written them into the host's manifest already, or (b) the script installing them explicitly after the host install
4. **Run the test command from inside the merged tree** — `cwd` is `<host_copy>`, and the test runner discovers tests using the host's normal layout

### Per-script responsibilities

- **`prepare_environment_<lang>`** performs the full merge once per render (host copy + plain_modules overlay + dependency install + any build artifacts) into `.tmp/<lang>_<arg>/`. The N subsequent `run_conformance_tests_<lang>` invocations attach to this populated folder (activate-only variant — see the shared testing-script rules)
- **`run_unittests_<lang>`** performs its **own** merge into its **own** `.tmp/<lang>_<arg>/` working folder — it does not share `prepare`'s folder, and it does not depend on `prepare` having run. The host copy + overlay + install steps are duplicated inside the unit-test script for self-containedness
- **`run_conformance_tests_<lang>`** does **not** re-merge. It `cd`s into the working folder that `prepare_environment` populated and runs the conformance command against the merged tree

### Language-specific merge primitives

| Language | Host copy | Overlay | Dependency install | Test invocation (inside merged tree) |
|----------|-----------|---------|--------------------|--------------------------------------|
| Python | `rsync -a <host>/ .tmp/python_<arg>/` | `rsync -a plain_modules/<module>/ .tmp/python_<arg>/<host_pkg_path>/` | `cd .tmp/python_<arg> && pip install -e .` (then integration extras) | `cd .tmp/python_<arg> && pytest …` |
| Node.js | `rsync -a <host>/ .tmp/node_<arg>/` | `rsync -a plain_modules/<module>/ .tmp/node_<arg>/<host_pkg_path>/` | `cd .tmp/node_<arg> && npm ci` (then integration extras) | `cd .tmp/node_<arg> && npm test …` |
| Go | `rsync -a <host>/ .tmp/go_<arg>/` | `rsync -a plain_modules/<module>/ .tmp/go_<arg>/<host_pkg_path>/` | `cd .tmp/go_<arg> && go mod tidy` | `cd .tmp/go_<arg> && go test ./…` |
| Java / Kotlin | `rsync -a <host>/ .tmp/java_<arg>/` | `rsync -a plain_modules/<module>/ .tmp/java_<arg>/<host_pkg_path>/` | `cd .tmp/java_<arg> && mvn -q -DskipTests install` | `cd .tmp/java_<arg> && mvn test …` |
| Rust | `rsync -a <host>/ .tmp/rust_<arg>/` | `rsync -a plain_modules/<module>/ .tmp/rust_<arg>/<host_pkg_path>/` | `cd .tmp/rust_<arg> && cargo fetch` | `cd .tmp/rust_<arg> && cargo test …` |

Adjust the language-specific install / test commands to whatever the host's manifest actually uses (Poetry instead of pip, pnpm instead of npm, Gradle instead of Maven, …). The merge primitive itself does not change.

### Invariants the scripts must enforce

- **Host root is a parameter, not a literal.** No script may hardcode an absolute host path. Read the host root from an env var (e.g. `HOST_CODEBASE_ROOT`) with a sensible default matching the user's layout (e.g. `../host_project`). Surface the env var in each script's `--help` / usage banner. Capture this env var in the integration's configuration concept so it has exactly one declared name across specs, scripts, and runtime
- **Target package path is read from the `host-codebase` concept** — never inferred from a heuristic. The renderer writes that path into the generated module's location too, so the overlay destination is unambiguous
- **The host source tree is read-only.** The merge writes into `.tmp/<lang>_<arg>/`; the user's `<host>` checkout is never modified. If a script appears to need to write into `<host>`, it is buggy — the working copy under `.tmp/` is what's mutable
- **Each merge is idempotent.** Re-running the script (or two scripts back-to-back) yields the same merged tree
- **No new `config.yaml` key is needed** — the merge happens inside the scripts. The renderer reads the `host-codebase` concept (for the package path) and the configuration concept (for `HOST_CODEBASE_ROOT`) to wire the script bodies correctly
- **`***test reqs***` must document the merge contract** — name the merge primitive (`rsync` / `cp -R` / `robocopy`), the env var the host root is read from, the target package path inside the host where `plain_modules/<module>/` is overlaid, and the language-appropriate install + test commands. The renderer reads this req and emits the right script bodies

## Embedded-specific completion checklist

Before declaring an embedded integration done, in addition to the shared checklist in [`integrations.md`](integrations.md):

- [ ] `host-codebase` concept records host root path, host language + version, host dependency manager + manifest, target package path, host base class import path, target generated-class FQN, and the host conventions the contract follows
- [ ] Contract spec carries renderer directives (target language, target file path, target class name, host base class to subclass, host-package pins) and **links** to the contract schema; no class body is inlined
- [ ] Every host symbol referenced in any spec uses its fully qualified import path and is tagged "imported from the host codebase; do not redefine"
- [ ] Every host file the integration touches is linked at its **original host-relative path** — no host file has been copied into `resources/host/` or anywhere else, and no host file contents are inlined in any spec
- [ ] `forge-plain` Phase 2's tech-stack decisions are transcribed verbatim from the host (no independent stack choices)
- [ ] Host-package version pins are copied into `***implementation reqs***`
- [ ] `prepare_environment` copies the host into `.tmp/<lang>_<arg>/`, overlays `plain_modules/<module>/` at the target package path, installs the merged tree's dependencies, and is the working folder conformance attaches to
- [ ] `run_unittests` runs the same host-copy + overlay + install sequence into its **own** `.tmp/<lang>_<arg>/` and invokes the test runner from inside the merged tree
- [ ] `run_conformance_tests` `cd`s into `prepare_environment`'s populated working folder and runs the conformance command from there — it does not re-merge and does not use import-path stitching
- [ ] Host codebase root is read from a named env var (default value documented in each script's usage) — never hardcoded
- [ ] Target package path (where `plain_modules/<module>/` is overlaid inside the host copy) is read from the `host-codebase` concept — never inferred
- [ ] The host source tree itself is never written to — every script mutation lands in `.tmp/<lang>_<arg>/`
- [ ] A `***test reqs***` entry documents the merge contract (primitive used, env var name, target package path inside the host, install + test commands)

## Anti-patterns specific to embedded integrations

- **Choosing a different language, framework, or dependency manager than the host.** The host stack is inherited; cross-stack `requires` chains are forbidden by [`requires-modules.md`](requires-modules.md)
- **Redefining a host class under `plain_modules/`.** Reference the host symbol by FQN; let the renderer import it
- **Inlining a host base class body into the contract spec.** Reference the host file as a linked resource **at its original host-relative path** — do not inline its contents and do not copy it into `resources/`
- **Copying host source files into `resources/host/` (or anywhere under `resources/`).** That creates a second source of truth that silently drifts from the host. Link the host file in place; the integration `.plain` module already lives inside the host codebase, so the path resolves naturally
- **Hardcoding the host codebase path in any spec or script.** Read it from the env var declared in the configuration concept
- **Asking the user to design the integration's tech stack.** Read it from the host's manifest files
- **Authoring an integration spec that contradicts an existing integration in the same host** without first surfacing the conflict and getting explicit user confirmation
- **Wiring tests with `PYTHONPATH` / `NODE_PATH` / Go `replace` directives instead of physically merging `plain_modules/<module>/` into a host copy.** The import-stitching approach is forbidden — every embedded test run starts by overlaying the generated module onto a working copy of the host tree
- **Writing into the user's `<host>` checkout from any test script.** The host source is read-only; the merged tree lives in `.tmp/<lang>_<arg>/`
- **Sharing one `.tmp/` working folder between `run_unittests` and `run_conformance_tests`.** Each script stages its own copy; only `run_conformance_tests` attaches to the folder `prepare_environment` populated
