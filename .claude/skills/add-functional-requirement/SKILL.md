---
name: add-functional-requirement
description: >-
  Add a functional requirement to the ***functional specs*** section of a
  ***plain spec file. Use when the user wants to add new behavior, a feature,
  or a "what the software should do" requirement to a .plain file.
---

# Add Functional Requirement

For full ***plain syntax details, see [PLAIN_REFERENCE.md](../../PLAIN_REFERENCE.md).

## Workflow

1. **Identify the target `.plain` file.** If ambiguous, ask the user.
2. **Read the entire file** to understand existing definitions, implementation reqs, and all current functional specs (including those in `requires` modules).
3. **Draft the functional spec** following the rules below.
4. **Analyze complexity** — use the `analyze-if-func-spec-too-complex` skill to verify the drafted spec implies ≤ 200 LOC. If too complex, break it down into smaller specs and repeat from step 3 for each.
5. **Check for conflicts** with every existing functional spec — this is critical. Use `analyze-2-func-specs` to check pairs; use `resolve-spec-conflict` if a conflict is found.
6. **Append the spec** to the end of the `***functional specs***` section (specs are chronological; new ones go last).
7. **Read the file again** to confirm correct placement and syntax.

## Rules

### Complexity Limit

Each functional spec must imply a **maximum of 200 changed lines of code**. If the requirement is too large, break it into multiple smaller, independent specs. Do not include LOC estimates in the spec text.

### Chronological Ordering

Specs are rendered incrementally, top to bottom. The renderer has **no knowledge of future specs** — only previously rendered specs are in context. This means:
- A new spec can reference behavior defined by earlier specs.
- A new spec **cannot** assume anything about specs that come after it.
- Place the new spec at the correct position if it must come before a future spec; otherwise append at the end.

### Language Agnosticism

Write in terms of behavior, concepts, and domain logic — not implementation constructs. Avoid language-specific types, generics syntax, framework annotations, or other constructs tied to a particular language or framework. General technical terms (null values, JSON types, HTTP status codes) are fine. Language-specific guidance belongs in `***implementation reqs***`.

### No Conflicts

The new spec must not contradict any existing functional spec. Conflicting requirements are the most costly outcome. Before adding, review all existing specs and verify the new one is compatible. Use `analyze-2-func-specs` to determine if 2 specs are compatible or not. If ambiguity exists, add explicit detail to eliminate any conflicting interpretation. If a conflict is detected, use the `resolve-spec-conflict` skill to diagnose and fix it before proceeding.

### Disambiguation

Each functional spec must be unambiguous — the renderer should have only one reasonable interpretation. If a single line is not enough to fully disambiguate the behavior, use **nested sub-bullets** to add detail. Nested lines clarify the parent spec; they do not introduce separate functionality. Even with nested detail, the spec must still imply ≤ 200 LOC.

```plain
- :User: should be able to send a :Message: to a :Conversation:.
  - A :Message: must have non-empty content.
  - The :Message: is appended to the end of the :Conversation:.
  - All :Participant: members of the :Conversation: can see the new :Message:.
```

### Deterministic Interface

Specs must be detailed enough that a developer can use the built software without reading the generated code. All external interfaces must be explicit — REST endpoint paths and HTTP methods, CLI command names and arguments, file formats, message schemas, etc. Never leave interface details up to the renderer's discretion.

### Encapsulation

Functionality must be self-contained in the spec text. `requires` modules only import functional specs, so do not rely on implementation reqs to convey behavior — they won't be visible in downstream modules.

## Acceptance Tests

If the functional requirement needs verification, use the `add-acceptance-test` skill to add acceptance tests after inserting the spec.

## Validation Checklist

- [ ] Spec implies ≤ 200 lines of code changes
- [ ] No conflict with any existing functional spec
- [ ] Written in language-agnostic terms (no language/framework specifics)
- [ ] All external interfaces are explicit (endpoint paths, methods, CLI args, formats, etc.)
- [ ] All referenced `:Concepts:` are defined in `***definitions***`
- [ ] Sentences are short, clear, and unambiguous
- [ ] No redundancy with existing specs
- [ ] Placed in correct chronological position (usually at the end)
