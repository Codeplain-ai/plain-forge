---
name: add-feature
description: >-
  End-to-end feature addition: takes a feature request in plain English, runs a
  focused QA interview to gather all details, then writes the ***plain specs
  (concepts, implementation reqs, functional specs, acceptance tests) using the
  other skills. Use when the user wants to add a new feature to an existing
  project.
---

# Add Feature

For full ***plain syntax details, see [PLAIN_REFERENCE.md](../../PLAIN_REFERENCE.md).

This skill is the continuous-loop counterpart of the full QA workflow in [CLAUDE.md](../../CLAUDE.md). Where the QA workflow bootstraps an entire project from scratch, `add-feature` adds a single feature to an **existing** set of `.plain` specs through the same interview-then-implement pattern.

## Input

A feature request from the user — anything from a one-liner ("add dark mode") to a detailed description. The request may be vague; the interview phase will sharpen it.

## Phase 1 — Interview

Gather everything needed to write unambiguous specs. Do not write any specs yet.

### 1a. Understand the request

Read the feature request and identify:
- What is the user asking for at a high level?
- Which existing `.plain` file(s) does this feature belong to?

Read the target `.plain` file(s) — including their `import` and `requires` chains — to understand what already exists: definitions, implementation reqs, and all current functional specs.

### 1b. Ask clarifying questions

Work through these areas, skipping any that are already clear from the request or the existing specs:

1. **Behavior** — What exactly should happen? What triggers it? What is the expected outcome?
2. **Entities** — Does this feature introduce new concepts, or does it extend existing ones? What attributes are involved?
3. **Edge cases** — What happens with invalid input, empty state, missing data, or boundary values?
4. **Constraints** — Are there business rules, permissions, size limits, or ordering requirements?
5. **Implementation guidance** — Does this feature need new technology, libraries, data formats, or architectural patterns not already in the implementation reqs?
6. **Verification** — What concrete outcomes prove this feature works correctly? Are acceptance tests needed?

Use the **AskQuestion** tool to batch related questions (3–5 per batch) as structured multiple-choice when the options are predictable. Always follow up with a free-form prompt so the user can add context not covered by the options.

### 1c. Confirm the plan

Once all details are gathered, summarize:
- New concepts to define (if any)
- New implementation reqs to add (if any)
- New functional specs to add (listed in proposed chronological order)
- Acceptance tests to add (if any)
- Which `.plain` file(s) will be modified

Read the summary back to the user and get explicit confirmation before proceeding.

## Phase 2 — Implement

Write the specs using the existing skills, in this exact order:

### 2a. Add concepts

If the feature introduces new entities or attributes, add them using the `add-concept` skill. Define each concept before it is referenced by later concepts or functional specs.

### 2b. Add implementation reqs

If the feature requires new technology, libraries, patterns, or coding guidance, add them using the `add-implementation-requirement` skill. Only add what is not already present in the file or its imports.

### 2c. Add test reqs

If the feature changes how conformance tests should be run (new framework, new execution command, new constraint), add using the `add-test-requirement` skill. This is rarely needed for a single feature.

### 2d. Add functional specs

Translate the confirmed feature into one or more functional specs. For each spec:

1. Draft the spec text.
2. Run `analyze-if-func-spec-too-complex` to verify it implies ≤ 200 LOC. If too complex, break it down and re-confirm with the user.
3. Run `analyze-2-func-specs` against every existing spec that touches the same concepts to check for conflicts. If a conflict is found, use `resolve-spec-conflict` before proceeding.
4. Insert the spec using `add-functional-requirement`.

Repeat for each functional spec in chronological order.

### 2e. Add acceptance tests

For functional specs that need concrete verification (as identified in the interview), add acceptance tests using the `add-acceptance-test` skill.

## Phase 3 — Review

After all specs are written:

1. Read the modified `.plain` file(s) in full.
2. Verify:
   - All new concepts are defined before use and have no circular references.
   - No conflicts between new and existing functional specs.
   - Each functional spec implies ≤ 200 LOC.
   - Functional specs are language-agnostic.
   - All external interfaces are explicit (endpoint paths, methods, CLI args, formats, etc.).
   - Chronological ordering is correct.
   - Acceptance tests are consistent with their parent specs.
3. Present the final changes to the user for approval.
4. If the user requests changes, apply them and re-review.

## When the User Comes Back with Another Feature

After completing one feature, the user may immediately describe the next. Start again from Phase 1. This creates a continuous loop: **interview → implement → review → interview → ...**

## Validation Checklist

- [ ] All clarifying questions answered before writing any specs
- [ ] User confirmed the plan before implementation started
- [ ] New concepts defined before they are referenced
- [ ] No circular concept references
- [ ] Each functional spec implies ≤ 200 LOC (verified via `analyze-if-func-spec-too-complex`)
- [ ] No conflicts with existing specs (verified via `analyze-2-func-specs`)
- [ ] Functional specs are language-agnostic
- [ ] All external interfaces are explicit (endpoint paths, methods, CLI args, formats, etc.)
- [ ] Acceptance tests are consistent with their parent functional specs
- [ ] User approved the final result
