---
description: Rules for writing ***implementation reqs*** sections in .plain files
globs: "**/*.plain"
---

# Rules for writing `***implementation reqs***`

When writing or editing an `***implementation reqs***` section in a `.plain` file, always follow these rules:

## HOW, not WHAT
- Implementation reqs describe **how** the software should be built, not **what** it should do
- Observable behavior (endpoints, business rules, user-facing features) belongs in `***functional specs***`
- Internal structure, technology choices, and coding guidance belong here

## What belongs here
- Technology choices: language, framework, runtime version
- Architectural constraints: patterns, layering, dependency rules
- Coding standards: naming conventions, style guidelines
- Data formats: serialization, encoding, transformation rules
- Error handling: strategies, retry logic, exception hierarchies
- Algorithm descriptions: specific approaches when behavior alone is insufficient
- Performance guidance: memory constraints, streaming requirements, batching strategies
- Language-specific constructs: generics, annotations, framework-specific types and idioms

## What does NOT belong here
- Behavior and features → `***functional specs***`
- Concept definitions → `***definitions***`
- Conformance test instructions → `***test reqs***`

## Encapsulation warning
- `requires` modules only receive functional specs from their dependencies — not implementation reqs
- If downstream modules need certain behavior to be visible, express it in functional specs, not here

## No duplication
- Do not duplicate guidance already present in the file or its imports
- Check imported templates before adding a new req

## Concept references
- Reference defined `:Concepts:` where they add clarity
- All referenced concepts must already be defined in `***definitions***`
- Implementation reqs in non-leaf sections apply to all subsections

## Format

```plain
***implementation reqs***
- :Implementation: should be in Python 3.12.
- :Implementation: should use pip for dependency management.
- When writing CSV files, :Implementation: should use streaming writes to avoid holding large datasets in memory.
```
