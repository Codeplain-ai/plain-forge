---
description: Rules for writing ***definitions*** sections in .plain files
globs: "**/*.plain"
---

# Rules for writing `***definitions***`

When writing or editing a `***definitions***` section in a `.plain` file, always follow these rules:

## Concept syntax
- Wrap concept names in colons: `:ConceptName:`
- Use CamelCase starting with an uppercase letter
- Valid characters: letters, digits, `+`, `-`, `.`, `_`

## Uniqueness
- Concept names must be globally unique across the spec and all its imports
- Check for collisions with imported templates, `import` and `requires` modules before adding

## Define before use
- A concept must be defined before it is referenced in any section (definitions, implementation reqs, functional specs, test reqs)
- Sources of definitions: the module's own `***definitions***`, an `import`ed module's definitions, or a `require`d module's `exported_concepts`

## No circular references
- Concept references must not form cycles — if A references B, then B must not reference A (directly or indirectly)
- Insert each concept after any concepts it references

Bad — circular:

```plain
- :Customer: is a user who has placed at least one :Order:.
- :Order: is placed by :Customer: and contains :OrderItem: entries.
```

`:Order:` references `:Customer:`, and `:Customer:` references `:Order:`. Fix by removing the back-reference:

```plain
- :Customer: is a user of the system.
- :Order: is placed by :Customer: and contains :OrderItem: entries.
```

## Exported concepts are not transitive
- If module A exports a concept and module B `requires` A, module C `requires` B does **not** gain access to A's exports
- Shared concepts belong in a common import module

## Description quality
- Descriptions must be clear, concise, and language-agnostic
- Nest attributes and constraints as sub-bullets
- Do not use programming language constructs (generics, annotations, framework types) in definitions

## Format

```plain
***definitions***
- :ConceptName: is a description of what it represents.
  - Attribute one (required)
  - Attribute two (optional)
```
