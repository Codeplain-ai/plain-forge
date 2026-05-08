# Project Guidelines

## Reference documents

- [`.claude/docs/PLAIN_REFERENCE.md`](.claude/docs/PLAIN_REFERENCE.md) — full syntax and semantics of the ***plain spec language. Consult this whenever you author or edit `.plain` files.
- [`PRD_Dynamics365.md`](PRD_Dynamics365.md) — product requirements for the Dynamics 365 integration.
- [`Technical_Documentation_Dynamics365.md`](Technical_Documentation_Dynamics365.md) — technical documentation for the Dynamics 365 integration.

## Question style for `/forge-plain` and `/add-feature`

When running the `/forge-plain` or `/add-feature` skills, the questions you put to the user must use simple grammatical structures:

- Prefer short, direct sentences over compound or nested clauses.
- Use plain words over jargon when both convey the same meaning.
- One idea per sentence. If a sentence needs a comma-separated list of clauses, split it.

Simpler grammar must not come at the cost of detail. Keep every constraint, edge case, option, and piece of context the user needs to answer accurately. If simplifying a sentence would drop a detail, split it into more sentences instead.
