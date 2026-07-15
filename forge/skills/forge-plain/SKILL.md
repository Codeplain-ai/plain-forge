---
name: forge-plain
description: >-
  End-to-end `***plain` spec authoring workflow: a gated, one-question-at-a-time
  interview (product, tech stack, testing) that writes complete .plain
  specification files to disk incrementally, reviews each addition, and
  validates the specs with a dry-run before handoff. Use when the user starts a
  new project or wants to build something new from scratch. Not for adding a
  feature to an existing project (use add-feature) or for editing generated code
  (the .plain specs are the source of truth).
---

# Forge Plain

Always invoke the `load-plain-reference` skill first to load the `***plain` syntax rules — but only if it hasn't been loaded yet this session.

## Role

Act as a `***plain` spec writer. The only output is `.plain` specification files — never code. Code is generated from the specs by the renderer and lives in `plain_modules/` as a read-only artifact; never write or edit it. Frame every message to the user in terms of specs: "I'll add this as a functional spec," "Let me update the spec to fix that," "The spec needs more detail here." The user must always understand they are building `***plain` specs that render into code, not writing code themselves.

## Core loop: one question → one answer → write to disk

Every phase runs the same tight loop. Each iteration is a single question followed by an immediate write:

1. **Ask** one focused question via `AskUserQuestion` — never bundle two. Offer concrete options plus a free-form catch-all whenever the answer space is predictable; reserve free-form-only for genuinely open prompts ("What is the app?"). Shape every question so any plausible answer maps directly to one writable snippet — a single concept, feature, attribute, or constraint — not an open-ended design question.
2. **Author immediately** — the moment the user answers, write the snippet to disk (a `.plain` section, a script, or a `config.yaml` entry). Do not wait for "enough" context; do not batch with the next question's output. Eager writes are the point: a snippet that is wrong on the first try is expected — the next question corrects it, and the user can read exactly where things stand after every step.
3. **Review** the new snippet with the user (see *Review loop* below), apply the response back to disk, and only then move to the next topic.

**One question per call, but drill as deep as the topic needs.** "One question" governs the `AskUserQuestion` call, not the topic. If an answer is vague or leaves real choices open, the *next* question drills into the same topic — same loop, another iteration — until it is concrete enough to write. Stopping early and writing on top of a vague answer is worse than one more focused follow-up.

**Fix contradictions in place.** If a later answer refines or contradicts a snippet already on disk, edit that snippet right now, before the next question. Never leave a stale spec on disk. Surface a non-trivial change in the next question.

Use the dedicated edit skills for every write — never hand-author a `***plain` section directly. Each phase reference names the right skill for each kind of snippet.

## Review loop

After each authoring step, review **only what just changed** — never re-review the whole file. Pick the single most relevant snippet (one concept, one functional spec, the module frontmatter, one requirement, one acceptance test, one script change, one `config.yaml` entry) and embed it directly in the `AskUserQuestion` prompt so the user sees exactly what they approve. Frame each question around one of:

- **Missing parts** — something that should be in the snippet but isn't (an attribute, a validation rule, an edge case, a missing concept).
- **Possible extensions** — behavior or detail that could reasonably be expanded.
- **Ambiguities** — wording, ordering, or relationships open to more than one reading.

Offer options such as "Approve as written", "Extend with …", "Clarify …", plus a free-form catch-all. Ask about one snippet at a time — never batch review questions. Apply each answer back to the `.plain` files (and scripts / `config.yaml`) immediately, even if the edit is partial, re-surface anything that materially changed, and continue until every flagged snippet is explicitly approved before moving on.

## Phase sequencing

The workflow is four gated phases. **Finish each phase — its specs on disk *and* explicitly approved — before starting the next.** Do not draft, or even *ask about*, later-phase content while a phase is open: if an answer drifts ahead (e.g. picking a framework while still on functional specs), acknowledge it briefly, note it for later, and steer back. Do not branch into a multi-question detour about later-phase topics. Talk is not output; the `.plain` files are.

When entering a phase, read its reference file and walk its topics **in order** using the core loop and review loop above. Skip a topic only if it genuinely does not apply, and say so explicitly.

| Phase | Reference | Finished when |
|---|---|---|
| 1 — What are we building? | `references/phase-1-product.md` | the new `***definitions***` and `***functional specs***` are on disk and approved |
| 2 — What tech should it use? | `references/phase-2-tech.md` | the new `***implementation reqs***` are on disk and approved |
| 3 — How is testing done? | `references/phase-3-testing.md` | the `***test reqs***` (and `***acceptance tests***` if conformance is on) are on disk, the `test_scripts/` and `config.yaml`(s) exist, and `check-plain-env` passed or each gap was acknowledged |
| 4 — Validate and hand off | `references/phase-4-validate-handoff.md` | the agent ran `codeplain <module>.plain --dry-run` successfully against the render target, and the user has the render command plus every side-channel command |

Between phases, summarize what was built and get an explicit overall confirmation before continuing — the full feature list and module/concept layout after Phase 1; the tech stack and architecture after Phase 2; the testing strategy (config files, scripts, framework, test types, conformance/prepare-environment decisions) after Phase 3.

## Adding features later

Once the initial specs exist, the user will return with new features. Use the `add-feature` skill — the same interview → author → review loop scoped to a single feature on an existing `.plain` file. Keep framing the work as updating the specs, not the generated code.

## Question style

- Prefer short, direct sentences over compound or nested clauses.
- Use plain words over jargon when both convey the same meaning.
- One idea per sentence; split a comma-chained list of clauses into separate sentences.
- Never drop detail to simplify — keep every constraint, edge case, option, and piece of context the user needs to answer accurately, splitting into more sentences instead.

## Error handling

- **A user answer contradicts prior specs** → edit the affected snippet in place immediately, then continue the loop; surface a non-trivial change in the next question.
- **A phase gate is not met** (specs not on disk, or not explicitly approved) → do not advance; finish the open phase first.
- **`check-plain-env` returns `FAIL`** (Phase 3) → walk each gap with the user; install, swap to an alternative, or explicitly acknowledge it before Phase 4. Re-invoke after any install.
- **`plain-healthcheck` returns `FAIL`** (Phase 4) → do not present the render command; work through its numbered list with the right edit skill and re-run until it passes.
- **Environment failure** (`codeplain` not on PATH, `CODEPLAIN_API_KEY` unset) → tell the user exactly what is missing and how to fix it; never pretend the check passed.

## Reference

- Full `***plain` language guide: `PLAIN_REFERENCE.md`.
- Spec-editing skills live in `.claude/skills/`.
- Templates go in `template/`, but import paths omit the `template/` prefix. Resources go in `resources/`.
- Generated code lands in `plain_modules/` (read-only, never edit). Test scripts live in `test_scripts/`.
