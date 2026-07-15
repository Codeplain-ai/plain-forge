# Phase 1 — What are we building?

Understand the product. This is the most important phase; do it thoroughly and drill into the app's behavior. Run the core loop (ask → author → review) from `SKILL.md` for each topic below, in order. This phase is incremental and one-question-at-a-time — never ask everything up front and write all the specs at the end.

## Author targets for this phase

The moment the user answers, write the resulting snippet to disk using the right skill:

- **Module structure** — create or update the `.plain` file(s) (single module, template + modules, or chained modules). Set up YAML frontmatter (`import`, `requires`, `description`) and the proposed module name. If a template is used, create it in `template/` **without** a `***functional specs***` section. Use the `create-import-module` skill where applicable.
- **`***definitions***`** — add or refine concepts (entities, attributes, relationships). Define every concept before it is referenced. Use the `add-concept` skill.
- **`***functional specs***`** — translate each answer into a single chronological, incremental spec (≤200 lines of code change, language-agnostic, no conflicts). Use `add-functional-spec` for one new spec; use `add-functional-specs` only when a single answer naturally decomposes into a tight cluster of specs flowing from the same answer (e.g. list / create / delete CRUD on one entity). **Never hand-author the `***functional specs***` section directly.**

Do **not** add `***implementation reqs***`, `***test reqs***`, or `***acceptance tests***` in this phase — they belong to later phases.

## Topics (in order)

1. **What is the app?** — one sentence: what problem does it solve? Free-form, not multiple choice. Author a stub `.plain` file with the description in the YAML frontmatter and the proposed module name. Review the frontmatter and the module split.
2. **Who uses it?** — target users or personas; is it a CLI tool, web app, API, desktop app, mobile app, library, or something else? Author any user/persona concepts that emerge. Review those concepts.
3. **What is the scope?** — MVP, prototype, or full product? What is explicitly out of scope? Tighten the description and, if needed, split modules to keep MVP scope cohesive. Review the resulting module structure.
4. **Core entities** — the main "things" in the system (Users, Tasks, Orders, Messages, …), their attributes, and relationships. Author one concept per entity in `***definitions***`. Review each concept snippet.
5. **Key features** — every distinct thing the app should do. For each feature capture the trigger, the expected outcome, and edge cases / validation rules. Author one or more functional specs per feature, in chronological build order, each ≤200 LOC. Break large features into smaller specs together with the user. Review each new functional spec (or tight group of related specs).
6. **User flows** — walk through the app from the user's perspective: what happens first, what happens next, and at each decision point. Author the ordering and any missing intermediate functional specs. Review the affected sequence of specs.
7. **Constraints and rules** — business rules, validation, permissions, error-handling behavior. Fold these into the relevant functional specs, and add concepts where they are first-class entities (e.g. roles). Review the updated specs.
8. **User interface (optional)** — skip entirely if the project has no UI. Otherwise ask, one question per iteration:
   - How does the UI look and feel?
   - Where are the key UI elements located?
   - What do the key UI elements do?
   - What is the layout and design of the UI?

   Author UI-behavior functional specs (still language- and framework-agnostic). Review those specs.
9. **Anything else** — anything the user wants to add or change that hasn't already been covered.

Keep asking follow-ups within a topic until every feature is specific enough to become a single functional spec (implying ≤200 lines of code change each). If a feature is too large, break it down together with the user before authoring.

When all topics are complete, summarize the full feature list and the final module/concept layout, and get an explicit overall confirmation before moving to Phase 2.
