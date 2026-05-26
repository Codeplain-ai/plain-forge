---
description: Rules for authoring ***plain specs for REST API integrations
globs: "**/*.plain"
---

# Rules for writing integration specs in `***plain`

When writing or editing a `.plain` file that describes an **integration** against a REST API (synchronous JSON/HTTP request-response plus webhook callbacks), always follow these rules. Non-REST integrations (gRPC, GraphQL, SOAP, message brokers, raw TCP, file drops) are out of scope of these rules.

## Scope of "integration" specs
- An integration `.plain` module describes how the project talks to a **third-party or internal REST API**
- The integration may be **embedded** (lives as a library/module inside an existing host codebase) — see [`integration-embedded.md`](integration-embedded.md) for the additional rules that apply
- Or **standalone** (a service, daemon, CLI, scheduled job, or container) — see [`integration-standalone.md`](integration-standalone.md) for the additional rules that apply
- The contract surface, edge-case coverage, live-API cross-check, and `resources/` layout described below apply to **both** shapes — the shape-specific rule files add to them, never replace them

## Contract artifacts live in `resources/` (hard rule)

**Every structural contract the integration deals with — endpoint definitions, request/response schemas, error envelopes, webhook payloads, pagination envelopes, rate-limit headers, the integration's own I/O contract — lives in `resources/` as a linked resource.** Concepts and functional specs **reference** these files; they never restate fields, types, status codes, or header names inline.

Pick the right format per artifact:

| Artifact | Format | Conventional path |
|----------|--------|-------------------|
| Provider's REST surface | OpenAPI 3.1 (YAML or JSON) | `resources/<provider>.openapi.yaml` |
| Webhook payload (per event type) | JSON Schema Draft 2020-12 | `resources/webhooks/<event>.schema.json` |
| Rich webhook contracts (multi-channel) | AsyncAPI 2.6+ | `resources/webhooks.asyncapi.yaml` |
| Integration's own I/O contract | JSON Schema or OpenAPI | `resources/contract/<entry-point>.schema.json` |
| Configuration surface | JSON Schema | `resources/config.schema.json` |
| Error code → category mapping | YAML enum | `resources/error-map.yaml` |
| Rate-limit header inventory | YAML enum | `resources/rate-limit-headers.yaml` |
| Retry policy parameters | YAML enum | `resources/retry-policy.yaml` |
| Captured probe responses | Raw JSON | `resources/fixtures/<endpoint>.<case>.json` |

Rules that flow from this:

- **Concepts carry references, not data.** An endpoint concept names the endpoint and points at its OpenAPI `paths.<path>.<method>` entry; it does not duplicate the request/response shape in concept attributes. Same for webhook concepts, error-model concepts, pagination concepts, etc.
- **Functional specs consume linked resources.** A spec describes **behavior** ("call endpoint X, parse the response, classify errors, retry on 5xx") and links to the resource that supplies the **shape**. Field names, types, and validation rules live in the resource file.
- **Schemas are versioned by file path.** When the provider releases a new API version, copy the new OpenAPI file to a new path (e.g. `resources/<provider>.v2.openapi.yaml`); never mutate the v1 file in place.
- **The renderer generates language-native types from the resources.** For embedded integrations the renderer reads JSON Schema / OpenAPI components and emits Pydantic / TypeScript / Go types in `plain_modules/`. The spec declares **which** schema to generate from, **where** the generated type should land, and **what host base class** it must subclass — but never restates the schema's fields.

A single `.plain` module can (and typically will) reference many resources. That is the intended pattern; do not try to collapse them into one mega-file.

## Live API must be cross-checked against the documentation

Documentation lies — it goes stale, omits undocumented fields, describes a different API version, papers over breaking changes. Every integration spec must be grounded in what the API really returns, not what the docs claim it returns.

- **Validate credentials against the live API** before authoring downstream specs. A 2xx on a low-risk read-only endpoint (`/v1/me`, `/account`, `/whoami`, `/health`) is the gate. On 401/403, stop and resolve before continuing.
- **Issue the minimum cross-check coverage** with `fetch`: one discovery / schema endpoint if available, one list endpoint per primary entity in scope, one single-object retrieval per primary entity, one empty/boundary response, one 404, one 400/422, and one deliberate 401.
- **Save every probe response under `resources/fixtures/`** with credentials redacted. The fixtures become the seed for `resources/<provider>.openapi.yaml` and feed conformance tests later.
- **Every discrepancy is recorded, not smoothed over.** Each finding goes into the relevant resource (the OpenAPI file, the error envelope schema, `rate-limit-headers.yaml`, …) as the source of truth, with a short note in the corresponding concept saying "docs claim X, live API returns Y; we follow the live API".
- **Only `GET` / `HEAD` / `OPTIONS` on the cross-check.** Mutating calls (`POST`, `PATCH`, `PUT`, `DELETE`) require explicit per-call user confirmation and must target a sandbox account.
- **Credentials are never written to `.plain` files or summaries.** Reference them by env-var name only.

## Embedded vs standalone — pick the shape early

Every integration is either **embedded** (lives as a library/module inside an existing host codebase) or **standalone** (a service, daemon, CLI, scheduled job, or container). The choice is captured as a concept (`integration-shape: embedded | standalone`) so later specs can reference it.

The contract artifact itself is **identical** across both shapes: a JSON Schema (or OpenAPI) file under `resources/contract/`. What changes is **what the renderer emits from it** and **what extra context the spec carries**:

- **Embedded** → the renderer generates a host-language class from the schema and wires it into the host's import path. The host codebase dictates the tech stack — see [`integration-embedded.md`](integration-embedded.md) for the full ruleset
- **Standalone** → the renderer treats the schema as the public artifact: it generates an internal implementation in `plain_modules/` and ships the schema verbatim for external consumers. The integration owns its stack — see [`integration-standalone.md`](integration-standalone.md) for the full ruleset

## Edge-case coverage is a hard floor, not a stretch goal

A production-ready integration spec captures every corner case the API can throw at the integration. Each of the following must be in the specs (or explicitly recorded as "not applicable" / "not in scope" with the user's acknowledgement) before the integration is considered complete:

- **Provider, purpose, canonical documentation URL(s)** as concepts
- **Endpoints in scope** in `resources/<provider>.openapi.yaml`, one `paths.<path>.<method>` entry per endpoint; endpoint concepts link to the OpenAPI entry
- **Auth scheme**, credential source pinned by env-var name, refresh policy, scopes — with `components.securitySchemes` in the OpenAPI matching
- **Environments** (sandbox / staging / production) and the switch mechanism — reflected in `servers` of the OpenAPI file
- **API version pinning** strategy (URL path, header, `Accept`, query string) and the deprecation policy
- **Request serialization** (content type, date format, numeric precision, custom headers) in `components.schemas` / `components.parameters`
- **Pagination model** as `components.schemas.PageEnvelope` plus `resources/pagination.yaml` (style, defaults, safety cap)
- **Rate-limit model** as `resources/rate-limit-headers.yaml` + `resources/rate-limits.yaml` + `components.schemas.RateLimitError`
- **Error model** as `components.schemas.ErrorEnvelope` + `resources/error-map.yaml`, with one functional spec per error category
- **Retry policy** in `resources/retry-policy.yaml`
- **Idempotency strategy** in `resources/idempotency.yaml` + idempotency header in `components.parameters`
- **Webhook contracts** as `resources/webhooks/<event>.schema.json` per event type + `resources/webhook-signing.yaml`
- **Data mapping** (entity schemas + transformations / exclusions) as entity schemas + `resources/data-mapping.yaml`
- **Compliance / data-sensitivity** constraints (PII, PHI, payment data, data residency, log redaction, audit logs)
- **Observability** (log fields, provider request IDs, metrics, tracing propagation)

## Anti-patterns (do not do these)

- **Restating an OpenAPI / JSON Schema field list in a concept or functional spec.** The schema lives in `resources/`; the spec links to it
- **Pasting a webhook payload, error envelope, or list-endpoint response inline.** Save it as a fixture under `resources/fixtures/` and link the fixture
- **Inlining a host base class body into the contract spec.** Add the host file as a linked resource under `resources/host/` and reference it by FQN
- **Embedding credentials, tokens, or signing keys in a `.plain` file or in a summary** — credentials are referenced by env-var name only
- **Authoring against unverified credentials.** Validate first; if the user has no credentials yet, flag it in the module's frontmatter description and re-validate once credentials arrive
- **`requires`-ing a separate-stack module** (a Python backend `requires`-ing a React frontend, or vice versa) — see [`requires-modules.md`](requires-modules.md). Use a shared API schema in `resources/` instead
- **Authoring Phase 1 specs from the docs first and "reconciling" with the live API later.** Probe the API as you reach each topic; the live response is the source of truth from the moment it's captured
