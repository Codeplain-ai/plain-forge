---
description: Rules for creating and using import modules in .plain files
---

# Rules for import modules

When creating or editing a `.plain` file that uses `import` or is intended to be imported by other modules, always follow these rules:

## What an import module is
- An import module contains **only** `***definitions***`, `***implementation reqs***`, and/or `***test reqs***`
- It must **not** contain `***functional specs***`
- It must **not** use `requires` in its frontmatter
- It must live in the **`template/`** directory
- It may optionally `import` other modules or templates for layered reuse

## What import does
- `import` pulls in `***definitions***`, `***implementation reqs***`, and `***test reqs***` from the target module
- It does **not** pull in `***functional specs***`
- The default import directory is `template/` — the `template/` prefix is not needed in import paths
- Import paths omit the `.plain` extension

## Concept visibility
- All concepts defined in the imported module become available in the importing module
- Check for concept name collisions between imports and local definitions before adding

## Format

```plain
---
import:
  - airplain
description: Module that imports shared definitions and reqs
---
```

A module can import multiple modules:

```plain
---
import:
  - airplain
  - shared_utils
---
```

## Combining import with requires
- A module can use both `import` and `requires` together
- `import` brings in shared definitions and reqs
- `requires` brings in the build dependency chain and functional specs
- An import module itself must **not** use `requires`
