---
description: Conciseness and plain-language rules that keep .plain specs reviewable by a human
---

# Rules for keeping `.plain` specs concise

These rules apply to every section, to concept explanations, and to acceptance tests.

## Why this matters

- A spec is the source of truth, so a human has to be able to review it
- A long, dense, or ornate spec is skipped rather than reviewed — an unreviewed spec is an
  unverified spec, however correct it happens to be
- Length is not a proxy for rigor: a spec earns trust by being checkable, not by being thorough-looking
- Conciseness is about removing what carries no information, never about removing required detail —
  the deterministic-interface, disambiguation, and testability rules always win (see `func-specs.md`)

## Do not write the obvious

Delete any line a competent reader would already assume. Ask of every line: *if this were missing,
would anything be built differently?* If not, cut it.

Do not write:

- Restatements of a concept's own name (`:UserEmail: is the email address of a :User:.` adds nothing
  beyond what `definitions.md` already requires the concept to carry)
- Universal software defaults: that invalid input is rejected, that errors are reported, that data is
  saved when saving is the point of the operation
- Rationale, motivation, benefits, or background — the spec states what is, not why it was chosen
- Standard behavior of a technology already named in `***implementation reqs***` (an HTTP framework
  parses HTTP; a database driver opens connections)
- Restatements of a nearby bullet in different words, or of anything already stated in an `import`ed
  or `require`d module
- Anything about work the spec is not about ("no changes to the existing UI")
- Meta-commentary about the spec itself ("this spec is intentionally small", "as described above")

BAD — three bullets, one fact:

```plain
***functional specs***

- In order to provide users with a robust and seamless experience, :TaskService: exposes a comprehensive endpoint for the creation of new :Task: items.

- The endpoint accepts a request and, provided that the incoming payload is valid and well-formed, proceeds to persist the :Task: appropriately.

- If the payload is not valid, an appropriate error is returned to the caller so that the user is informed of the problem.
```

GOOD — one bullet, same information, plus the interface detail the BAD version never pinned down:

```plain
***functional specs***

- A :User: can create a :Task: via `POST /tasks`.
  - The request body is a :Task: without `id`.
  - The response is `201` with the created :Task:.
  - A request without a name returns `400`.
```

## Use plain words

- Prefer the shortest word that is still exact; a technical term is exact, an elaborate one is not
- Write short sentences: one clause plus, at most, one qualifier
- Use the same word for the same thing every time — synonym variety reads as two different things
- Do not use adverbs and adjectives that no test can check: `robust`, `seamless`, `efficient`,
  `scalable`, `comprehensive`, `modern`, `properly`, `gracefully`, `as appropriate`, `where
  applicable`, `best practices`. Either state the checkable fact (`a response is returned within 200 ms`)
  or delete the word
- Do not hedge: `should ideally`, `may optionally`, `typically`, `generally`, `if possible`. A spec
  states one behavior; a hedge tells the renderer to guess

| Do not write | Write |
|---|---|
| utilize, leverage | use |
| facilitate, enable the ability to | let, or name the action |
| in order to | to |
| prior to / subsequent to | before / after |
| in the event that | if |
| is responsible for handling | handles |
| performs the validation of | validates |
| a plurality of | several, or a number |
| terminate, initiate | stop, start |
| functionality for X | X |

## Keep the shape small

- One statement per bullet, one bullet per fact (see `bullet-continuation.md`)
- Nest a sub-bullet only to remove a real ambiguity; a sub-bullet that merely elaborates is filler
- If a bullet needs more than about five sub-bullets to be unambiguous, it is not an ambiguity
  problem but a size problem — for a functional spec, run `analyze-if-func-spec-too-complex` and
  then `break-down-func-spec`
- Never restate a parent bullet in its own sub-bullets
- Tables, prose paragraphs, and code blocks do not belong in a section; external artifacts are
  linked from `resources/` (see `linked-resources.md`)

## Review pass before writing to disk

Read the drafted lines once more and apply, in order:

1. **The deletion test** — cut every line whose removal would change nothing about what gets built
2. **The word test** — replace every ornate word with a plain one, and delete every uncheckable adjective, adverb, and hedge
3. **The duplication test** — cut anything already stated in this file, an `import`, or a `requires` chain
4. **The read-aloud test** — a line you cannot read aloud in one breath is either two facts or one padded one

If a cut would remove an interface detail, a boundary case, or a disambiguation, keep the fact and
shorten the wording instead.
