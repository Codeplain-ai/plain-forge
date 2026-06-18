---
description: Rules for writing ***functional specs*** and ***acceptance tests*** in .plain files
globs: "**/*.plain"
---

# Rules for writing `***functional specs***`

When writing or editing a `***functional specs***` section in a `.plain` file, always follow these rules:

## Complexity limit
- Each functional spec must imply a **maximum of 200 changed lines of code**
- If a spec is too large, use `break-down-func-spec` to split it into multiple smaller, independent specs
- Use `analyze-if-func-spec-too-complex` to verify before inserting
- Use `analyze-func-specs` to check a spec (or a batch of specs) against all relevant existing specs in a single batched call; use `resolve-spec-conflict` for each conflicting pair it reports

## Chronological ordering
- Specs are rendered incrementally, top to bottom
- The renderer has **no knowledge of future specs** — only previously rendered specs are in context
- A new spec can reference behavior from earlier specs but cannot assume anything about specs that come after it
- Functional specs from `requires` modules are treated as previous requirements

## No conflicts
- The new spec must not contradict any existing functional spec
- Before adding, review all existing specs and verify compatibility
- If ambiguity exists, add explicit detail to eliminate any conflicting interpretation

## Language agnosticism
- Write in terms of behavior, concepts, and domain logic
- Avoid language-specific terminology: generics syntax, framework annotations, language-specific collection types, decorator syntax, base-class keywords, framings like "POJO" or "dataclass"
- General technical terms that are not language-specific are fine: null values, JSON types, HTTP status codes, REST endpoints, etc.
- **Naming concrete components is encouraged.** Functional specs can and should refer to concrete domain components, services, or entities (e.g., `:PaymentProcessor:`, `:UserRepository:`, `:DataConverter:`) and their operations (e.g., `:ChargeCard:`, `:FindById:`), pinning down their inputs, outputs, and error behavior. Those names are part of the public contract and survive a language switch. What they must **not** do is bake in how the contract is realized (`@staticmethod`, `class Foo extends Bar`, `List<T>`, `async def`, etc.)
- **Litmus test:** if the project switched from Python to Java (or vice versa), would the functional spec read correctly with only `***implementation reqs***` updated? If yes, the spec is language-agnostic. If the spec itself would need rewording, the construct belongs in implementation reqs.

## Disambiguation
- Each functional spec must be unambiguous — the renderer should have only one reasonable interpretation
- If a single line is not enough to fully disambiguate the behavior, use **nested sub-bullets** to add detail
- Nested lines clarify the parent spec — they do not introduce separate functionality
- Even with nested detail, the spec must still imply ≤ 200 lines of code

## Deterministic interface
- Specs must be detailed enough that a developer can use the built software without reading the generated code
- All external interfaces must be explicit: REST endpoint paths and HTTP methods, CLI command names and arguments, file formats, message schemas, etc.
- Never leave interface details up to the renderer's discretion

## Encapsulation
- Functionality must be self-contained in the spec text
- `requires` modules only receive functional specs — do not rely on implementation reqs to convey behavior
- Behavior that downstream modules need must be expressed in functional specs, not elsewhere

## Line length
- See [`line-length.md`](line-length.md) — applies to every section, but bites hardest here because functional specs trend long
- Hard limit: 120 characters. When a line gets too long, split at a natural clause boundary into nested `- ` bullets — **never** use bare indented continuation lines (invalid ***plain syntax)

## Acceptance tests
- Nest `***acceptance tests***` under a functional spec when verification criteria are needed
- Each acceptance test must be a **full workflow test** — a specific scenario that exercises the functional spec end-to-end, not a unit-level check of a single field or condition
- Do not restate the obvious behavior from the functional spec — simple, direct verifications are already auto-generated as conformance tests. Acceptance tests must go beyond that: multi-step workflows, interactions between concepts, edge-case scenarios, or end-to-end sequences that prove the feature works in a realistic context
- Each acceptance test must be a direct logical consequence of the parent spec — it illustrates, not extends
- Acceptance tests must describe concrete, verifiable outcomes — not vague qualities
- Acceptance tests must not contradict, narrow, or extend beyond the parent spec

## Format

```plain
***functional specs***

- Implement the entry point for :App:.

- :User: should be able to add :Task:. Only valid :Task: items can be added.

- :User: should be able to send a :Message: to a :Conversation:.
  - A :Message: must have non-empty content.
  - The :Message: is appended to the end of the :Conversation:.
  - All :Participant: members of the :Conversation: can see the new :Message:.

  ***acceptance tests***
  - Sending a :Message: to a :Conversation: with three participants should make the message visible to all three.
```
