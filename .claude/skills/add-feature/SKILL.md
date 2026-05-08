---
name: add-feature
description: >-
  End-to-end feature addition: takes a feature request in plain English and
  incrementally writes ***plain specs (concepts, implementation reqs, functional
  specs, acceptance tests) one functionality at a time, asking, authoring, and reviewing
  per functionality. Use when the user wants to add a new feature to an existing project.
---

# Add Feature

For full ***plain syntax details, see [PLAIN_REFERENCE.md](../docs/PLAIN_REFERENCE.md).

This skill is the continuous-loop counterpart of the full QA workflow in `forge-plain`. Where that workflow bootstraps an entire project from scratch, `add-feature` adds a single feature to an **existing** set of `.plain` specs. Like `forge-plain`, it works **incrementally**: ask focused questions, author the resulting `.plain` content immediately, review just the snippet that changed, and only then move on. Do not run a big upfront interview and then write everything at the end.

## Input

A feature request from the user — anything from a one-liner ("add dark mode") to a detailed description. The request may be vague; the functionality loop in Phase 2 will sharpen it as you go.

## Phase 1 — Scope

Keep this phase short. The goal is to know enough to start the first functionality — not to design the entire feature on paper.

1. **Read the request.** Identify what is being asked for at a high level and which existing `.plain` file(s) the feature most likely belongs to.
2. **Read the target `.plain` file(s).** Follow their `import` and `requires` chains so you understand the existing definitions, implementation reqs, functional specs, test reqs, and acceptance tests. You need this context to recognize impact when it surfaces in Phase 2.
3. **Frame the work.** Ask 1–3 framing questions only if the request leaves you unable to start: which module, what overall behavior, anything obviously cross-cutting. Use **AskQuestion** with concrete options plus a free-form catch-all. Do **not** front-load every edge case, every constraint, or every break/augment decision — those happen per-functionality in Phase 2.
4. **Skip ahead when the request is already concrete.** If the request is small and unambiguous (e.g. "add a `created_at` timestamp to `Task`"), go straight to Phase 2 with a single functionality. Don't manufacture a topic walk for trivial features.

End Phase 1 when you can name the file(s) you'll modify and the first functionality you'll author.

## Phase 2 — Functionality loop

A **functionality** is the smallest user-visible piece of behavior that fits in a single ***plain functional spec (≤200 LOC). Walk the feature one functionality at a time. For each functionality, run this tight loop and finish it before starting the next:

### 2a. Ask

Use **AskQuestion** for just the questions needed to author *this* functionality. Keep batches small (1–5 related questions). Cover only what shapes this functionality:

- **Behavior** — what exactly should happen, what triggers it, what the expected outcome is.
- **Entities** — does this functionality introduce a new concept or extend an existing one, and which attributes are involved?
- **Edge cases** — invalid input, empty state, missing data, boundary values, only as they apply *here*.
- **Constraints** — business rules, permissions, ordering, size limits that apply *here*.
- **Implementation guidance** — only if the functionality needs technology, libraries, data formats, or architectural patterns not already in the file or its imports.
- **Verification** — only if conformance testing is configured (see *Conformance gate* below): what concrete outcome proves this functionality works.

Frame each question with concrete options when the answer space is predictable, plus a free-form catch-all so the user can add detail you didn't anticipate.

### 2b. Author

Translate the answers directly into `.plain` content by editing the target file(s) yourself. Run the relevant checks **inline before inserting** each snippet:

- **New concepts** — add to the `***definitions***` section. Define each concept before it is referenced by anything else.
- **New functional spec** — draft the spec text; then **always** run `analyze-if-func-spec-too-complex` to verify it implies ≤200 LOC of generated code (if it doesn't, break it down with the user into smaller specs that each fit the limit); **always** run `analyze-2-func-specs` against every existing spec that touches the same concepts to confirm there are no contradictions; only after both analyzers pass, insert it into `***functional specs***` at the correct chronological position.
- **New implementation reqs** — only when the functionality introduces technology, libraries, data formats, or architectural patterns not already present. Add to `***implementation reqs***`.
- **New acceptance tests** — only if conformance testing is configured (see *Conformance gate* below) and the functionality needs concrete verification. Add as a child block under the relevant functional spec.
- **New test reqs** — only if conformance testing is configured *and* this functionality changes how conformance tests should be run (new framework, new execution command, new constraint). Add to `***test reqs***`. Rarely needed for a single feature.

After inserting a new functional spec, re-read the chronological ordering and confirm earlier specs still build cleanly. A new spec should slot in at the correct point in the build order; existing specs should not need to move.

### 2c. Handle impact just-in-time

If `analyze-2-func-specs` returns CONFLICTING, or if authoring this functionality would **break** (contradict, invalidate) or **augment** (change the meaning of, add behavior to) an existing concept, functional spec, implementation req, test req, or acceptance test, **stop authoring and surface it to the user right now**. Show the exact existing snippet and ask whether to:

- **(a) keep** the existing spec as-is and adjust this functionality to fit around it,
- **(b) augment** the existing spec — embed the proposed new wording in the question so the user can see what they're approving, or
- **(c) replace** the existing spec.

Apply the decision before continuing:

- For conflicts, rewrite the affected spec(s) directly so both intents hold, or replace the older spec if it is fully superseded.
- For augment or replace, edit the affected spec directly in the `.plain` file.
- If the user approved augmenting a concept, walk every existing functional spec, implementation req, test req, and acceptance test that references it and update each so it still holds under the new definition. Limit changes to the scope the user approved — do not opportunistically rewrite unrelated specs.

Never silently rewrite or weaken prior intent. If you didn't surface a break/augment to the user, you cannot make it.

### 2d. Review

Surface only what just changed using **AskQuestion**. Embed each snippet directly in the prompt so the user sees exactly what they are approving — the new concept, the new functional spec, the new impl req, the new acceptance test, or any existing spec you just augmented or replaced. For each snippet, frame the question around one or more of:

- **Missing parts** — anything that should be in the spec but isn't (an attribute, a validation rule, an edge case, a missing concept).
- **Possible extensions** — behavior or detail that could reasonably be expanded.
- **Ambiguities** — wording, ordering, or relationships that could be read multiple ways.

Offer concrete options such as "Approve as written", "Extend with …", "Clarify …", plus a free-form catch-all. Apply the user's response back to the `.plain` file(s) and re-surface any snippet that materially changed. Continue until every snippet from this functionality has been explicitly approved.

### 2e. Decide what's next

Either start the next functionality (back to 2a) or, if the feature is fully covered, move to Phase 3.

### Conformance gate

Steps 2b–2d above only generate `***test reqs***` and `***acceptance tests***` when the project has a `config.yaml` with a valid `conformance-tests-script` entry pointing at an existing conformance-test script in `test_scripts/`. Check the relevant `config.yaml` (the one that covers this module — there may be more than one in multi-part projects) and confirm the referenced script file exists. If conformance testing is not configured, skip those authoring paths entirely; functional specs, concepts, and implementation reqs still get authored normally.

## Phase 3 — Final review

Most checks have already happened per-functionality. Phase 3 is a slim consistency pass over the whole result, not a re-do of the functionality loop.

1. Read the modified `.plain` file(s) in full.
2. Verify:
   - All new concepts are defined before use and have no circular references.
   - Chronological ordering is correct end-to-end (no new spec depends on something that comes after it).
   - Functional specs are language-agnostic.
   - All external interfaces are explicit (endpoint paths, methods, CLI args, formats, etc.).
   - Acceptance tests (if any) are consistent with their parent specs.
3. Present the final diff for the modified file(s) to the user for approval.
4. If the user requests changes, apply them and re-review only the affected snippets — do not restart the functionality loop for the whole feature.

## When the User Comes Back with Another Feature

After completing one feature, the user may immediately describe the next. Start again from Phase 1. This creates a continuous loop: **scope → functionality loop → final review → scope → ...**

## Validation Checklist

- [ ] Target `.plain` file(s) and their `import`/`requires` chain were read before authoring
- [ ] Each functionality was asked, authored, conflict-checked, and reviewed before the next functionality started
- [ ] New concepts defined before they are referenced
- [ ] No circular concept references
- [ ] Each functional spec implies ≤ 200 LOC (verified via `analyze-if-func-spec-too-complex`)
- [ ] No unresolved conflicts with existing specs (verified via `analyze-2-func-specs`)
- [ ] Every break/augment of an existing spec was explicitly surfaced and approved by the user
- [ ] Functional specs are language-agnostic
- [ ] All external interfaces are explicit (endpoint paths, methods, CLI args, formats, etc.)
- [ ] Acceptance tests are consistent with their parent functional specs
- [ ] User approved the final diff
