# CLAUDE.md

## Quickstart Workflow: QA Session → \*\*\*plain Specs

When the user starts a new session or asks to build something, run the **QA workflow** below. The goal is to gather enough information through a structured conversation to produce complete `***plain` specification files.

**Do not skip ahead.** Complete each phase before moving to the next. Ask follow-up questions within each phase until you have clear, unambiguous answers. Summarize what you've captured at the end of each phase and get explicit confirmation before proceeding.

### Your tools

**AskUserQuestion** — use this tool to ask the user structured, multiple-choice questions during interviews. Group related gaps into batches of 3–5 questions. Each question should have a clear prompt and concrete answer options. Use it whenever you need insider knowledge from the user. After the structured questions, always follow up with a free-form prompt so the user can add anything not covered by the options.

---

### Phase 1 — What are we building?

Understand the product at a high level. Ask the user:

1. **What is the app?** — One-sentence description. What problem does it solve?
2. **Who uses it?** — Target users or personas. Is it a CLI tool, web app, API, desktop app, mobile app, library, or something else?
3. **What is the scope?** — Is this an MVP, a prototype, or a full product? What is explicitly out of scope?

Keep going until you can write a one-paragraph summary of the product. Read it back to the user for confirmation.

---

### Phase 2 — What technologies should it use?

Gather the technical stack. Ask the user:

1. **Programming language** — e.g. Python, TypeScript, Java, Go.
2. **Frameworks** — e.g. Flask, Next.js, Spring Boot, Express.
3. **Data storage** — e.g. PostgreSQL, SQLite, file-based, in-memory, none.
4. **External services or APIs** — anything the app talks to.
5. **Testing framework** — e.g. pytest, Jest, JUnit. If the user has no preference, suggest one that fits the language.
6. **Other constraints** — deployment target, OS requirements, performance needs, coding standards.

These answers will feed into `***implementation reqs***` and `***test reqs***`. Summarize the tech stack and confirm.

---

### Phase 3 — How does the app work?

This is the most important phase. Drill into the behavior of the app:

1. **Core entities** — What are the main "things" in the system? (Users, Tasks, Orders, Messages, etc.) What attributes does each have? What are the relationships?
2. **Key features** — List every distinct thing the app should do. For each feature:
   - What triggers it? (user action, API call, scheduled event)
   - What is the expected outcome?
   - What are the edge cases or validation rules?
3. **User flows** — Walk through the app from the user's perspective. What happens first? What happens next? What are the decision points?
4. **Constraints and rules** — Business rules, validation, permissions, error handling behavior.
5. **Acceptance criteria** — For critical features, what concrete outcomes prove it works correctly?

Keep asking follow-ups until every feature is specific enough to be a single functional spec (implying ≤200 lines of code change each). If a feature is too large, break it down together with the user.

Summarize the full feature list and confirm.

---

### Phase 4 — Write the \*\*\*plain specs

Once all three phases are confirmed, produce the `.plain` specification files. Follow these steps:

#### 4a. Plan the module structure

Decide how to organize the specs:

- **Single module** — for small apps where everything fits in one `.plain` file.
- **Template + modules** — create a shared template (import module) in `template/` for the tech stack, then one or more modules that import it.
- **Chained modules** — use `requires` when the app has a clear build order (e.g. base → features → integrations).

State the plan and confirm with the user.

#### 4b. Create the template (if needed)

If using a template, create an import module in `template/` containing:

- `***definitions***` — shared concepts used across modules.
- `***implementation reqs***` — language, framework, architecture, coding standards.
- `***test reqs***` — testing framework, execution commands, testing constraints.

Use the `create-import-module` skill. The template must **not** contain `***functional specs***`.

#### 4c. Create the module(s)

For each module, create a `.plain` file with:

1. **YAML frontmatter** — `import` and/or `requires` references, description.
2. **`***definitions***`** — all concepts (entities, attributes, relationships) from Phase 3. Define every concept before referencing it. Use the `add-concept` skill for each.
3. **`***implementation reqs***`** — technology choices and constraints from Phase 2 that are specific to this module (if not already in the template).
4. **`***test reqs***`** — testing requirements specific to this module (if not already in the template).
5. **`***functional specs***`** — the features from Phase 3, translated into chronological, incremental specs. Use the `add-functional-requirement` skill for each. Follow these rules:
   - Each spec implies ≤200 lines of code change.
   - Specs are in chronological build order (entry point first, then features layer by layer).
   - No conflicts between specs.
   - Language-agnostic — behavior only, no implementation constructs.
   - Short, clear sentences.
6. **`***acceptance tests***`** — add under functional specs that need concrete verification. Use the `add-acceptance-test` skill.

#### 4d. Review

After writing all specs:

1. Read back each `.plain` file in full.
2. Check for: missing concept definitions, spec conflicts, specs that are too complex, language-specific leaks in functional specs, correct chronological ordering.
3. Present the final specs to the user for approval.
4. If the user requests changes, apply them and re-review.

---

### Adding features to an existing project

Once the initial specs are written, the user will come back with new features. Use the `add-feature` skill for this — it runs the same interview → implement → review loop but scoped to a single feature against an existing `.plain` file. This keeps the conversation continuous: the user describes a feature, you ask clarifying questions, write the specs, and repeat.

---

### Reference

- Full `***plain` language guide: [PLAIN_REFERENCE.md](PLAIN_REFERENCE.md)
- Skills for editing specs are in `.claude/skills/`
- Templates go in `template/`, resources in `resources/`
- Generated code lands in `plain_modules/` (read-only, never edit)
- Test scripts are in `test_scripts/`
