# Forge Plain Workflow Checklist

Use this to verify the workflow was followed — never as a substitute for it. Run the relevant block **before advancing out of each phase**, and run the whole list once more before handing off. A box only counts as met when the spec is on disk and explicitly approved, not merely discussed. If a box is unmet, go back and complete the step; do not advance.

## Every loop iteration (Phases 1–3)

- [ ] Asked exactly one focused question via `AskUserQuestion` — not two bundled together.
- [ ] Wrote the snippet to disk immediately after the answer, using the dedicated edit skill — never hand-authored a `***plain` section directly.
- [ ] Reviewed only what just changed (missing parts / extensions / ambiguities), applied the response back to disk, and got explicit approval before moving on.
- [ ] Any answer that contradicted an earlier snippet was fixed in place before the next question — no stale spec left on disk.
- [ ] Stayed within the current phase — no drafting or multi-question detours into later-phase content.

## Phase 0 — Setup

- [ ] Invoked `load-plain-reference` first (unless already loaded this session).

## Phase 1 — What are we building?

- [ ] Read `references/phase-1-product.md` and walked its topics in order (app, users, scope, entities, features, flows, constraints, UI if any, anything else) — skipped topics called out explicitly.
- [ ] `.plain` module structure created with YAML frontmatter; template (if any) has no `***functional specs***`.
- [ ] Every concept authored in `***definitions***` via `add-concept`, defined before use.
- [ ] Every feature authored as functional specs via `add-functional-spec(s)`, each ≤200 LOC, in chronological build order.
- [ ] No `***implementation reqs***`, `***test reqs***`, or `***acceptance tests***` written in this phase.
- [ ] Summarized the full feature list and module/concept layout; got explicit overall confirmation.

## Phase 2 — What tech should it use?

- [ ] Read `references/phase-2-tech.md` and walked its topics in order (language, frameworks, storage, external services, structure/architecture, other constraints, anything else).
- [ ] Every requirement authored into `***implementation reqs***` at the right scope (shared → template, module-specific → module).
- [ ] No `***test reqs***` or `***acceptance tests***` written in this phase.
- [ ] Summarized the tech stack and architecture; got explicit overall confirmation.

## Phase 3 — How is testing done?

- [ ] Read `references/phase-3-testing.md`; stated the planned `config.yaml` split (one per part) and confirmed it before topic 1.
- [ ] Honored the hard partition — every `:UnitTests:` fact in `***implementation reqs***`, every `:ConformanceTests:` fact in `***test reqs***`; never shared a bullet.
- [ ] Walked topics in order (unit framework, unit types/architecture, conformance decision, prepare-environment decision, layout, execution, other constraints, anything else).
- [ ] Generated the needed scripts under `test_scripts/` via the `implement-*-script` skills and added each `*-script:` entry to the right `config.yaml`.
- [ ] Conformance decision was asked explicitly; if yes, walked every Phase-1 functional spec one at a time for acceptance tests via `add-acceptance-test`.
- [ ] Prepare-environment decision was asked explicitly and recorded.
- [ ] Recapped the testing strategy; got explicit overall confirmation.
- [ ] Ran `check-plain-env`; it returned `PASS`, or `WARN`/`FAIL` with each remaining item explicitly acknowledged by the user (re-invoked after any install).

## Phase 4 — Validate and hand off

- [ ] Identified the render target — the last module in the dependency chain (or the single module).
- [ ] Ran `init-config-file` to build the final `config.yaml`(s); resolved any precondition gap with the user before validating.
- [ ] Ran `plain-healthcheck`; worked its numbered list to `PASS` — never presented the render command on a `FAIL`.
- [ ] Presented the render command only after the dry-run passed, plus every side-channel script actually generated in Phase 3.
