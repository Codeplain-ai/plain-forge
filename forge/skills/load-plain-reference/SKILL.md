---
name: load-plain-reference
description: >-
  Loads the full ***plain language reference into context: syntax, section types
  (definitions, implementation reqs, test reqs, functional specs, acceptance tests),
  concept notation, frontmatter (import/requires/required_concepts/exported_concepts),
  templates, linked resources, module model, and authoring best practices. Use whenever
  authoring, editing, reviewing, or debugging .plain files, or before invoking any other
  skill that reads or writes .plain content.
---

# PLAIN_REFERENCE.md

## Project Overview

This repository is a workspace for writing and managing **\*\*\*plain** (codeplain) specifications. \*\*\*plain is a specification-driven language powered by AI that generates production-ready code from `.plain` spec files.

The `.plain` files in this repository are the source of truth. They describe what the software should do, how it should be built, and how it should be tested. The generated code is a read-only artifact produced by the renderer.

## ***plain Language Reference

***plain is a specification language designed for writing software requirements in a clear, structured format. It generates production-ready code from `.plain` spec files using AI. Full documentation: https://plainlang.org/docs/language-guide/

### .plain File Structure

A `.plain` file consists of an optional YAML frontmatter section followed by standardized sections marked with `***section name***` headers. There are four types of specification sections:

- `***definitions***` — declares concepts used throughout the specification
- `***implementation reqs***` — non-functional requirements about how the software should be built
- `***test reqs***` — requirements for conformance testing
- `***functional specs***` — describes what the software should do

Every plain source file requires at least one functional spec and an associated implementation req. Functional specs must reside in leaf sections while other specifications can be placed also in non-leaf sections. Specifications in non-leaf sections apply to all of their subsections.

### Concept Notation

Concepts are the building blocks of ***plain specifications. They are written between colons: `:ConceptName:`. Valid characters include letters, digits, plus, minus, dot, and underscore.

Concepts must be defined in `***definitions***` before being referenced in other sections. Concept names must be globally unique across the specification and its imports. Concept references must not form cycles — if concept A references concept B, then concept B must not reference concept A (directly or indirectly).

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
| `:UnitTests:` | Auto-generated unit tests for individual functionalities |
| `:ConformanceTests:` | Auto-generated tests that verify implementation conforms to specs |
| `:AcceptanceTest:` / `:AcceptanceTests:` | Tests that validate specific aspects of the implementation |

### Definitions Section

Declares concepts used throughout the specification. A concept must be defined before it can be referenced in any section. The definition can come from the module's own `***definitions***` section, from an `import`ed module's definitions, or from a `require`d module's `exported_concepts`. Attributes and constraints can be nested as sub-bullets.

```plain
***definitions***
- :ConceptName: is a description of the concept.
  - Additional details or attributes can be nested
  - Multiple attributes can be listed
```

### Implementation Reqs Section

A free-form section for any instructions that steer code generation. Common uses include technology choices, architectural constraints, coding standards, and naming conventions, but it can also contain detailed implementation guidance — data formats, error handling strategies, algorithm descriptions, or any other context the renderer needs to produce correct code. These describe HOW to build the software, not WHAT it should do.

```plain
***implementation reqs***
- :Implementation: should be in Python.
- :MainExecutableFile: of :App: should be called "hello_world.py".
- :Implementation: should include :Unittests: using Unittest framework!
```

### Test Reqs Section

Specifies requirements for conformance testing — test frameworks, execution methods, and testing constraints. Only used when writing and fixing conformance tests (not unit tests).

```plain
***test reqs***
- :ConformanceTests: of :App: should be implemented in Python using Unittest framework.
- :ConformanceTests: will be run using "python -m unittest discover" command.
- :ConformanceTests: must be implemented and executed - do not use unittest.skip().
```

### Functional Specs Section

Describes what the software should do. Each bullet point is a single piece of functionality that will be implemented. Functional specs are rendered incrementally one by one — earlier specs cannot reference later specs.

Each functional spec must be limited in complexity. If a spec is too complex, the renderer responds with "Functional spec too complex!" and it must be broken down into smaller specs.

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

Nested under individual functional specs to specify how to verify correct implementation. They extend conformance tests and are implemented according to the `***test reqs***` specification.

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
- **`exported_concepts`** — concepts made available to modules that `require` this one.

### Linked Resources

Specifications can reference external files using markdown link syntax. The linked resource is passed along with the spec to the renderer. File paths are resolved relative to the `.plain` file location. Only files in the same folder (and subfolders) are supported; no external URLs.

```plain
- :User: should be able to add :Task:. The details of the user interface
  are provided in the file [task_modal_specification.yaml](task_modal_specification.yaml).
```

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
4. **Use acceptance tests** — add them for requirements that need verification
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
config.yaml              # Codeplain configuration
```

**Generated artifacts** (gitignored):
- `plain_modules/<module_name>/` — generated project for each `.plain` spec (implementation + unit tests)
- `conformance_tests/<module_name>/` — generated conformance tests for each module

## How Modules Work

There are two types of modules:

### Import Modules

An import module lives in the **`template/`** directory and contains **only** `***definitions***`, `***implementation reqs***`, and/or `***test reqs***`. It must **not** contain `***functional specs***` and must **not** use `requires`. It may optionally `import` other templates for layered reuse.

When a module **`import`s** another, it gains access to the imported module's definitions, implementation reqs, and test reqs — but not its functional specs. The default import directory is `template/`, so the `template/` prefix is not needed (e.g., `airplain`).

### Requires Modules

`requires` establishes a build ordering between modules. The required module is built **before** the current one. This does not necessarily mean the current module extends or depends on the required module's code — it may be completely independent. The `requires` relationship ensures the build order is correct.

When a module **`requires`** another:
- The required module's generated code (`plain_modules/<required_module>`) is copied as the starting point.
- The required module's `***functional specs***` become visible as **previous functional specs**.
- Only `exported_concepts` from the required module are available (not its full definitions).

A module can use both `requires` and `import` together. `requires` points to other root-level modules (e.g., `auth`, `messaging`); `import` resolves from the default `template/` directory without needing the prefix (e.g., `airplain`). Modules with functional specs live at the repository root. Import modules (templates) live in `template/`.

**`requires` modules must share the same tech stack.** Because the required module's generated code is copied as the starting point and the renderer continues building on top of it with one language/framework toolchain, two modules can only be linked with `requires` when they target the same language, framework, and runtime. A runtime/network dependency between systems is **not** a reason to use `requires`. For example, a React frontend that talks to a Python/FastAPI backend over HTTP must **not** `requires: [backend]` — the stacks differ. Model that pair as two independent root modules (each with its own `config.yaml` and test scripts), and express the contract between them through a shared API schema in `resources/` or shared concepts in an `import`ed template, not through `requires`.

### Contracts Between Modules

Modules can use `required_concepts` and `exported_concepts` to enforce contracts between them. A template declaring `required_concepts` means any module that imports it must define those concepts. A module declaring `exported_concepts` controls which concepts are visible to modules that `require` it.

**Exported concepts are not transitive.** If module A exports a concept and module B `requires` A, module B can use that concept — but if module C `requires` B, it does **not** automatically gain access to A's exported concepts. If a concept needs to be shared across multiple `requires` modules, define it in a common import module and have each module `import` that shared template.

## Running Tests

Test scripts live in `test_scripts/` and are run from the repo root:

```bash
# Run all unit tests for a module
./test_scripts/run_unittests.sh <module_name>

# Run a single unit test
./test_scripts/run_unittests_single.sh <module_name>

# Run conformance tests
./test_scripts/run_conformance_tests.sh <module_name> <conformance_tests_folder>
```

## Writing Functional Specs

- Each functional spec must imply a **maximum of 200 changed lines of code**. This is a hard limit — if a spec would result in more than 200 lines of changes, it must be broken down into smaller, independent specs. This limit also helps avoid "Functional spec too complex!" errors from the renderer.
- **Conflicting specs must be avoided at all costs.** Functional specs should be written so that no conflicts exist between them. If two specs appear to conflict, they must be clarified by adding more detail and context to the specs until all possible conflicts are resolved. Prevention is always preferable to debugging conflicts after rendering.
- **Specs should be language-agnostic.** Avoid using programming language-specific terminology (e.g., generics syntax, framework annotations, language-specific collection types) in functional specs and definitions. Write specs in terms of behavior, concepts, and domain logic — not implementation constructs. General technical terms that are not language-specific are fine (e.g., null values, JSON types, HTTP status codes, REST api endpoints etc.). The `***implementation reqs***` section is the appropriate place for language-specific guidance.
- **Keep sentences short and clear.** Spec lines should be easy to read and understand at a glance. Prefer several short, concise sentences over long, complex ones.
- **Specs must be deterministic enough to use the software without reading the generated code.** A developer should be able to know exactly how to interact with the built software solely from the specs. For example, if the software is a REST API, the specs must include endpoint paths, HTTP methods, request/response formats, and status codes. If it is a CLI tool, the specs must include command names, arguments, and expected output. Never leave interface details up to the renderer's discretion.
- **Encapsulate functionality in functional specs.** `requires` modules import only functional specs. It is therefore important that the functionality is encapsulated in the functional specs and not in implementation reqs, as those will not be in the context of future functional specs when fixing previous conformance tests of previous functional specs.

## Working with Specs

- The `.plain` files are the source of truth. Modify specs to change behavior, then re-render.
- The `template/` directory contains reusable template specs that define common patterns.
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

## Conformance Test Workflow

Each functional spec in a module has its own set of conformance tests, generated per functional spec per module. After a new functional spec is rendered (i.e., its implementation code is generated), conformance tests for that spec are also rendered. Before proceeding, **all previous conformance tests** (from earlier functional specs in the same module) are run. Ideally, all conformance tests of all previous functional specs pass without any changes. If any previously passing conformance test now fails, the failure must be resolved before moving on. Resolution means one of three things: fixing the conformance test, fixing the implementation code (by adjusting the spec), or identifying conflicting specs.

If conformance tests of a previous functional spec need to be changed in order to pass, this is a strong indicator that the functional specs themselves may need to be amended. Needing to modify earlier conformance tests suggests the new functional spec has introduced behavior that is inconsistent with what was previously specified — the specs should be reviewed and clarified to eliminate the ambiguity or conflict.

## Conflicting Specs and Conformance Test Debugging

The renderer can detect conflicting specs. Two functional specs may be in conflict if conformance tests for a previously passing spec begin to fail after a new spec is rendered. When a conformance test failure occurs, the first step is to determine **where the issue lies**. There are three possible outcomes:

1. **The implementation is incorrect** — the generated code does not correctly implement the functional spec. Fix the spec to clarify intent and re-render.
2. **The conformance tests are incorrect** — the generated tests do not accurately verify the spec. Adjust `***test reqs***` or `***acceptance tests***` to guide better test generation and re-render.
3. **The requirements conflict** — the two functional specs are inherently contradictory. One or both specs must be revised to resolve the conflict before re-rendering.

Conflicting specs are the most costly outcome and should be **prevented proactively**. When writing or modifying functional specs, carefully consider how each spec interacts with all previous specs. If ambiguity exists, add explicit detail to the spec to eliminate any possible interpretation that could conflict with earlier specs.

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