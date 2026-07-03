---
name: load-plain-reference
description: >-
  Loads the full ***plain language reference into context (PLAIN_REFERENCE.md): syntax, section types
  (definitions, implementation reqs, test reqs, functional specs, acceptance tests),
  concept notation, frontmatter (import/requires/required_concepts/exported_concepts),
  templates, linked resources, module model, and authoring best practices. Use whenever
  authoring, editing, reviewing, or debugging .plain files, or before invoking any other
  skill that reads or writes .plain content.
---

# PLAIN_REFERENCE.md

## Project Overview

\*\*\*plain is a specification-driven language powered by AI that generates production-ready code from `.plain` spec files.

The `.plain` files are the source of truth. They describe what the software should do, how it should be built, and how it should be tested. The generated code is a read-only artifact produced by the renderer.

## ***plain Language Reference

***plain is a specification language designed for writing software requirements in a clear, structured format. It generates production-ready code from `.plain` spec files using AI. Full documentation: https://plainlang.org/docs/language-guide/

### .plain File Structure

A `.plain` file has a YAML frontmatter section followed by standardized sections marked with `***section name***` headers. There are four types of specification sections:

- `***definitions***` — declares concepts used throughout the specification
- `***implementation reqs***` — non-functional requirements about how the software should be built
- `***test reqs***` — requirements for conformance testing
- `***functional specs***` — describes what the software should do

Every plain source file requires at least one functional spec and an associated implementation req. 

### Concept Notation

Concepts are the building blocks of ***plain specifications. They are written between colons: `:ConceptName:`. Valid characters include letters, digits, plus, minus, dot, and underscore.

Concepts must be defined in `***definitions***` before being referenced in other sections. Concept names must be globally unique across the specification and its imports. Concept references must not form cycles — if concept A references concept B, then concept B must not reference concept A.

Example:

```plain
***definitions***

- :User: is the user of :App:

- :Task: describes an activity that needs to be done by :User:. :Task: has:
    - Name - a short description (required)
    - Notes - additional details (optional)
    - Due Date - completion deadline (optional)

- :TaskList: is a list of :Task: items.
    - Initially :TaskList: should be empty.
```

### Predefined Concepts

***plain provides predefined concepts available in all specifications without needing to be defined:

| Concept | Meaning |
|---------|---------|
| `:plainDefinitions:` | Content of the `***definitions***` section |
| `:plainImplementationReqs:` | Content of the `***implementation reqs***` section |
| `:plainFunctionality:` | Content of the `***functional specs***` section |
| `:plainTestReqs:` | Content of the `***test reqs***` section |
| `:Implementation:` | The system implementing `:plainFunctionality:` |
| `:plainImplementationCode:` | The generated implementation code |
| `:UnitTests:` | Auto-generated unit tests for individual functionalities - their usage goes in in the ***implementation reqs*** section |
| `:ConformanceTests:` | Auto-generated tests that verify implementation conforms to specs |
| `:AcceptanceTest:` / `:AcceptanceTests:` | Tests that validate specific aspects of the implementation |

### Definitions Section

Declares concepts used throughout the specification. A concept must be defined before it can be referenced in any section. The definition can come from the module's own `***definitions***` section, from an `import`ed module's definitions, or from a `require`d module's `exported_concepts` (but not transitively). Attributes, constraints and clarifications can be nested as sub-bullets.

```plain
***definitions***

- :ConceptName: is a description of the concept.
    - Additional details or attributes can be nested
    - Multiple attributes can be listed
    - Concept clarification also goes here
```

### Implementation Reqs Section

A free-form section for any instructions that steer code generation. Common uses include technology choices, architectural constraints, coding standards, and naming conventions, but it can also contain detailed implementation guidance — data formats, error handling strategies, algorithm descriptions, or any other context the renderer needs to produce correct code. These describe HOW to build the software, not WHAT it should do. Specs about unit testing also go here - it is a common mistake to include them in the `***test reqs***` section.

```plain
***implementation reqs***

- :Implementation: should be in Python.

- :MainExecutableFile: of :App: should be called "hello_world.py".

- :Implementation: should include :Unittests: using Unittest framework!
```

### Test Reqs Section

Specifies requirements for conformance testing — test frameworks, execution methods, and testing constraints. Only used when writing and fixing conformance tests (not unit tests). Unit tests should be specified in the `***implementation reqs***` section and NOT HERE. 

```plain
***test reqs***

- :ConformanceTests: of :App: should be implemented in Python using Unittest framework.

- :ConformanceTests: will be run using "python -m unittest discover" command.

- :ConformanceTests: must be implemented and executed - do not use unittest.skip().
```

### Functional Specs Section

Describes what the software should do. Each bullet point is a single piece of functionality that will be implemented. Functional specs are rendered incrementally one by one — earlier specs cannot reference later specs.

Each functional spec must be limited in complexity. If a spec is too complex, the renderer responds with "Functional spec too complex!" and it must be broken down into smaller specs. Complexity is measured in lines of code - each spec should imply more than 200 lines of code.

Functional specs are in **chronological order** — earlier specs are rendered before later ones. Functional specs defined in `requires` modules are considered **previous functional specs** relative to the current module's specs. This ordering matters for incremental rendering and for detecting conflicts between specs.

The renderer has **no knowledge of future functional specs**. When a functional spec is being implemented, only the previous functional specs (those already rendered) are in the renderer's context. Specs that come later in the list are invisible to the renderer at that point. This means each spec is implemented without any awareness of what will come next.

```plain
***functional specs***

- Implement the entry point for :App:.

- Show :TaskList:.

- :User: should be able to add :Task:. Only valid :Task: items can be added.

- :User: should be able to delete :Task:.

```

Each functional spec must be unambiguous. If a single line is not enough to fully disambiguate the behavior, use nested sub-bullets to add detail. Nested lines clarify the parent spec — they do not introduce separate functionality. Even with nested detail, the spec must still respect the complexity limit.

```plain
***functional specs***

- :User: should be able to send a :Message: to a :Conversation:.
  - A :Message: must have non-empty content.
  - The :Message: is appended to the end of the :Conversation:.
  - All :Participant: members of the :Conversation: can see the new :Message:.
```

### Acceptance Tests

Nested under individual functional specs to specify how to verify correct implementation. They extend conformance tests and are implemented according to the `***test reqs***` specification. Acceptance tests are only run if conformance tests are enabled.

```plain
***functional specs***

- Display "hello, world"

    ***acceptance tests***
    - :App: should exit with status code 0 indicating successful execution.
    - :App: should complete execution in under 1 second.
```

### YAML Frontmatter

The frontmatter is enclosed between `---` markers and supports:

- **`import`** — includes definitions, implementation reqs, and test reqs from templates. Imported modules must not contain functional specs. The default import directory is `template/` — the `template/` prefix is not needed (e.g., `airplain` resolves to `template/airplain.plain`).
- **`requires`** — specifies dependencies on other root-level modules that must be built first. Unlike `import`, required modules can contain functional specs and represent complete software modules. Requires paths point to root-level modules (e.g., `auth`, `messaging`).
- **`description`** — optional description of the specification.
- **`required_concepts`** — concepts that must be defined by any module that imports this spec.
- **`exported_concepts`** — concepts made available to modules that `require` this one. **Exports are not transitive.** A concept exported from module `A` is visible only to the modules that `requires: A` directly. If module `B` `requires: A` and module `C` `requires: B`, the concepts `A` exports are **not** automatically visible to `C` — only the concepts `B` itself re-exports are. To pass a concept further down the chain, the intermediate module must re-declare it in its own `exported_concepts` list (and define / forward it in its own `***definitions***` as needed). This applies at every hop: each module is responsible for explicitly exporting whatever it wants its own `requires`-ers to see.

    **When a concept needs to live in more than just the immediately next module, don't propagate it by chained re-exports** — that turns every intermediate module into bookkeeping for a concept it doesn't itself use, and any missing hop silently drops the concept from downstream modules. Use a **shared import module** instead:

    1. Create an import module under `template/` (e.g. `template/shared_domain.plain`) and put the concept's `***definitions***` entry there. Import modules carry definitions, implementation reqs, and test reqs only — never functional specs.
    2. In every module that needs the concept (no matter how deep in the `requires` chain), add the import module to its frontmatter `import:` list. The concept is then visible in that module directly, without any `exported_concepts` plumbing.
    3. None of the `requires`-chained modules need to re-export the concept anymore — each one imports what it actually uses.

    Use the `create-import-module` skill to scaffold this, and `consolidate-concepts` when you discover the same concept has been scattered across several modules and needs to be pulled back into a single shared import.

    Rule of thumb: if a concept crosses **one** hop, `exported_concepts` is fine. If it crosses **two or more** hops, or is needed by sibling modules at the same depth, lift it into an import module.

### Linked Resources

Specifications can reference external files using markdown link syntax. The linked resource is passed along with the spec to the renderer. File paths are resolved relative to the `.plain` file location. Only files in the same folder (and subfolders) are supported.

```plain
- :User: should be able to add :Task:.
  - The user-interface details are in [task_modal_specification.yaml](task_modal_specification.yaml).
```

#### Hard constraint: a linked resource is always a single, text-based file on disk

The renderer reads the linked file's bytes verbatim and feeds them into the model alongside the spec. That mechanism only works for a specific shape of target, and violating any of the three rules below is one of the most common and disruptive mistakes in `.plain` authoring — the spec **looks** valid, but the renderer either silently ignores the link, fails to read it, or wastes the model's context window on bytes it cannot interpret.

A linked resource **must not** be any of the following:

1. **A folder / directory.** `[integrations](src/integrations/)`, `[schemas](resources/schemas/)`, `[host project](../host_project/)` are all invalid — the renderer cannot ingest a directory. If a whole directory's worth of content is relevant, pick the single most representative **file** inside it (a `README.md`, an exemplar source file, a manifest at the directory root) and link **that**.
2. **A URL / external location.** `[Stripe docs](https://stripe.com/docs/api)`, any `http://` / `https://` / `ftp://` / `git://` / `s3://` / `gs://` target. Linked resources are local-file only. If a URL's content is essential to the spec, fetch it once, save the response to a text file under `resources/` (e.g. `resources/stripe-docs-snapshot.md`, `resources/example-openapi.yaml`), and link **that file**.
3. **A binary file.** PNG, JPG, JPEG, GIF, BMP, TIFF, WebP, ICO, PDF, DOCX, XLSX, PPTX, ZIP, TAR, GZ, MP3, MP4, WAV, compiled binaries (`.exe`, `.so`, `.dylib`, `.class`, `.wasm`), and anything else that isn't human-readable text in its raw form. Binary content cannot be meaningfully consumed by the renderer; linking a screenshot, a PDF spec, or a packaged artifact accomplishes nothing except bloating the context. If the information in a binary asset is essential, transcribe it into a text-based form first — a UI screenshot becomes a Markdown description or a structured YAML wireframe under `resources/`; a PDF spec becomes a Markdown extract or the underlying JSON Schema / OpenAPI; an architecture diagram becomes a Mermaid block inside a Markdown file.

If the markdown-link target ends with `/`, contains `://`, points at a path that resolves to a directory, or points at a file with one of the binary extensions above, **stop** — it cannot be a linked resource. Convert it to a text file under `resources/` first, then link the converted file.

#### URLs and folder paths must not appear *anywhere* in `.plain` content

The constraint above is **not** just about markdown link syntax. URLs (any `http://`, `https://`, `ftp://`, `git://`, `s3://`, … string) and folder paths (`src/integrations/`, `../host_project/`, anything ending with `/`, anything that resolves to a directory) **must not appear anywhere in `.plain` content** — not as link targets, not in concept body prose, not in functional-spec text, not in implementation reqs, not in test reqs. Mentioning a URL or a folder in prose is a critical and common mistake because:

- **The renderer cannot follow URLs or open folders.** A URL or folder reference in prose is a *ghost* dependency: it looks meaningful to a human reader, but it contributes nothing to code generation. Worse, downstream readers (and future you) assume the renderer used the referenced content, so the spec silently drifts from reality.
- **The fix is always the same**: if external content matters, fetch it (or pick one canonical file out of the directory), save it as a text file under `resources/`, and refer to it through a normal linked resource. The concept or spec then names the content through the linked file, not through a URL or folder path string.

The **only** exception is for URLs and paths that are *values the produced software itself uses at runtime* — the base URL the integration calls, a database connection path, a CLI argument default. Those are configuration values, not external references, and they belong in the spec because the generated code needs them. A useful litmus test: "Would the renderer benefit from reading the bytes at this URL / folder?" If yes, save it to a text file and link the file. If no (it's a runtime value the generated code carries forward), it can stay as plain text in the spec.

**Structured protocol artifacts must be linked resources, never transcribed into prose.** Anything that has a formal machine-readable shape which includes but is not limited to — JSON Schema, OpenAPI / Swagger specs, GraphQL SDL, Protobuf / gRPC `.proto` files, Avro / Thrift schemas, XML XSDs, AsyncAPI specs, JSON-RPC method definitions, wire-protocol descriptions, payload examples, etc. — belongs in a file under `resources/` (or a subfolder of the `.plain` file's directory), and the spec refers to it via a markdown link. Do **not** restate the schema's fields, types, or constraints inline in functional specs, implementation reqs, or definitions. Reasons:

- **One source of truth.** A re-typed copy of a schema in prose drifts as soon as the real schema evolves. Both the renderer *and* downstream tooling (codegen, validators, API clients, IDE plugins) need the same canonical file.
- **Machine-readable.** The renderer and the generated code can both consume the file directly — a JSON Schema linked from a spec can drive request/response validation in the implementation *and* assertions in conformance tests, with no prose-to-code translation step in between.
- **Reviewable as a diff.** Schema changes show up cleanly in PRs as edits to a single file, instead of as a scatter of edits across multiple `.plain` sections.

The accompanying spec line should describe the *role* of the artifact ("the request body conforms to ...", "the public API surface is defined in ...") rather than its contents. If the artifact is referenced from more than one place, follow the [single-reference + concept](#linked-resources) rule below.

```plain
***definitions***

- :TaskCreateRequest: is the JSON payload for creating a task.
  - It is defined by [resources/task_create_request.schema.json](resources/task_create_request.schema.json).
- :TasksAPI: is the public HTTP surface for tasks.
  - It is defined by [resources/tasks_openapi.yaml](resources/tasks_openapi.yaml).

***functional specs***

- :User: should be able to add :Task: by POSTing :TaskCreateRequest: to the `POST /tasks` endpoint of :TasksAPI:.
  - The endpoint responds per :TasksAPI:.
```

**Each linked resource must be referenced from exactly one place** in the project — a single functional spec, implementation requirement, or `***definitions***` entry. Linking the same file from two functional specs (or from a functional spec *and* a requirement, etc.) creates two independent sources of truth: any later edit to one site silently diverges from the other, and the renderer has no way to know which one is canonical.

If a resource needs to inform multiple parts of the project, **don't repeat the link** — instead, attach the resource to a **concept** and let the rest of the project refer to that concept:

1. Define a concept under `***definitions***` whose explanation links the resource exactly once.
2. Use the concept token (`:ConceptName:`) wherever the resource was previously inlined.

For example, instead of linking `task_modal_specification.yaml` from two different functional specs:

```plain
***definitions***

- :TaskModalSpec: is the user-interface contract for the task modal.
  - It is fully described in [task_modal_specification.yaml](task_modal_specification.yaml).

***functional specs***

- :User: should be able to add :Task: using :TaskModalSpec:.

- :User: should be able to edit :Task: using :TaskModalSpec:.
```

This keeps the resource link in one place, makes the dependency explicit through the concept token, and means a change to the file only ever needs to be reconciled against one spec site. If you find yourself about to paste the same `[name](path)` link a second time, **stop** — create the concept first.

### Template System

***plain supports template inclusion using `{% include %}` syntax:

```plain
{% include "python-console-app-template.plain", main_executable_file_name: "my_app.py" %}
```

Parameters are passed as key-value pairs. Inside the template, they are accessed using variable syntax (`{{ variable_name }}`). Only variables are supported — conditionals, loops, and other Liquid features are not available.

### Comments

Lines starting with `>` are ignored when rendering:

```plain
> This is a comment in ***plain
```

### Best Practices

1. **Reference concepts consistently** — use `:ConceptName:` notation to disambiguate key concepts
2. **Keep it simple** — specs should be readable by both humans and AI
3. **Leverage templates** — use the standard template library for common patterns
4. **Use acceptance tests** — add them for requirements that need verification (under the condition that conformance tests are enabled)
5. **Be specific** — write clear, testable requirements in functional specs
6. **Define before use** — always define concepts in `***definitions***` before referencing them
7. **Start with imports** — import relevant templates before defining your own concepts

## Repository Structure

```
*.plain                  # Specification files (the source of truth)
template/*.plain         # Reusable template specs imported by module specs
plain_modules/           # Generated code output (one folder per .plain spec)
resources/               # Schemas, API specs, transforms, test fixtures
conformance_tests/       # Generated conformance tests (one folder per module)
test_scripts/            # Scripts for running unit and conformance tests
config.yaml              # codeplain CLI configuration
```

**Generated artifacts** (gitignored):
- `plain_modules/<module_name>/` — generated project for each `.plain` spec (implementation + unit tests)
- `conformance_tests/<module_name>/` — generated conformance tests for each module

## How Modules Work

There are two types of modules:

### Import Modules

An import module may live in the **`template/`** directory (other directories are also supported) and contains **only** `***definitions***`, `***implementation reqs***`, and/or optionally `***test reqs***`. It must **not** contain `***functional specs***` and must **not** use `requires`. It may optionally `import` other templates for layered reuse.

When a module **`import`s** another, it gains access to the imported module's definitions, implementation reqs, and test reqs — but not its functional specs. The default import directory needs to be specified in `config.yaml` - in such a case, the directory prefix is not needed (e.g., `airplain`).

### Requires Modules

`requires` establishes a build ordering between modules. The required module is built **before** the current one. This does not necessarily mean the current module extends or depends on the required module's code — it may be completely independent. The `requires` relationship ensures the build order is correct.

When a module **`requires`** another:
- The required module's generated code (`plain_modules/<required_module>`) is copied as the starting point.
- The required module's `***functional specs***` become visible as **previous functional specs** - this property IS transitive.
- Only `exported_concepts` from the required module are available (not its full definitions) - this property IS NOT transitive.

A module can use both `requires` and `import` together.

**`requires` modules must share the same tech stack.** Because the required module's generated code is copied as the starting point and the renderer continues building on top of it with one language/framework toolchain, two modules can only be linked with `requires` when they target the same language, framework, and runtime. A runtime/network dependency between systems is **not** a reason to use `requires`. For example, a React frontend that talks to a Python/FastAPI backend over HTTP must **not** `requires: [backend]` — the stacks differ. Model that pair as two independent root modules (each with its own `config.yaml` and test scripts), and express the contract between them through a shared API schema in `resources/` or shared concepts in an `import`ed template, NOT through `requires`.

### Contracts Between Modules

Modules can use `required_concepts` and `exported_concepts` to enforce contracts between them. An import module declaring `required_concepts` means any module that imports it must define those concepts. A module declaring `exported_concepts` controls which concepts are visible to modules that `require` it - not transitive.

**Exported concepts are not transitive.** If module A exports a concept and module B `requires` A, module B can use that concept — but if module C `requires` B, it does **not** automatically gain access to A's exported concepts. If a concept needs to be shared across multiple `requires` modules, define it in a common import module and have each module `import` that shared template.

## Conformance Test Workflow

Each functional spec in a module has its own set of conformance tests, generated per functional spec per module. After a new functional spec is rendered (i.e., its implementation code is generated), conformance tests for that spec are also rendered. Before proceeding, **all previous conformance tests** (from earlier functional specs in the same module) are run. Ideally, all conformance tests of all previous functional specs pass without any changes. If any previously passing conformance test now fails, the failure must be resolved before moving on. Resolution means one of three things: fixing the conformance test, fixing the implementation code (by adjusting the spec), or identifying conflicting specs.

If conformance tests of a previous functional spec need to be changed in order to pass, this is a strong indicator that the functional specs themselves may need to be amended. Needing to modify earlier conformance tests suggests the new functional spec has introduced behavior that is inconsistent with what was previously specified — the specs should be reviewed and clarified to eliminate the ambiguity or conflict.

## Running Tests

Test scripts live in `test_scripts/` and are run from the repo root:

```bash
# Run all unit tests for a module
./test_scripts/run_unittests.sh plain_modules/<module_name>

# Prepare environment for conformance tests
./test_scripts/prepare_environment.sh plain_modules/<module_name>

# Run conformance tests for a specific functionality in a module
./test_scripts/run_conformance_tests.sh plain_modules/<module_name> conformance_tests/<module_name>/<functionality>
```

## Testing Scripts

Every ***plain project ships shell scripts under `test_scripts/` that the user (and the renderer) call into to verify the generated code. There are three kinds, each authored by a dedicated skill — use the corresponding skill as the source of truth whenever you create, regenerate, or adapt a script.

### Why these scripts exist (and why they're shaped the way they are)

The **primary** purpose of these scripts is **automated execution by the renderer** to validate the generated code and validate that all the previous functionalities work as expected, not manual invocation by a developer. The user *can* run them by hand (see [Running Tests](#running-tests)), but the renderer runs them many times more often — once for every functional spec it processes — as part of its incremental rendering loop. The contract between the scripts and the renderer is shaped by that execution model:

- **Conformance tests are per-functional-spec.** Each functional spec in a module has its own folder under `conformance_tests/<module>/<functionality>/`. After the renderer finishes generating code for a new functional spec and the unit tests and refactoring passes, it runs the conformance tests of **all previous functional spec** to detect regressions — see [Conformance Test Workflow](#conformance-test-workflow). For a single module (with 0 `requires` modules) with N functional specs, the conformance script gets invoked **on the order of N times per render**, each invocation pointing at a different spec's test folder.
- **Each per-spec invocation is independent.** The conformance script does not know that it's the second invocation in a long sequence; from its point of view, each invocation is a cold start against a single spec's tests.
- **Per-spec independence is also what makes dependency installation expensive.** A naive conformance runner would re-install all of the project's runtime dependencies (Python venv + `pip install`, Maven dependency tree, `npm ci`, `cargo build`, ...) on every one of those N invocations. That's `N × install-cost` of wasted work for every render.
- **That is exactly why `prepare_environment_<lang>` exists.** Its **only** job is to amortize the install cost: install once at the start of a render, populate the working folder in the system temp directory (`/tmp/<lang>_<basename-of-build-folder>/` on macOS/Linux, the `GetTempPath()` equivalent on Windows) with the warmed dependency cache and build artifacts, then let the conformance runner **attach** to that working folder on each of the N per-spec invocations instead of re-installing. The conformance runner's [activate-only variant](../implement-conformance-testing-script/SKILL.md#variant-decision-install-inline-vs-activate-only) does precisely that — and it **never deletes** that working folder; prepare owns its lifecycle. When no prepare script exists, the conformance runner falls back to the install-inline variant and pays the install cost N times — acceptable for tiny projects, costly for anything realistic.
- **The unit-test runner has a different execution model, because unit tests live in a different place.** Unit tests are part of the generated codebase itself — they sit directly inside `plain_modules/<module>/` next to the implementation they exercise — whereas conformance tests live *outside* the codebase, in their own per-spec folders under `conformance_tests/<module>/<spec>/`. As a result, the unit-test runner doesn't have a per-spec axis to iterate over: it just runs against the whole `plain_modules/<module>/` build in one go, gets invoked far fewer times per render, and has no amortization gain to chase. That's why the unit-test runner is always self-contained and there is no `prepare_environment`-equivalent for it.

Keep this framing in mind when you author or adapt any of these scripts. The decisions about working-folder paths, isolation locations, exit codes, and the activate-only-vs-install-inline split are not arbitrary house style — they are what makes the renderer's per-spec loop tractable.

### The three scripts

- **`run_unittests_<lang>.sh` / `.ps1`** — runs the auto-generated unit tests in `plain_modules/<module>/`. Authored by the [`implement-unit-testing-script`](../implement-unit-testing-script/SKILL.md) skill. Receives one positional argument: the source build folder name. Invoked roughly once per render. **Fully self-contained:** it installs its own dependencies inline (via `pip install -r requirements.txt`, `npm ci`, `mvn`, `cargo fetch`, etc.) and never relies on any other script having run first.
- **`run_conformance_tests_<lang>.sh` / `.ps1`** — runs the conformance tests in `conformance_tests/<module>/<spec>/` against the generated implementation. Authored by the [`implement-conformance-testing-script`](../implement-conformance-testing-script/SKILL.md) skill. Receives two positional arguments: the source build folder and the conformance tests folder. **Invoked once per previous functional spec on every render** — i.e. roughly N times for a module with N functional specs.
- **`prepare_environment_<lang>.sh` / `.ps1`** — *optional* one-time setup that runs **before** the conformance script and **only the conformance script**. Invoked **once per render** to install the build's dependencies and pre-warm build artifacts into the system-temp working folder (`/tmp/<lang>_<basename>/`) so the N subsequent conformance invocations can attach to the warmed environment instead of re-installing. Authored by the [`implement-prepare-environment-script`](../implement-prepare-environment-script/SKILL.md) skill. Receives one positional argument: the source build folder name. **It does not feed the unit-test script** — see [`prepare_environment` is conformance-only](#prepare_environment-is-conformance-only-common-mistake) below.

### `prepare_environment` is conformance-only (common mistake)

It is a **common and costly mistake** to assume that `prepare_environment_<lang>` is a generic "warm up the environment for all the testing scripts" step that the unit-test runner can also lean on. It is not. The hard rule:

> `prepare_environment_<lang>` exists **solely** to set up the working folder that `run_conformance_tests_<lang>` then attaches to (the activate-only variant). The unit-test runner (`run_unittests_<lang>`) is **completely independent and complete** of it — it does not read from `prepare`'s working folder, does not require `prepare` to have run, and must install whatever dependencies it needs on its own.

Why:

- **Unit tests run against `plain_modules/<module>/`, conformance tests run against the system-temp working folder.** The two scripts stage into different places. `prepare_environment` populates `/tmp/<lang>_<basename>/` for conformance; the unit-test script does its own staging into its **own** system-temp working folder, installs its own dependencies there, and removes that folder when it exits.
- **The unit-test runner must work in isolation.** Users and CI systems run unit tests as a quick smoke check without ever invoking conformance. If `run_unittests_<lang>` depended on `prepare_environment` having run, those one-off unit-test invocations would silently fail (or be "fixed" by a misguided edit to make it depend on `prepare`).
- **The skill contract enforces it.** [`implement-unit-testing-script`](../implement-unit-testing-script/SKILL.md) emits a fully self-contained script every time: toolchain check → stage → install dependencies inline → run tests. It never emits an activate-only variant. The two-variant pattern is exclusive to the conformance runner.

If you find yourself authoring (or asked to author) a `prepare_environment` script that handles unit-test dependencies too, **stop**. The unit-test script handles its own dependencies. Adding a unit-test path into `prepare_environment` couples scripts that should stay independent, and breaks the activate-only contract between `prepare` and `conformance`.

### Shared rules across all three scripts

Anything not listed here is documented in the individual skill file:

- **Input folders are read-only — hard rule.** The build folder (and, for conformance, the conformance tests folder too) is **input only**. Every install, build artifact, cache, log, JUnit XML, coverage report, compiled test class, and temp file must land inside the working folder in the system temp directory, never inside the input folder. The build folder is shared with the renderer and with the user's version control; writing into it corrupts both. If you find yourself about to issue a command whose `cwd` is an input folder, or whose target path starts with the input folder, **stop** — the write has to go into the working folder.
- **Arguments arrive as absolute paths.** Current renderers resolve the build folder and conformance-tests folder to absolute paths before invoking the scripts (older renderers passed relative ones). Scripts therefore build their working-folder name from the **basename** of the argument (`/tmp/<lang>_$(basename "$1")` in Bash, `Join-Path ([System.IO.Path]::GetTempPath()) "<lang>_$(Split-Path $arg -Leaf)"` in PowerShell) and resolve the conformance-tests argument to absolute before any `cd`. Concatenating a raw argument (`.tmp/$1`, `<lang>_$1`, `$current_dir/$2`) produces doubled paths and errors like `ImportError: Start directory is not importable`.
- **Cleanup ownership.** The unit-test runner and the install-inline conformance runner remove their working folder on exit (`trap 'rm -rf …' EXIT` / `finally`). `prepare_environment` and the activate-only conformance runner **never delete** the working folder — prepare wipes-and-recreates it once per render and the activate-only runner attaches to it N times; deleting it in between destroys the amortization.
- **Shell flavor matches the host.** `.sh` on macOS / Linux, `.ps1` on Windows. A project intended for both OSes ships both files in matching pairs (`prepare` + `conformance` for each language must agree on working-folder name and isolation paths).
- **Exit codes are part of the contract.** `69` for unrecoverable errors (missing toolchain, bad args, can't enter the working folder, install failed); `1` for the "no tests discovered" guard in the conformance runner (and bad usage in the unit-test runner); any other non-zero code is propagated from the underlying test command. Other skills — notably [`plain-healthcheck`](../plain-healthcheck/SKILL.md) and [`check-plain-env`](../check-plain-env/SKILL.md) — branch on these codes.
- **Wired in via `config.yaml`.** Each script that is actually generated must be referenced from the relevant `config.yaml` via the `unittests-script:`, `conformance-tests-script:`, and `prepare-environment-script:` keys respectively. See the [`init-config-file`](../init-config-file/SKILL.md) skill for the canonical assembly. **If `prepare-environment-script` is declared, `conformance-tests-script` must be declared too** — a prepare script only makes sense in service of conformance, and `plain-healthcheck` will hard-fail a project that violates this.
- **Conformance scripts come in two variants — unit-test scripts do not.** When a `prepare_environment_<lang>` script exists, the conformance script is the **activate-only** variant (it attaches to the env prepare populated in the system-temp working folder). When no prepare exists, the conformance script is the **install-inline** variant (it stages and installs in one shot). The `implement-conformance-testing-script` skill picks the right variant automatically based on whether a prepare script is already on disk. **The unit-test script has no activate-only variant** — it is always self-contained, regardless of whether a `prepare_environment_<lang>` script exists.
- **Dependency isolation is project-local.** Each language's package cache / virtual env / build repo lives inside the working folder (`./.venv` for Python, `./node_modules` for Node, `./.m2` for Java, `./.gocache` for Go, `./.cargo` for Rust, `./.pub-cache` for Flutter, ...) — never in the user's home directory. The conformance script reads from the same project-local location prepare wrote to; the unit-test script uses its **own** working folder and its **own** copy of the isolated dependencies.
- **No language-package checks live in these scripts.** The scripts themselves install language packages via `pip install -r requirements.txt`, `npm ci`, `mvn -Dmaven.repo.local=...`, `go mod download`, `cargo fetch`, etc. They do **not** pre-verify individual packages; that's the package manager's job. The host-level checks for the toolchains and external dependencies belong in `check-plain-env`, not in these scripts.
- **Scripts are verbose**. They print out every step they take, including toolchain checks, dependency installations, and test results. This makes it easier to debug and understand what's going on.

For implementation details — the exact step sequence, toolchain checks, language-specific install / test commands, working-folder lifecycle, anti-patterns — open the corresponding `implement-*-testing-script` skill. Do not hand-author a testing script from scratch; route every creation or modification through the matching skill so the shared rules above are enforced uniformly.

## Writing Functional Specs

- Each functional spec must imply a **maximum of 200 changed lines of code**. This is a hard limit — if a spec would result in more than 200 lines of changes, it must be broken down into smaller, independent specs. This limit also helps avoid "Functional spec too complex!" errors from the renderer.
- **Conflicting specs must be avoided at all costs.** Functional specs should be written so that no conflicts exist between them. If two specs appear to conflict, they must be clarified by adding more detail and context to the specs until all possible conflicts are resolved. Prevention is always preferable to debugging conflicts after rendering.
- **Specs should be language-agnostic.** Avoid using programming language-specific terminology (e.g., generics syntax, framework annotations, language-specific collection types, decorator syntax, language-specific base classes or type keywords like "POJO" or "dataclass") in functional specs and definitions. Write specs in terms of behavior, concepts, and domain logic — not implementation constructs. General technical terms that are not language-specific are fine (e.g., null values, JSON types, HTTP status codes, REST api endpoints etc.). The `***implementation reqs***` section is the appropriate place for language-specific guidance.

    Naming concrete *components* — classes, methods, functions, fields — is encouraged and not in conflict with this rule. A functional spec should freely refer to concrete domain components, services, or entities (e.g., `:PaymentProcessor:`, `:UserRepository:`, `:DataConverter:`) and their operations (e.g., `:ChargeCard:`, `:FindById:`), pinning down their inputs, outputs, and error behaviors, and treat those names as part of the public contract. What it must *not* do is bake in how that contract is realized in a particular language: no `@staticmethod` decorators, no `class Foo extends Bar` phrasing, no `List<T>` or `Optional<T>` syntax, no "POJO with static methods" framing.

    The litmus test: if you switched the project from Python to Java (or vice versa), would the functional spec still read correctly with only `***implementation reqs***` updated? If yes, the spec is language-agnostic. If the functional spec itself would need rewording because it referenced a language-specific construct, the construct belongs in implementation reqs instead. The component name (`:DataConverter:`) is the same across languages; the syntax used to express "static method on a class" is not.
- **Keep sentences short and clear — but never at the cost of ambiguity.** Spec lines should be easy to read and understand at a glance. Prefer short, direct sentences and plain words over long sentences and jargon — if a 10-cent word and a 50-cent word say the same thing, use the 10-cent one. This applies to every spec section, not only functional specs: `***definitions***`, `***implementation reqs***`, `***test reqs***`, and `***acceptance tests***` should all be as concise as they can be while staying unambiguous. The hard constraint is in the second half of that rule: **wordy-but-precise always beats terse-but-ambiguous.** If trimming a clause, a qualifier, or a sub-bullet would leave the spec open to more than one reasonable interpretation, leave it in. When a sentence starts to grow because the behavior is genuinely complex, split it into two short sentences (or into a parent line + sub-bullets) rather than dropping detail. Concision is in service of clarity, never the other way around.
- **Specs must be deterministic enough to both *run* and *use* the software without reading the generated code.** A developer should be able to figure out, from the specs alone, two distinct things:

    1. **How to run the built software** — the entry-point command (e.g. `python -m app`, `uvicorn app.main:app`, `./my-cli`), prerequisites (required runtime versions, package managers, system binaries), required environment variables, ports the software listens on, configuration file paths and shapes, and any default arguments.
    2. **How to use the running software** — the full interaction surface. For a REST API: every endpoint path, HTTP method, request body shape, response body shape, status codes, and authentication scheme. For a CLI tool: every command, its arguments and flags, the expected output (including exit codes), and the input it reads (stdin, files, env vars). For a library: every public function/class, its signature, the inputs it accepts, the outputs it returns, and the errors it can raise.

    Concretely, a reader should never have to open `plain_modules/` to answer "how do I start this?" or "how do I call this endpoint?" — those answers must already live in the specs. **Never leave runtime or interface details up to the renderer's discretion** — if the spec doesn't pin them down, two renders can produce two different shapes, and any human or automated consumer of the software is now coupled to an undocumented choice.
- **Encapsulate functionality in functional specs.** `requires` modules import only functional specs. It is therefore important that the functionality is encapsulated in the functional specs and not in implementation reqs, as those will not be in the context of future functional specs when fixing previous conformance tests of previous functional specs.
- **Specs must define programmatic interfaces.** Any runtime or interface details must be defined in the functional specs, not in implementation reqs. This means functional specs name the concrete *components* a caller will reach for — utilities, services, methods, functions, fields — and pin down their inputs, outputs, and error behavior, so that callers can use the software without reading the generated code. For example, a spec can require:

    ```plain
    - Implement :DataConverter: as a stateless utility component exposing two operations.
        - :FormatData: takes a raw data string and a format type, returns a formatted string. Infer and convert value types. Empty inputs must be converted to null. Null values must be preserved — keys with null values must appear in the result, not be omitted. Handle escaping logic. Raise an error if the format type is not supported.
        - :ParseData: takes a formatted string and returns a structured object. Output an empty structure for null or missing fields. Unrecognized extra keys should be silently ignored.
    ```

    This rule is complementary to the earlier "specs should be language-agnostic" guideline, not in conflict with it. Component names (`:DataConverter:`, `:FormatData:`, `:ParseData:`) and behavioral contracts belong in functional specs because they survive a language switch unchanged. Language-specific realizations of those contracts — "POJO class with static methods", "Python module with module-level functions", `@staticmethod`, `class Foo`, exception types like `IllegalArgumentException` vs `ValueError`, choice of test framework (`pytest` vs `JUnit`), mocking library, fixture style, assertion syntax — belong in `***implementation reqs***` and `***test reqs***`, because those are exactly what changes when the target language changes. Use `***implementation reqs***` for *how the production code is realized* (language, frameworks, libraries, syntax, error types) and `***test reqs***` for *how the tests are realized* (test framework, test runner, mocking and fixture conventions, parametrization style, naming conventions, file layout). The goal is that swapping languages requires editing only `***implementation reqs***` and `***test reqs***`; the functional spec for `:DataConverter:` should read identically whether the project is in Python, Java, or anything else.

## Line Length Rule

**Keep every line in the `.plain` short.** When a sentence is too long, **do not** soft-wrap it across continuation lines — ***plain syntax requires every line inside a section to be its own list item starting with `- ` (with the possibility for nested bullet items). Instead, break the sentence down into multiple bullet items, each on its own line and each prefixed with `- `, nested under the parent bullet so the meaning stays grouped.

This rule applies to **every** spec update and to **all** sections — `***definitions***`, `***implementation reqs***`, `***test reqs***`, `***functional specs***`, `***acceptance tests***`, and concept explanations alike.

BAD — line is too long:

```plain
- :GatewayWebhook: should hand off :StripeRequest: to :StripeIntegration:.handle(), which returns a list of :EventEnvelope: dicts conforming to the gateway's contract.
```

WRONG SYNTAX AND BAD (AVOID AT ALL COSTS) — bare indented continuation lines without a leading `- ` are invalid ***plain syntax:

```plain
- :GatewayWebhook: should hand off :StripeRequest: to :StripeIntegration:.handle(),
  which returns a list of :EventEnvelope: dicts conforming to the gateway's
  contract.
```

GOOD — split at a natural clause boundary into nested `- ` bullets:

```plain
- :GatewayWebhook: should hand off :StripeRequest: to :StripeIntegration:.handle()
  - The method returns a list of :EventEnvelope: dicts.
  - The dicts must conform to the gateway's :EventEnvelope: contract.
```

If you find yourself writing a line longer than **120 characters**, stop and split it at a natural clause boundary into nested `- ` bullets (as in the GOOD example above) before moving on. Never use bare indented continuation lines without a leading `- ` — that is invalid ***plain syntax.

Do not paste long URLs, schema fragments, or example payloads inline either — those belong in `resources/` per the [Linked Resources](#linked-resources) rule above.

## Conflicting Specs and Conformance Test Debugging

The renderer can detect conflicting specs. Two functional specs may be in conflict if conformance tests for a previously passing spec begin to fail after a new spec is rendered. When a conformance test failure occurs, the first step is to determine **where the issue lies**. There are three possible outcomes:

1. **The implementation is incorrect** — the generated code does not correctly implement the functional spec. Fix the spec to clarify intent and re-render.
2. **The conformance tests are incorrect** — the generated tests do not accurately verify the spec. Adjust `***test reqs***` or `***acceptance tests***` to guide better test generation and re-render.
3. **The requirements conflict** — the two functional specs are inherently contradictory. One or both specs must be revised to resolve the conflict before re-rendering.

Conflicting specs are the most costly outcome and should be **prevented proactively**. When writing or modifying functional specs, carefully consider how each spec interacts with all previous specs. If ambiguity exists, add explicit detail to the spec to eliminate any possible interpretation that could conflict with earlier specs.

## Working with Specs

- The `.plain` files are the source of truth. Modify specs to change behavior, then re-render.
- The `resources/` directory contains schemas, API specs, transforms, and test fixtures referenced by the specs.
- Generated code in `plain_modules/` should not be manually edited — changes will be overwritten on the next render.

## Read-Only Generated Artifacts

All code in `plain_modules/` and `conformance_tests/` is generated and **must never be modified directly** — not the implementation code, not the unit tests, not the conformance tests. These artifacts can only be:

- **Read** — to understand what the generated code does, inspect behavior, and identify ambiguities in the specs.
- **Tested** — unit tests and conformance tests can be executed to verify correctness.
- **Debugged** — test failures and unexpected behavior should be traced through the generated code to understand root causes, but fixes must always be applied in the `.plain` specs, never in the generated code.

Each module has its own folder under `plain_modules/<module_name>/` containing the generated project (implementation + unit tests). Each module also has its own folder under `conformance_tests/<module_name>/`, with individual subfolders per functionality for conformance tests. Conformance tests may also include generated `***acceptance tests***` — these are equally read-only and serve the same purpose: gathering information and debugging the specs.

To change the generated code, **only the corresponding `.plain` spec files may be edited**:
- To change implementation or unit tests → modify the `***functional specs***`, `***implementation reqs***` or `***definitions***` sections of the spec.
- To guide conformance test generation → modify the `***test reqs***` section of the spec.
- To guide acceptance test generation → modify the `***acceptance tests***` subsections under functional specs.

The `test_scripts/` folder contains shell scripts for running unit tests and conformance tests against the generated code. These scripts are the entry point for test execution — see the [Running Tests](#running-tests) section for usage.

The workflow is: read the generated code to understand what it does, identify what is ambiguous or incorrect in the specs, then make changes exclusively in the `.plain` files and re-render.

## Common mistakes

- Usage of concepts before defining them 

BAD
```***plain
***functional specs***

- Implement :Message:

```

GOOD
```***plain
***definitions***

- :Message: is an interface of communication between two users. 

***functional specs***

- Implement :Message:
```

- Cyclic definitons 

BAD
```***plain
***definitions***

- :Message: has an :Author:

- :Author: can create a :Message:
```

GOOD
```***plain
***definitions***

- :Message: is an interface of communication between two users. 

- :Author: can create a :Message:
```

- Conflicting implementation requirements

BAD — both reqs in the same module

```***plain
***implementation reqs***

- :Implementation: should be in python

- :Implementation: should be in react
```

GOOD — split into two independent root modules

`backend.plain`
```***plain
***implementation reqs***

- :Implementation: should be in python

```

`frontend.plain`
```***plain
***implementation reqs***

- :Implementation: should be in react
```


## `codeplain` CLI reference

### Path parameter resolution

Every path argument the renderer accepts (`--build-folder`, `--conformance-tests-folder`, `--unittests-script`, `--conformance-tests-script`, `--prepare-environment-script`, `--log-file-name`, `--logging-config-path`, `--template-dir`, `--base-folder`, `--build-dest`, `--conformance-tests-dest`) resolves **based on where the value was written**:

- **CLI argument** → resolved against the **current working directory** of the `codeplain` invocation.
- **`config.yaml` value** → resolved against the **directory containing that config file**.
- **Default (not provided anywhere)** → resolved against the **directory containing the plain file**.
- **Absolute paths** and paths starting with `~` are used as-is (`~` is expanded).

Consequences worth knowing when authoring or debugging a project:

- Script paths are **validated at parse time** — the renderer fails fast with a `FileNotFoundError` if a `*-script` value doesn't resolve to an existing file. There is no fallback lookup (older renderer versions fell back to the renderer's own directory; that behavior is gone).
- The renderer passes the **resolved absolute paths** to the test scripts as their positional arguments — the scripts must not assume relative paths (see [Testing Scripts](#testing-scripts)).
- Since defaults resolve against the plain file's directory, `plain_modules/`, `conformance_tests/`, and `codeplain.log` land next to the spec regardless of where `codeplain` is invoked from — but an explicitly passed relative path lands relative to where it was written (CLI → cwd, config → config dir).

### CLI help

```txt
Render plain code to target code. Path arguments resolve based on where they
were written: values given on the command line are resolved against the
current working directory, values read from config.yaml are resolved against
the config file's directory, and defaults are resolved against the directory
containing the plain file. Absolute paths (and paths starting with '~') are
used as-is.

positional arguments:
  filename              Path to the plain file to render. The directory
                        containing this file has highest precedence for
                        template loading, so you can place custom templates
                        here to override the defaults. See --template-dir for
                        more details about template loading.

options:
  -h, --help            show this help message and exit
  --verbose, -v         Enable verbose output
  --base-folder BASE_FOLDER
                        Base folder for the build files
  --build-folder BUILD_FOLDER
                        Folder for build files
  --log-to-file, --no-log-to-file
                        Enable logging to a file. Defaults to True. Set to
                        False to disable.
  --log-file-name LOG_FILE_NAME
                        Name of the log file. Defaults to 'codeplain.log'. If
                        a file already exists at the resolved path, it will be
                        overwritten by the current logs.
  --render-range RENDER_RANGE
                        Specify a range of functionalities to render (e.g. `1`
                        , `2`, `3`). Use comma to separate start and end IDs.
                        If only one functionality ID is provided, only that
                        functionality is rendered. Range is inclusive of both
                        start and end IDs.
  --render-from RENDER_FROM
                        Continue generation starting from this specific
                        functionality (e.g. `2`). The functionality with this
                        ID will be included in the output. The functionality
                        ID must match one of the functionalities in your plain
                        file.
  --force-render        Force re-render of all the required modules.
  --unittests-script UNITTESTS_SCRIPT
                        Shell script to run unit tests on generated code.
                        Receives the build folder path as its first argument
                        (default: 'plain_modules').
  --conformance-tests-folder CONFORMANCE_TESTS_FOLDER
                        Folder for conformance test files
  --conformance-tests-script CONFORMANCE_TESTS_SCRIPT
                        Path to conformance tests shell script. Every
                        conformance test script should accept two arguments:
                        1) Path to a folder (e.g. `plain_modules/module_name`)
                        containing generated source code, 2) Path to a
                        subfolder of the conformance tests folder (e.g.
                        `conformance_tests/subfoldername`) containing test
                        files.
  --prepare-environment-script PREPARE_ENVIRONMENT_SCRIPT
                        Path to a shell script that prepares the testing
                        environment. The script should accept the source code
                        folder path as its first argument.
  --test-script-timeout TEST_SCRIPT_TIMEOUT
                        Timeout for test scripts in seconds. If not provided,
                        the default timeout of 120 seconds is used.
  --api [API]           Alternative base URL for the API. Default:
                        `https://api.codeplain.ai`
  --api-key API_KEY     API key used to access the API. If not provided, the
                        `CODEPLAIN_API_KEY` environment variable is used.
  --full-plain          Full preview ***plain specification before code
                        generation.Use when you want to preview context of all
                        ***plain primitives that are going to be included in
                        order to render the given module.
  --dry-run             Dry run preview of the code generation (without
                        actually making any changes).
  --replay-with REPLAY_WITH
  --template-dir TEMPLATE_DIR
                        Path to a custom template directory. Templates are
                        searched in the following order: 1) Directory
                        containing the plain file, 2) Custom template
                        directory (if provided through this argument), 3)
                        Built-in standard_template_library directory
  --copy-build          If set, copy the rendered contents of code in `--base-
                        folder` folder to `--build-dest` folder after
                        successful rendering.
  --build-dest BUILD_DEST
                        Target folder to copy rendered contents of code to
                        (used only if --copy-build is set).
  --copy-conformance-tests
                        If set, copy the conformance tests of code in
                        `--conformance-tests-folder` folder to `--conformance-
                        tests-dest` folder successful rendering. Requires
                        --conformance-tests-script.
  --conformance-tests-dest CONFORMANCE_TESTS_DEST
                        Target folder to copy conformance tests of code to
                        (used only if --copy-conformance-tests is set).
  --render-machine-graph
                        If set, render the state machine graph.
  --logging-config-path LOGGING_CONFIG_PATH
                        Path to the logging configuration file.
  --headless            Run in headless mode: no TUI, no terminal output
                        except a single render-started message. All logs are
                        written to the log file.

configuration:
  --config-name CONFIG_NAME
                        Name of the config file to look for. Looked up in the
                        plain file directory and the current working
                        directory. Defaults to config.yaml.

```

---
