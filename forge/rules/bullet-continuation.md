---
description: Bullet and continuation syntax for every section in .plain files
---

# Rules for bullets and continuations in `.plain` files

These rules apply to every section and to concept explanations.

## No line-length limit

- `.plain` does not impose a maximum number of characters per line
- Do not split a valid line merely to satisfy an arbitrary formatting width
- Prefer clear, precise wording; concision must never remove required detail

## Never use bare continuation lines

- Every line inside a section must be a list item beginning with `- `
- An indented continuation without `- ` is invalid syntax
- If content is intentionally separated across lines, express the additional lines as nested
  bullet items so each line remains syntactically valid

WRONG — bare continuation lines:

```plain
***functional specs***

- :GatewayWebhook: hands off :StripeRequest: to :StripeIntegration:.handle(),
  which returns a list of :EventEnvelope: dicts conforming to the gateway contract.
```

GOOD — one valid list item:

```plain
***functional specs***

- :GatewayWebhook: hands off :StripeRequest: to :StripeIntegration:.handle(), which returns a list of :EventEnvelope: dicts conforming to the gateway contract.
```

BEST — separate clarifications expressed as nested bullets:

```plain
***functional specs***

- :GatewayWebhook: hands off :StripeRequest: to :StripeIntegration:.handle().
  - The method returns a list of :EventEnvelope: dicts.
  - The dicts conform to the gateway's :EventEnvelope: contract.
```

## Presenting `.plain` examples

- Show every example under its owning section header
- Separate top-level list items with one blank line
- Keep nested clarifications directly under their parent without a blank line
- BAD, WRONG, `Before:`, and `Too complex:` examples may intentionally demonstrate invalid syntax

## Content that belongs in resources

Long URLs, schema fragments, and example payloads belong in `resources/` because they are external
artifacts, not because of their character count. Follow `linked-resources.md`.
