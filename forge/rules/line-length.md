---
description: Line-length and bullet-continuation rules for every section in .plain files
---

# Rules for line length in `.plain` files

These rules apply to **every** section — `***definitions***`, `***implementation reqs***`, `***test reqs***`, `***functional specs***`, `***acceptance tests***` — and to concept explanations alike.

## Hard limit: 120 characters per line
- If a line exceeds 120 characters, split it at a natural clause boundary into nested `- ` bullets
- Concision is in service of clarity, never the other way around — wordy-but-precise always beats terse-but-ambiguous
- Prefer short, direct sentences and plain words; if a 10-cent word and a 50-cent word say the same thing, use the 10-cent one

## Never use bare continuation lines (invalid ***plain syntax)
- ***plain syntax requires every line inside a section to be its own list item starting with `- `
- Indented continuation lines without a leading `- ` are syntactically invalid — they look reasonable to a human reader but the renderer cannot parse them
- When a sentence is too long, **break it into multiple bullet items**, each on its own line, nested under the parent bullet so the meaning stays grouped

## Examples

BAD — line is too long:

```plain
***functional specs***

- :GatewayWebhook: hands off :StripeRequest: to :StripeIntegration:.handle(), which returns a list of :EventEnvelope: dicts conforming to the gateway's contract.
```

WRONG SYNTAX (AVOID AT ALL COSTS) — bare indented continuation without a leading `- `:

```plain
***functional specs***

- :GatewayWebhook: hands off :StripeRequest: to :StripeIntegration:.handle(),
  which returns a list of :EventEnvelope: dicts conforming to the gateway's
  contract.
```

GOOD — split at a natural clause boundary into nested `- ` bullets:

```plain
***functional specs***

- :GatewayWebhook: hands off :StripeRequest: to :StripeIntegration:.handle()
  - The method returns a list of :EventEnvelope: dicts.
  - The dicts must conform to the gateway's :EventEnvelope: contract.
```

## What never goes inline
- Long URLs, schema fragments, or example payloads — those belong in `resources/` per [`linked-resources.md`](linked-resources.md)
- If you find yourself pasting a multi-line block into a spec line, stop and link the file instead

## Presenting `.plain` examples
- Show every example snippet under its owning section header — e.g. `***functional specs***`, `***definitions***` — so the reader can see which section the lines belong in
- Separate top-level `- ` items with a single blank line; keep nested `- ` clarifications directly under their parent with **no** blank line between parent and child
- These conventions apply to canonical / "good" / "after" / "acceptable" example blocks; BAD / WRONG / `Before:` / `Too complex:` blocks show the header too but may otherwise deviate (that is the point of showing them)
