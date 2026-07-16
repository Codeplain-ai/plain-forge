---
name: create-requires-module
description: >-
  Create a ***plain module that uses requires to depend on another module in
  the build chain. Use when the user wants to create a new .plain file that
  builds on top of a previously built module, inheriting its functional specs
  and generated code as a starting point.
---

# Create Requires Module

Always use the skill `load-plain-reference` to retrieve the ***plain syntax rules — but only if you haven't done so yet.

## What Requires Does

`requires` establishes a build ordering between modules. The required module is built **before** the current one. This does not necessarily mean the current module extends or depends on the required module's code — it may be completely independent. The `requires` relationship simply ensures the build order is correct.

When this module is rendered:
- The required module's generated code (`plain_modules/<required_module>`) is copied as the starting point.
- The required module's `***functional specs***` become visible as **previous functional specs**.
- Only `exported_concepts` from the required module are available (not its full definitions).

Use `requires` for:
- Ensuring a module is built after another in the build chain
- Building on top of an existing module's functionality
- Extending a base module with additional features

If you only need shared definitions and reqs (no functional specs, no generated code), use `import` instead — see the `create-import-module` skill.

## Workflow

1. **Identify the dependency.** Determine which module this new module builds on. That module must already exist and be renderable.
2. **Create the `.plain` file at the repository root** with YAML frontmatter containing the `requires` field. Modules with functional specs live at the root, not in `template/`.
3. **Review the required module's functional specs** — they will be treated as previous requirements. Your new functional specs must not conflict with them.
4. **Review the required module's `exported_concepts`** — only those concepts are available to reference from the required module.
5. **Add module-specific content** — definitions, implementation reqs, test reqs, and functional specs unique to this module.
6. **Check for conflicts** between your new functional specs and the required module's specs.

## Format

The `requires` field is a list of module paths in the YAML frontmatter:

```plain
---
requires:
  - base_module
import:
  - shared_template
description: Extended module that builds on base_module
---

***definitions***

- :NewFeature: is a feature added by this module.

***functional specs***

- :NewFeature: is available.
```

A module can use both `requires` and `import` together. `requires` points to other root-level modules; `import` resolves from the default `template/` directory (no prefix needed).

## Exported Concepts

The required module controls what concepts are visible via `exported_concepts`:

```plain
> In the required module's frontmatter:
---
exported_concepts: [":StorageClient:", ":BackupResult:"]
---
```

Only `:StorageClient:` and `:BackupResult:` would be available to modules that `require` this one. All other concepts from the required module are internal.

## Chronological Ordering with Requires

Functional specs from `requires` modules are considered **previous functional specs**. This means:
- They are already rendered and their code exists.
- Your new specs are rendered after them, with full awareness of what they defined.
- Your new specs must not conflict with the required module's specs.
- The renderer sees the required module's functional specs as context when rendering yours.

The current module may or may not be functionally related to the required module. In some cases `requires` simply enforces build order — the two modules may be independent pieces of the same project that need to be built in sequence.

## Import vs Requires

| Aspect | `import` | `requires` |
|--------|----------|------------|
| Pulls in definitions | Yes | No (only `exported_concepts`) |
| Pulls in implementation reqs | Yes | No |
| Pulls in test reqs | Yes | No |
| Pulls in functional specs | No | Yes (as previous requirements) |
| Copies generated code | No | Yes |
| Typical use | Templates, shared definitions | Build dependency chain |

## Validation Checklist

- [ ] Module file is at the repository root (not in `template/`)
- [ ] Required module exists and is renderable
- [ ] Required module's `exported_concepts` provide the concepts you need
- [ ] New functional specs do not conflict with the required module's specs
- [ ] Module has at least one functional spec and one implementation req
- [ ] Both `requires` and `import` are used correctly (not mixed up)
- [ ] YAML frontmatter is correctly formatted between `---` markers
