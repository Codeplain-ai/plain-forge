---
name: add-feature
description: >-
  End-to-end feature addition: takes a feature request in plain English and
  incrementally writes ***plain specs (concepts, implementation reqs, functional
  specs, acceptance tests) one functionality at a time, asking, authoring, and reviewing
  per functionality. Use when the user wants to add a new feature to an existing project.
---

# Add Feature

Always use the skill `load-plain-reference` to retrieve the ***plain syntax rules — but only if you haven't done so yet.

This skill is the continuous-loop counterpart of the full QA workflow in `forge-plain`. Where that workflow bootstraps an entire project from scratch, `add-feature` adds a single feature to an **existing** set of `.plain` specs.

## Core principle: one question → one answer → write specs

This skill runs as a tight, granular loop. **Each iteration is a single question to the user, followed by an immediate write to a `.plain` file.** No multi-question batches, no upfront interview, no "I'll gather a few things and then author." The cycle is:

1. Ask **one** focused question.
2. User answers.
3. **Immediately** write the resulting spec snippet to disk — even if you suspect it's incomplete or partly wrong.
4. Ask the next question, which often refines, extends, or corrects what you just wrote.

Writing eagerly is the point. A spec that's mostly right and gets corrected two questions later is better than a spec that waits for "enough" context before being written. The user can read what's on disk after every step and see exactly where things stand. Wrong-on-first-attempt specs are expected and welcome — you'll fix them in place on the next iteration. The questions themselves should be **shaped to produce immediately writable content**: a single attribute, a single behavior, a single edge case, a single constraint — not open-ended design questions that can't be turned into a snippet.

**One question at a time — but dig as deep as the topic needs.** "One question per iteration" is a rule about the AskUserQuestion call, not about the topic. If the user's answer is vague, ambiguous, or leaves real choices open, your **next** question should drill into that same topic — same loop, just another iteration. Keep drilling until the topic is concrete enough to produce a writable snippet. Only then move on to the next topic. Stopping too early and writing on top of a vague answer is worse than asking one more focused follow-up on the same thing.

## Input

A feature request from the user — anything from a one-liner ("add dark mode") to a detailed description. The request may be vague; the functionality loop in Phase 2 will sharpen it as you go.

## Phase 1 — Scope

Keep this phase short. The goal is to know enough to ask the **very first** writable question — not to design the entire feature on paper.

1. **Read the request.** Identify what is being asked for at a high level and which existing `.plain` file(s) the feature most likely belongs to.
2. **Read the target `.plain` file(s).** Follow their `import` and `requires` chains so you understand the existing definitions, implementation reqs, functional specs, test reqs, and acceptance tests. You need this context to recognize impact when it surfaces in Phase 2.
3. **Pick the target module** with one question — only if it's actually ambiguous which file to modify. Otherwise skip this and start authoring immediately.

End Phase 1 the moment you can name the file you'll write into and a single concrete starter question. Do **not** ask framing questions, scope questions, or multi-part design questions here.

## Phase 2 — One-question loop

This phase is a single, repeating cycle. Each iteration is **exactly one question** to the user followed by **an immediate write** to a `.plain` file. The loop ends when the user says the feature is fully covered.

### 2a. Ask one question

Use **AskUserQuestion** with **one** question per call. The question must be **writable**: phrase it so that any plausible answer maps directly to a concrete spec snippet you can insert. Bad shape: "How should the feature behave?" Good shape: "When the user submits an empty title, should the request be rejected with HTTP 400, accepted with a default title, or something else?"

Each question targets exactly one of:

- **Behavior** — a single trigger and its outcome.
- **A concept** — does this introduce a new concept, or extend an existing one? Which single attribute?
- **A single edge case** — one invalid input, empty state, boundary value.
- **A single constraint** — one business rule, permission, ordering, or size limit.
- **Implementation guidance** — only when the functionality requires technology / library / pattern not already in the file or its imports.
- **Verification** — only when the *Conformance gate* below is satisfied: one concrete outcome that proves this functionality works.

Always offer concrete options when the answer space is predictable, plus a free-form catch-all. Never bundle a second question into the prompt; never ask a question whose answer doesn't translate into a writable snippet on its own.

### 2b. Write immediately

The moment the user answers, write the resulting snippet to disk. Do **not** wait for additional context. Do **not** batch with the next question's output. Eager writes are the point — they may be wrong on the first try and that's expected. The next question will let the user correct them.

- **New concept** → use `add-concept` to add to `***definitions***`. Define before any reference.
- **New functional spec** → use `add-functional-spec`. That skill runs `analyze-if-func-spec-too-complex` and `analyze-func-specs` for you; let it. **Never hand-author functional specs.** If the skill reports the spec is too complex, ask the user a follow-up question to split it (the next iteration of the loop) — don't break it down on your own.
- **New implementation req** → use `add-implementation-requirement`. Only when the answer introduces technology / library / data format / architectural pattern not already present.
- **New acceptance test** → use `add-acceptance-test` under the relevant functional spec. Only when the *Conformance gate* is satisfied and the answer describes a concrete verification.
- **New test req** → use `add-test-requirement`. Only when conformance testing is configured and this answer changes how conformance tests are run.

If the user's answer **contradicts or refines** something you wrote in a previous iteration, fix the existing snippet in place right now — edit the spec, the concept, or the requirement directly. This is the explicit "correct on the next pass" behavior. Surface the change in the next question if it's non-trivial.

### 2c. Handle conflicts just-in-time

If `add-functional-spec` (via the analyzers it calls) reports a conflict with an existing spec, or if the snippet you just wrote would **break** (contradict, invalidate) or **augment** (change the meaning of, add behavior to) an existing concept / functional spec / implementation req / test req / acceptance test, your **next question** to the user must be about that conflict.

Show the exact existing snippet in the question and offer:

- **(a) keep** the existing spec — back out or narrow what you just wrote,
- **(b) augment** the existing spec — embed the proposed new wording in the question,
- **(c) replace** the existing spec.

Apply the user's choice the instant they answer. If they augmented a concept, walk every spec that references it and update each in place; limit changes to the approved scope. Never silently rewrite prior intent.

### 2d. Decide what's next

Ask the user whether the feature is fully covered. If yes, go to Phase 3. If no, return to 2a with the next single question — which often refines what you just wrote, or starts the next behavior, concept, edge case, or constraint.

### Conformance gate

Steps 2a–2d above only generate `***test reqs***` and `***acceptance tests***` when the project has a `config.yaml` with a valid `conformance-tests-script` entry pointing at an existing conformance-test script in `test_scripts/`. Check the relevant `config.yaml` (the one that covers this module — there may be more than one in multi-part projects) and confirm the referenced script file exists. If conformance testing is not configured, skip those authoring paths entirely; functional specs, concepts, and implementation reqs still get authored normally.

## Phase 3 — Final review

Most checks have already happened in the one-question loop. Phase 3 is a slim consistency pass, and its **final automated step is always `plain-healthcheck`**.

1. Read the modified `.plain` file(s) in full.
2. Verify:
   - All new concepts are defined before use and have no circular references.
   - Chronological ordering is correct end-to-end (no new spec depends on something that comes after it).
   - Functional specs are language-agnostic.
   - All external interfaces are explicit (endpoint paths, methods, CLI args, formats, etc.).
   - Acceptance tests (if any) are consistent with their parent specs.
3. Present the final diff for the modified file(s) to the user for approval.
4. If the user requests changes, drop **straight back into the one-question loop** to fix them — one question, one write, one fix at a time. Do not restart the whole loop from scratch.
5. **Final automated step — run `plain-healthcheck`.** This is the last thing the skill does before handing control back to the user. After the user approves the final diff, invoke the `plain-healthcheck` skill. It validates every `config.yaml` and dry-runs every top module, so a feature is never considered finished while the project would fail to render. If `plain-healthcheck` returns `FAIL`, work through the numbered list it produced (fix only `.plain` files / `config.yaml` / scripts — never generated code) by dropping back into the one-question loop, and then re-run `plain-healthcheck`. Repeat until it returns `PASS`. The skill is not done until `plain-healthcheck` has returned `PASS` — only then tell the user the feature is ready and remind them to re-render with `codeplain <module>.plain`.

## When the User Comes Back with Another Feature

After completing one feature, the user may immediately describe the next. Start again from Phase 1. This creates a continuous loop: **scope → functionality loop → final review → scope → ...**

## Validation Checklist

- [ ] Target `.plain` file(s) and their `import`/`requires` chain were read before authoring
- [ ] Every iteration asked exactly one question and wrote to disk immediately after the answer
- [ ] Every functional spec was authored via `add-functional-spec` (never hand-written)
- [ ] New concepts defined before they are referenced
- [ ] No circular concept references
- [ ] Every conflict / break / augment surfaced by the analyzers was put to the user as the next question and resolved before continuing
- [ ] Functional specs are language-agnostic
- [ ] All external interfaces are explicit (endpoint paths, methods, CLI args, formats, etc.)
- [ ] Acceptance tests are consistent with their parent functional specs
- [ ] User approved the final diff
- [ ] `plain-healthcheck` returned `PASS` after the final diff was approved


## Question style

The questions you put to the user must use simple grammatical structures:

- Prefer short, direct sentences over compound or nested clauses.
- Use plain words over jargon when both convey the same meaning.
- One idea per sentence. If a sentence needs a comma-separated list of clauses, split it.

Simpler grammar must not come at the cost of detail. Keep every constraint, edge case, option, and piece of context the user needs to answer accurately. If simplifying a sentence would drop a detail, split it into more sentences instead.
