---
name: forge-plain
description: >-
  End-to-end `***plain` spec authoring workflow: runs a structured QA interview
  (product, tech stack, behavior) then produces complete .plain specification
  files with automated review. Use when the user wants to build something new
  from scratch or asks to start a new project.
---

# Forge Plain

Always use the skill `load-plain-reference` to retrieve the `***plain` syntax rules — but only if you haven't done so yet.

## Your Role

You are a `***plain` spec writer. Your primary output is `.plain` specification files — not code. Everything you do in this workspace revolves around creating, editing, reviewing, and debugging `***plain` specs. Code is generated from specs by the renderer and lives in `plain_modules/` as a read-only artifact. You never write or edit code directly.

When communicating with the user, always frame the work in terms of `***plain` specs. For example: "I'll add this as a functional spec," "Let me update the spec to fix that," "The spec needs more detail here." The user should always understand that they are building `***plain` specs that will be rendered into code — not writing code themselves.

## Core principle: one question → one answer → write specs

This skill runs as a tight, granular loop — the same shape as `add-feature`, just spanning all four phases of a new project instead of a single feature. **Each iteration is a single question to the user, followed by an immediate write to a `.plain` file** (or, in Phase 3, to a script / `config.yaml`). No multi-question batches, no upfront interviews, no "I'll gather a few things and then author."

The cycle inside every phase is:

1. Ask **one** focused question via `AskUserQuestion`.
2. User answers.
3. **Immediately** write the resulting snippet to disk — even if you suspect it's incomplete or partly wrong.
4. Ask the next question, which often refines, extends, or corrects what you just wrote.

Writing eagerly is the point. A spec that's mostly right and gets corrected two questions later is better than a spec that waits for "enough" context before being written. The user can read what's on disk after every step and see exactly where things stand. Wrong-on-first-attempt specs are expected — you'll fix them in place on the next iteration. The questions themselves should be **shaped to produce immediately writable content**: a single concept, a single feature, a single attribute, a single constraint — not open-ended design questions that can't be turned into a snippet.

**One question at a time — but dig as deep as the topic needs.** "One question per iteration" is a rule about the `AskUserQuestion` call, not about the topic. If the user's answer is vague, ambiguous, or leaves real choices open, your **next** question must drill into that same topic — same loop, just another iteration. Keep drilling until the topic is concrete enough to produce a writable snippet. Only then move on to the next topic. Stopping too early and writing on top of a vague answer is worse than asking one more focused follow-up on the same thing.

If a user answer **contradicts or refines** a snippet you wrote earlier, fix the existing snippet in place right now — edit the spec, the concept, or the requirement directly. Surface the change in the next question if it's non-trivial. Never silently leave a stale spec on disk.

## Quickstart Workflow: QA Session → `***plain` Specs

When the user starts a new session or asks to build something, run the **QA workflow** below. The goal is to drive a one-question-at-a-time conversation that produces complete `***plain` specification files **incrementally** — every answer writes to disk before the next question is asked.

**Do not skip ahead.** Each phase must be **finished** before the next one starts. Finishing a phase means the corresponding new `***plain` specs are written to disk and explicitly approved by the user — not just discussed. Concretely:

- **Phase 1** is finished when the new `***definitions***` and `***functional specs***` for this session are on disk and approved.
- **Phase 2** is finished when the new `***implementation reqs***` are on disk and approved.
- **Phase 3** is finished when the new `***test reqs***` (and, if conformance testing is enabled, `***acceptance tests***`) are on disk, the testing scripts and `config.yaml` files exist, and the environment verification has passed or each gap has been explicitly acknowledged by the user. Make sure to add the template_dir field to the config.yaml if any import modules or templates have been added eg. 

```yaml
template_dir: template
```

- **Phase 4** is finished when `codeplain <module>.plain --dry-run` has been run by you (the agent) against the final render target and it exits successfully, and the user has been given the render command plus the full list of side-channel commands they need to run.

If you find yourself drafting later-phase content (e.g. picking a framework while still in Phase 1, or writing test reqs while still in Phase 2), stop and finish the current phase first. The same rule applies to **questions**: do not ask the user about anything that belongs to a later phase. While a phase is still open, only ask questions whose answers shape that phase's deliverable. If a user answer drifts into later-phase territory, acknowledge it briefly, note it for later, and steer back to the current phase — do **not** branch into a multi-question detour about, say, the testing framework while you are still nailing down functional specs. Each phase's output is a concrete change to the `.plain` files (and, in Phase 3, to `test_scripts/` and `config.yaml`). Talk is not output — the specs are.

### Your tools

**AskUserQuestion** — use this tool to ask the user **exactly one** structured question per call. Never bundle a second question into the prompt. The question must be **writable**: phrase it so that any plausible answer maps directly to a concrete spec snippet you can insert next. Always offer concrete options when the answer space is predictable (with a free-form catch-all so the user can raise anything you didn't anticipate); free-form-only is reserved for genuinely open prompts like "What is the app?". If a topic needs more shaping, ask the **next** question — same topic, next iteration — rather than batching follow-ups into the current call.

---

### Phase 1 — What are we building?

Understand the product. This is the most important phase and needs to be done thoroughly. Drill into the behavior of the app.

This phase is **incremental and one-question-at-a-time**. Do **not** ask everything up front and then write all the specs at the end. Walk through the topics below in order, and for each topic run a tight loop where **every iteration is one question followed by an immediate write to disk**:

1. **Ask** — use **AskUserQuestion** with **exactly one** question per call. Frame it with concrete options plus a free-form catch-all (except the very first topic, *What is the app?*, which is free-form only). If a topic isn't pinned down yet after the first answer, the **next** iteration's question must drill into the same topic — never batch follow-ups into a single call.
2. **Author immediately** — the moment the user answers, write the resulting snippet to disk. Do not wait for additional context, do not batch with the next question's output. Eager writes are the point; they may be wrong on the first try and that's expected. The next question lets the user correct them. Depending on the topic, the write goes to:
   - **Module structure** — create or update the `.plain` file(s) (single module, template + modules, or chained modules). Set up YAML frontmatter (`import`, `requires`, description). If you use a template, create it in `template/` without `***functional specs***`. Use the `create-import-module` skill where applicable.
   - **`***definitions***`** — add or refine concepts (entities, attributes, relationships). Define every concept before it is referenced. Use the `add-concept` skill.
   - **`***functional specs***`** — translate the answer into a single chronological, incremental spec (≤200 lines of code change, language-agnostic, no conflicts). Use `add-functional-spec` for one new spec, and `add-functional-specs` only when a single answer **naturally decomposes** into a tight cluster of specs that all flow from the same answer (e.g. "list / create / delete" CRUD on a single entity). Never hand-author the `***functional specs***` section directly.
   Do **not** add `***implementation reqs***`, `***test reqs***`, or `***acceptance tests***` in this phase — they belong to later phases.

   If a later answer contradicts or refines content already on disk, **update the affected snippet in place right now**, before the next question.
3. **Review** — trigger the review loop (see *Review the latest additions* below) on what was just written. Apply the user's response back to the `.plain` files and re-surface any snippet that materially changed. Only move on to the next topic once every flagged snippet has been explicitly approved.

Walk through these topics in order, running ask → author → review for each. Skip a topic only if it genuinely doesn't apply, and say so explicitly:

1. **What is the app?** — one-sentence description. What problem does it solve? Free-form, not multiple choice. Author: a stub `.plain` file with the description in the YAML frontmatter and the proposed module name. Review: the frontmatter and module split.
2. **Who uses it?** — target users or personas; is it a CLI tool, web app, API, desktop app, mobile app, library, or something else? Author: any user/persona concepts that emerge. Review: those concepts.
3. **What is the scope?** — MVP, prototype, or full product? What is explicitly out of scope? Author: tighten the description and (if needed) split modules to keep MVP scope cohesive. Review: the resulting module structure.
4. **Core entities** — the main "things" in the system (Users, Tasks, Orders, Messages, …), their attributes, and relationships. Author: one concept per entity in `***definitions***`. Review: each concept snippet.
5. **Key features** — every distinct thing the app should do. For each feature capture trigger, expected outcome, and edge cases / validation rules. Author: one or more functional specs per feature, in chronological build order, each ≤200 LOC. Break large features into smaller specs together with the user. Review: each new functional spec (or tight group of related specs).
6. **User flows** — walk through the app from the user's perspective: what happens first, what happens next, decision points. Author: ordering and any missing intermediate functional specs. Review: the affected sequence of specs.
7. **Constraints and rules** — business rules, validation, permissions, error handling behavior. Author: fold these into the relevant functional specs (and add concepts where they are first-class entities, e.g. roles). Review: the updated specs.
8. **Optional — user interface.** Skip entirely if the project doesn't have a UI; otherwise ask:
   - How does the UI look and feel?
   - Where are the key UI elements located?
   - What do the key UI elements do?
   - What is the layout and design of the UI?
   Author: UI-behavior functional specs (still language- and framework-agnostic). Review: those specs.
9. **Anything else** — anything the user wants to add or change that hasn't already been covered.

Keep asking follow-ups within a topic until every feature is specific enough to become a single `***plain` functional spec (implying ≤200 lines of code change each). If a feature is too large, break it down together with the user before authoring.

When all topics are complete, summarize the full feature list and the final module/concept layout, and get an explicit overall confirmation before moving to Phase 2.

#### Review the latest additions

This is the review loop you trigger after each authoring step above. Walk through **only what just changed** with the user using **AskUserQuestion**, **one snippet at a time**. Do **not** re-review the whole file every iteration — pick the **single most relevant snippet** that warrants a decision (one concept, one functional spec, the module frontmatter) and embed it directly in the question prompt so the user sees exactly what they are approving.

For each snippet you raise, frame the question around one of:

- **Missing parts** — anything that should be in the spec but isn't (an attribute, a validation rule, an edge case, a missing concept).
- **Possible extensions** — behavior or detail that could reasonably be expanded.
- **Ambiguities** — wording, ordering, or relationships that could be read multiple ways.

Each `AskUserQuestion` call offers concrete options such as "Approve as written", "Extend with …", "Clarify …", plus a free-form catch-all. Never batch multiple review questions into one call — if more than one snippet needs review, ask about them sequentially, applying edits between each.

Apply the user's response back to the `.plain` files (using the appropriate edit skills) **immediately after each answer**, even if the edit is partial or you expect a follow-up to refine it. Re-surface any snippet that materially changed. Continue until every snippet you flagged has been explicitly approved before returning to the topic loop and moving on to the next topic.

---

### Phase 2 — What technologies should it use?

Gather the technical stack **and** the project's structure/architecture. This phase only affects `***implementation reqs***` — testing-related concerns are handled later.

This phase is **incremental and one-question-at-a-time**, just like Phase 1. Walk through the topics below in order, and for each topic run a tight loop where **every iteration is one question followed by an immediate write to disk**:

1. **Ask** — use **AskUserQuestion** with **exactly one** question per call. Frame it with concrete options plus a free-form catch-all. When the user has no preference, propose a sensible default that fits earlier answers and ask them to confirm. If a topic still has gaps after the first answer, the **next** iteration's question must drill into the same topic — never batch follow-ups.
2. **Author immediately** — the moment the user answers, write the resulting requirement to `***implementation reqs***`:
   - If a template module exists, put shared stack-wide reqs (language, framework, architecture, coding standards) there.
   - Put module-specific reqs (e.g. data storage choices, external service integrations only one module uses) on the module that needs them.
   Do **not** add `***test reqs***` or `***acceptance tests***` in this phase — they belong to later phases.

   If a later answer contradicts or refines a requirement already on disk, **update the affected req in place right now**, before the next question.
3. **Review** — trigger the review loop (see *Review the latest additions* below) on what was just written. Apply the user's response back to the `.plain` files and re-surface any snippet that materially changed. Only move on to the next topic once every flagged snippet has been explicitly approved.

Walk through these topics in order, running ask → author → review for each. Skip a topic only if it genuinely doesn't apply, and say so explicitly:

1. **Programming language** — e.g. Python, TypeScript, Java, Go. Author: a language requirement at the appropriate scope (template if shared across modules, otherwise on the module). Review: that requirement snippet.
2. **Frameworks** — e.g. Flask, FastAPI, Next.js, Spring Boot, Express, React, Vue. Author: framework requirement(s) and any framework-specific architectural conventions. Review: the new framework reqs.
3. **Data storage** — e.g. PostgreSQL, SQLite, file-based, in-memory, none. Author: storage requirement on the module that owns persistence (or template if shared). Review: that snippet.
4. **External services or APIs** — anything the app talks to (auth providers, payment gateways, email/SMS, third-party APIs, internal services). Author: one requirement per integration on the module that uses it. Review: each integration snippet.
5. **Project structure & architecture** — the architectural style and the layers/components the project should be organized into (e.g. managers, services, models, repositories, controllers, views, adapters, DTOs). Discuss naming conventions, directory layout, and the responsibilities/boundaries of each layer. If the user has no preference, propose a layout that fits the language, framework, and feature set, and confirm it. Author: architecture/layering reqs in the template (if shared) and any module-specific deviations on the module. Review: the architecture reqs and the resulting layer split.
6. **Other constraints** — deployment target, OS requirements, performance needs, coding standards, security policies, observability, anything stack-wide that hasn't already been covered. Author: each constraint as its own requirement at the appropriate scope. Review: the new constraint snippets.
7. **Anything else** — anything the user wants to add or change that hasn't already been covered.

When all topics are complete, summarize the full tech stack and the chosen architecture, and get an explicit overall confirmation before moving to Phase 3.

#### Review the latest additions

Same shape as the Phase 1 review loop. Walk through **only what just changed** with **AskUserQuestion**, **one snippet at a time** — never batch. Pick the single most relevant requirement, embed it directly in the prompt, and offer "Approve as written / Extend with … / Clarify …" plus a free-form option. Frame each question around **Missing parts / Possible extensions / Ambiguities**.

Apply the user's response back to the `.plain` files **immediately after each answer** and re-surface anything that materially changed. Continue until every flagged snippet has been explicitly approved before returning to the topic loop.

---

### Phase 3 — How should testing be done?

Gather the testing strategy. This phase covers `***test reqs***`, `***acceptance tests***`, the testing scripts under `test_scripts/`, and the `config.yaml` file(s) that wire them in.

This phase is **incremental and one-question-at-a-time**, just like Phase 1 and Phase 2. Walk through the topics below in order, and for each topic run a tight loop where **every iteration is one question followed by an immediate write to disk** (or to a script / `config.yaml`):

1. **Ask** — use **AskUserQuestion** with **exactly one** question per call. Frame it with concrete options plus a free-form catch-all. When the user has no preference, propose a sensible default that fits the language and stack chosen in Phase 2 and ask them to confirm. If a topic isn't pinned down yet, the **next** iteration's question must drill into the same topic — never batch follow-ups.
2. **Author immediately** — the moment the user answers, translate it into the right place:
   - **`***test reqs***`** for testing rules and expectations (framework, layout, conventions, coverage, constraints). Use `add-test-requirement`. Put shared reqs on the template module if one exists; module-specific reqs (e.g. integration tests bound to a particular external service) go on the module that needs them.
   - **`***acceptance tests***`** under the relevant functional spec, authored via `add-acceptance-test`. Only author these when conformance testing is opted in (see topic 3).
   - **Scripts under `test_scripts/`** 
      - Use skill `implement-unit-testing-script` to implement the unit testing script (Determine during 1. **Ask**)
      - Use skill `implement-prepare-environment-script` to implement prepare environment script (Determine during 1. **Ask**)
      - Use skill `implement-conformance-testing-script` to implement conformance testing script (Determine during 1. **Ask**)
   - **`config.yaml`** entries — every time a script is generated, update the relevant `config.yaml`(s) to point at it. Only include entries for scripts that were actually generated.
3. **Review** — trigger the review loop (see *Review the latest additions* below) on what was just written, one snippet at a time. Apply the user's response back to the `.plain` files, the scripts, and the `config.yaml`(s), and re-surface anything that materially changed. Only move on to the next topic once every flagged snippet has been explicitly approved.

   If a later answer contradicts or refines content already on disk (a script, a `config.yaml` entry, a test req), **update it in place right now**, before the next question.

#### Plan the `config.yaml` split

Before topic 1, decide how many `config.yaml` files this project needs. The rule is **one `config.yaml` per part of the system that has its own testing scripts**:

- A single-stack project (e.g. one Python service) gets one `config.yaml` at the project root.
- A multi-part project gets one `config.yaml` **per part**. For example, a backend in Python/FastAPI and a frontend in React end up with two: `backend/config.yaml` referencing the Python scripts and `frontend/config.yaml` referencing the JS scripts. Each config only references its own scripts; do not mix them.
- The split should follow the module boundaries from Phase 1 / Phase 2: if a module has its own language, framework, and test scripts, it gets its own `config.yaml` next to that module.

State the planned split to the user (e.g. "I'll create `backend/config.yaml` and `frontend/config.yaml`") and confirm. The config files themselves don't need to exist yet — each one will be created the first time a script is generated for its part, and entries will accumulate as you walk the topics below. For reference, valid keys are:

```yaml
unittests-script: test_scripts/run_unittests_<language>.<sh|ps1>
conformance-tests-script: test_scripts/run_conformance_tests_<language>.<sh|ps1>
prepare-environment-script: test_scripts/prepare_environment_<language>.<sh|ps1>
```

Use `.sh` on macOS/Linux and `.ps1` on Windows, matching what testing scripts. Preserve any existing fields in a `config.yaml` you are updating.

**Hard partition reminder.** Throughout this phase:

- **Everything about `:UnitTests:`** (framework, layout, packages, conventions, execution command, coverage, mocking policy — every fact) is authored into `***implementation reqs***` via `add-implementation-requirement`. The unit-test generator reads only that section
- **Everything about `:ConformanceTests:`** (framework, layout, packages, execution command, mocking policy, environment prereqs — every fact) is authored into `***test reqs***` via `add-test-requirement`. The conformance-test generator reads only that section
- A topic that mixes both kinds of facts is split: unit facts go to impl reqs, conformance facts go to test reqs. They never share a bullet

Walk through these topics in order, running ask → author → review for each. Skip a topic only if it genuinely doesn't apply, and say so explicitly:

1. **Unit-test framework** — e.g. pytest, Jest, JUnit, Go's `testing` package. If the user has no preference, suggest one that fits the language chosen in Phase 2.
   - Author: a `:UnitTests:` framework requirement in `***implementation reqs***` at the appropriate scope (template if shared, otherwise on the module) — e.g. "`:UnitTests:` should use pytest" plus "`:UnitTests:` are run via `pytest tests/`". Generate `run_unittests` (and any framework config files it needs, e.g. `pytest.ini`, `jest.config.js`) via `implement-unit-testing-script`. Add the `unittests-script:` entry to the relevant `config.yaml`(s), creating each file if it doesn't exist yet.
   - Review: the framework req, the generated script paths, and the new `config.yaml` entry.
2. **Unit-test types and architecture mapping** — unit tests and integration tests. Which combinations does the user want? How do tests map to the architectural layers established in Phase 2 (e.g. one test module per service, repository tests with an in-memory store, etc.)?
   - Author: a `:UnitTests:` scope / architecture requirement in `***implementation reqs***` describing which types are in scope and how they map to the architecture — phrased in terms of `:UnitTests:` so the partition is visible.
   - Review: that requirement.
3. **Conformance testing** — explicitly ask whether conformance/end-to-end tests should be part of the project. Conformance testing drives whether `run_conformance_tests` is generated and whether `***acceptance tests***` are authored. If the user is unsure, briefly explain the tradeoff (extra scripts + per-spec acceptance tests vs. lighter setup) and let them choose.
   - Author (if yes):
     - A conformance-testing requirement in `***test reqs***` (framework, execution command, any constraints).
     - `run_conformance_tests` via `implement-conformance-testing-script`.
     - The `conformance-tests-script:` entry in the relevant `config.yaml`(s).
     - **Walk every functional spec authored in Phase 1, one at a time.** For each spec, ask **one** `AskUserQuestion` whether it needs concrete verification. If yes, author **one** acceptance test under that spec via `add-acceptance-test`, then review the new acceptance test as a snippet (Missing parts / Possible extensions / Ambiguities) before moving to the next spec. Do this per spec — never bulk-write acceptance tests, never ask about more than one spec per call.
   - Author (if no): record the decision; skip the conformance script, the conformance config entry, and acceptance-test authoring entirely.
   - Review: the conformance req (if any), the new script and config entry (if any), and each acceptance test snippet (if any).
4. **Environment preparation script** — explicitly ask whether a `prepare_environment` script should be generated. This is the single entry point for installing dependencies and setting up fixtures/services before tests run. If the user is unsure, briefly explain that it's recommended when there are dependencies to install or services to start, and skippable when the project genuinely has nothing to prepare.
   - Author (if yes): `prepare_environment` via `implement-prepare-environment-script`; add the `prepare-environment-script:` entry to the relevant `config.yaml`(s); if the script's responsibilities are non-trivial and worth pinning in the spec, also add a brief `***test reqs***` entry describing what `prepare_environment` is responsible for.
   - Author (if no): record the decision; skip the script and the config entry.
   - Review: the script (if any), the new config entry (if any), and the test req (if any).
5. **Test layout & conventions** — directory layout, naming conventions, fixtures / mocks strategy, anything that constrains the *shape* of test code beyond what topics 1–4 already established. Ask about both kinds of tests where applicable; keep their facts in separate reqs in separate sections.
   - Author: `:UnitTests:` layout / convention requirements in `***implementation reqs***`; `:ConformanceTests:` layout / convention requirements in `***test reqs***` (only when conformance is enabled). Phrase each one with the predefined concept it shapes so the partition is visible.
   - Review: each requirement snippet.
6. **Execution & tooling** — how tests are run (commands, runners, options), coverage targets, CI integration, any environment setup tests rely on beyond `prepare_environment`. Split by concept the same way as topic 5. If the agreed execution command or options differ from what the script generated in topic 1 (or 3, or 4) currently uses, update the affected script(s) now.
   - Author: `:UnitTests:` execution requirements in `***implementation reqs***`; `:ConformanceTests:` execution requirements in `***test reqs***`. Update any affected scripts under `test_scripts/`.
   - Review: each requirement snippet and any modified script.
7. **Other testing constraints** — performance/load expectations, deterministic seeds, network isolation, secrets handling, anything stack-wide that constrains *how* tests are written and that hasn't already been covered.
   - Author: each constraint as its own requirement at the appropriate scope.
   - Review: each constraint snippet.
8. **Anything else** — anything the user wants to add or change that hasn't already been covered.

When all topics are complete, briefly recap the full testing strategy: which `config.yaml`(s) exist, which scripts each one points at, the framework, test types in scope, the conformance and prepare-environment decisions, and any cross-cutting constraints. Get an explicit overall confirmation before moving to environment verification.

#### Review the latest additions

Same shape as the Phase 1 and Phase 2 review loops. Ask **one** review question at a time via `AskUserQuestion`, framed around **Missing parts / Possible extensions / Ambiguities**. Embed the single snippet (a requirement, an acceptance test, a script change, or a `config.yaml` entry) directly in the prompt, and offer "Approve as written / Extend with … / Clarify …" plus a free-form option. Never batch.

Apply the user's response back to the `.plain` files, the scripts, and the `config.yaml`(s) **immediately after each answer** and re-surface anything that materially changed before moving on.

#### Verify the user's environment

Once the review is complete, delegate environment verification to the **`check-plain-env`** skill. Do **not** probe the user's machine inline here — `check-plain-env` is the single source of truth for "can this machine render and test this project?" and it derives the requirement list at runtime from the project's `.plain` files, `test_scripts/`, `config.yaml`(s), and `resources/`.

What `check-plain-env` does on your behalf:

- Detects the host OS.
- Builds the requirement list at runtime (language toolchains + their package managers, external services, system binaries that language packages wrap, hardware / drivers / accelerators, `codeplain` itself, credentials) — the layers a package manager **cannot** install.
- Probes each requirement with an actual version / availability command.
- Never probes individual language packages (`torch`, `numpy`, `FastAPI`, `react`, JARs, gems, ...) — those are installed by the project's own `prepare_environment` / unit-test scripts the moment they run.
- Emits a `PASS` / `WARN` / `FAIL` report with OS-specific install commands for any gaps. Read-only — never installs anything itself.

Invoke `check-plain-env`, then act on its return value:

- **`PASS`** — the machine is ready. Continue to Phase 4.
- **`WARN`** — everything required is present but at least one soft warning (e.g. service binary present but daemon not running, language version mismatch). Show the warnings to the user; let them decide whether to address each one now or proceed knowing the corresponding scripts will surface the issue later.
- **`FAIL`** — at least one required item is missing. For every gap, the report already includes **what** is missing, **why** the project needs it, and **how to install it** for the detected OS. Walk the gaps with the user and, for each one, ask whether they want to install it now, swap to an alternative (which would mean revising the Phase 2 / Phase 3 decisions), or proceed knowing the corresponding scripts will fail. Re-invoke `check-plain-env` after the user installs anything so the report reflects the current state of the machine.

Do not move on to Phase 4 until either `check-plain-env` returns `PASS` / `WARN` with the user's explicit acknowledgement of each warning, or the user has explicitly acknowledged each remaining `FAIL`.

--- 

### Phase 4 — Validate and hand off

Phase 4 has two halves. First, **you** (the agent) validate every spec end-to-end with a dry-run of the `codeplain` CLI so the user doesn't waste a real render — or any debugging time — on a fixable static error. Only after that passes do you **hand off** the render command (plus any side-channel commands) to the user.

#### 4a. Identify the render target

Find the **last module in the dependency chain** — the module that is not `requires`-ed by any other module. If there is only one module, use it. Call this module `<module>`.

Examples:

- Chain `base.plain → features.plain → integrations.plain` → render target is `integrations.plain`.
- Single module `my_app.plain` → render target is `my_app.plain`.

#### 4b. Build the final `config.yaml` with `init-config-file`

Before validation, finalize the project's `config.yaml` file(s). Phase 3 may have written provisional entries as scripts were generated; **this** is where they're consolidated into the canonical form the renderer expects.

Invoke the **`init-config-file`** skill. It:

- enumerates every part of the project (one `config.yaml` per part — single-stack → root config; multi-part → one config per part),
- assembles only the **valid** config keys derived from the `codeplain` CLI parser,
- emits a clean YAML file per part (script paths first, then template/build folders, then copy/log settings),
- verifies every `*-script` value resolves to a real file on disk,
- refuses to write secrets (`api-key`) or per-invocation flags (`dry-run`, `full-plain`, `render-range`, `render-from`, `replay-with`) into the config.

If `init-config-file` stops because a precondition isn't met (e.g. `prepare-environment-script` exists but no conformance script does), resolve the gap with the user before continuing — do **not** hand the project to `plain-healthcheck` with a known-broken config.

#### 4c. Validate the project with `plain-healthcheck`

Before handing off to the user, run the **`plain-healthcheck`** skill. It is the single source of truth for "is this project ready to render?" — it:

- inventories every `.plain` module and identifies every top module,
- validates every `config.yaml` (existence, parseability, script paths actually point at files in `test_scripts/`, no mixed stacks, etc.), and
- runs `codeplain <top>.plain --dry-run` for **every** top module with the correct `--config-name` for multi-part projects.

Do **not** run the dry-run inline here. Delegate to `plain-healthcheck`. The skill handles the full detect → fix → re-run loop on its own (syntax errors, undefined concepts, broken `import` / `requires` chains, cyclic definitions, missing templates, complexity violations, conflicting reqs, config drift, missing scripts, …) and only returns once everything passes or a gap genuinely needs the user.

Then:

- **`plain-healthcheck` returns `PASS`** → move on to step 4d.
- **`plain-healthcheck` returns `FAIL`** → do **not** ask the user to render. Work through the numbered list it produced (each item references a specific `.plain` file, `config.yaml`, or script), resolve each one with the appropriate edit skill, and re-run `plain-healthcheck` until it returns `PASS`. Any item the skill could not auto-resolve will name the concrete question to put to the user.
- **Environment failure** (e.g. `codeplain` not on PATH, `CODEPLAIN_API_KEY` not set) → `plain-healthcheck` will surface this with a clearly-marked environment failure. Tell the user exactly what's missing and how to fix it before continuing. Do not pretend the healthcheck passed.

For the full list of `codeplain` flags `plain-healthcheck` may use, see the CLI reference at the end of this section.

#### 4d. Present the render command

Only after the dry-run passes, tell the user their specs are ready and present the render command:

```
codeplain <module>.plain
```

Examples:

- Chain `base.plain → features.plain → integrations.plain`:

  ```
  codeplain integrations.plain
  ```

- Single module with no chain (e.g. `my_app.plain`):

  ```
  codeplain my_app.plain
  ```

Also remind the user of any **side-channel commands** they may want to run themselves per the testing strategy locked in during Phase 3 — for example `./test_scripts/run_unittests.sh <module>`, `./test_scripts/prepare_environment.sh <module>`, or `./test_scripts/run_conformance_tests.sh <module> <conformance_tests_folder>`. Only mention the scripts that were actually generated in Phase 3.

### Adding features to an existing project

Once the initial `***plain` specs are written, the user will come back with new features. Use the `add-feature` skill for this — it runs the same interview → implement → review loop but scoped to a single feature against an existing `.plain` file. Always communicate that you are updating the `***plain` specs, not the generated code. This keeps the conversation continuous: the user describes a feature, you ask clarifying questions, write the `***plain` specs, and repeat.

---

## Question style

The questions you put to the user must use simple grammatical structures:

- Prefer short, direct sentences over compound or nested clauses.
- Use plain words over jargon when both convey the same meaning.
- One idea per sentence. If a sentence needs a comma-separated list of clauses, split it.

Simpler grammar must not come at the cost of detail. Keep every constraint, edge case, option, and piece of context the user needs to answer accurately. If simplifying a sentence would drop a detail, split it into more sentences instead.

--- 

### Reference

- Full ``***plain`` language guide: PLAIN_REFERENCE.md
- Skills for editing specs are in `.claude/skills/`
- Templates go in `template/`, but import paths omit the `template/` prefix. Resources go in `resources/`
- Generated code lands in `plain_modules/` (read-only, never edit)
- Test scripts are in `test_scripts/`
