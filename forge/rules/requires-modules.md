---
description: Rules for creating and using requires modules in .plain files
---

# Rules for requires modules

When creating or editing a `.plain` file that uses `requires`, always follow these rules:

## What requires does
- `requires` establishes a **build ordering** — the required module is built before the current one
- The required module's generated code (`plain_modules/<required_module>`) is copied as the starting point
- The required module's `***functional specs***` become visible as **previous functional specs** — this property **is transitive**
- Only `exported_concepts` from the required module are available — not its full definitions — and this property **is not transitive**

## Tech stack must match (hard rule)
- Because the required module's generated code is copied as the starting point and the renderer continues building on top of it with a single toolchain, two modules can only be linked with `requires` when they target the **same language, framework, and runtime**
- A runtime / network dependency between systems is **not** a reason to use `requires`
- Example of the mistake: a React frontend that talks to a Python/FastAPI backend over HTTP must **not** `requires: [backend]` — the stacks differ
- Model that pair as two independent root modules (each with its own `config.yaml` and test scripts) and express the contract through a shared API schema in `resources/` or shared concepts in an `import`ed template — never through `requires`

## Build order, not necessarily dependency
- The current module does not need to extend or depend on the required module's code
- The two modules may be completely independent
- `requires` ensures the build order is correct for the project as a whole

## Conflict prevention
- The current module's functional specs must not conflict with the required module's specs
- The required module's specs are treated as previous requirements — the renderer sees them as context
- Review the required module's functional specs before adding new ones

## No access to full definitions
- Only concepts listed in the required module's `exported_concepts` are available
- Other concepts from the required module are internal and invisible
- If you need shared definitions, use `import` for that — not `requires`

## File locations
- Modules that use `requires` live at the **repository root** — they are functional modules with specs
- `requires` paths point to other root-level modules (e.g., `auth`, `messaging`)
- The default import directory is `template/` — the `template/` prefix is not needed in import paths (e.g., `airplain`)
- Never `require` a template — templates are for `import` only

## Format

```plain
---
requires:
  - auth
import:
  - airplain
description: Module built after auth, importing shared definitions
---
```

A module can require multiple modules:

```plain
---
requires:
  - auth
  - messaging
import:
  - airplain
---
```
