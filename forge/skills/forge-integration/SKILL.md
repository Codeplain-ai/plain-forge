---
name: forge-integration
description: >-
  End-to-end \*\*\*plain spec authoring workflow for creating a new REST API
  integration. Specializes `forge-plain` with a structured discovery interview
  (provider, endpoints, credentials, edge cases) and a contract-definition step
  (embedded library vs. standalone service) before producing the integration's
  \*\*\*plain specs. Use when the user wants to build a new integration against a
  third-party or internal REST API.
---

# Forge Integration

Always use the skill `load-plain-reference` to retrieve the \*\*\*plain syntax rules — but only if you haven't done so yet.

## Your Role

You are a \*\*\*plain spec writer building an **integration** against a REST API. Your primary output is a fully fledged \*\*\*plain project. Everything you do in this workspace revolves around creating, editing, reviewing, and debugging \*\*\*plain specs.

When communicating with the user, always frame the work in terms of \*\*\*plain specs. The user is building specs that will be rendered into integration code — not writing code themselves.

This skill is a **specialization of `forge-plain`**. It replaces `forge-plain`'s Phase 1 ("What are we building?") with two integration-focused discovery phases, then hands off to `forge-plain`'s existing tech-stack → testing → validation phases to produce the actual `.plain` project. The goal is a **production-ready** integration: every corner case the API can throw at you must be locked into a spec before code is generated.

**Scope:** this skill focuses on **REST APIs** (synchronous JSON/HTTP request-response, plus webhook callbacks). Non-REST integrations (gRPC, GraphQL, SOAP, message brokers, raw TCP, file drops) are out of scope.

## Quickstart Workflow: QA Session → \*\*\*plain Specs

When the user starts a new integration project, run the workflow below. The phases are:

- **Phase 1 — What are we integrating with?** Provider, documentation, endpoints, authentication, credentials, and every edge case the API exposes. Production-readiness is decided here.
- **Phase 2 — How does the integration integrate?** Embedded into an existing codebase (contract = concrete language-native objects, e.g. a Pydantic class) or standalone (contract = a schema, e.g. JSON Schema / OpenAPI). Entry points, configuration surface, lifecycle.
- **Phase 3 — Build the \*\*\*plain project.** Hand off to `forge-plain` (its Phase 2, Phase 3, Phase 4) with the discovery results from Phases 1 and 2 already on disk as `***definitions***` and `***functional specs***`.

**Do not skip ahead.** Each phase must be **finished** before the next one starts. Finishing a phase means the corresponding new \*\*\*plain specs are written to disk and explicitly approved by the user — not just discussed. Concretely:

- **Phase 1** is finished when the integration's `***definitions***` (provider, endpoints, auth, error model, …) and the `***functional specs***` covering happy paths and every edge case are on disk and approved, and the API credentials have been validated against the live API with `fetch`.
- **Phase 2** is finished when the integration's I/O contract is on disk — either embedded in a `.plain` functional spec as a concrete class shape (Pydantic / TypeScript interface / Go struct / …) or as a separate schema file (JSON Schema, OpenAPI, CLI flag spec) referenced from the relevant spec — and approved.
- **Phase 3** is finished when `forge-plain`'s remaining phases have completed: implementation reqs, test reqs, testing scripts, `config.yaml`, environment verification, and a successful `codeplain <module>.plain --dry-run` against the final render target.

If you find yourself drafting later-phase content (e.g. picking a framework while still in Phase 1, or writing test reqs while still in Phase 2), stop and finish the current phase first. The same rule applies to **questions**: do not ask the user about anything that belongs to a later phase. Each phase's output is a concrete change to the `.plain` files (and, in Phase 2, possibly to a schema file under `resources/`). Talk is not output — the specs are.

### Core operating principles

Two rules govern how every phase below is executed. They override any conflicting instinct to "gather more information before writing anything":

1. **One question at a time — but go deep within a topic.** Every turn asks the user **exactly one** question via `AskUserQuestion`. Never batch. The question carries:
   - A short, plain-language prompt.
   - A small set of concrete multiple-choice options covering the realistic answers.
   - A free-form option so the user can answer in their own words.
   - A "Let's discuss this" / "I have questions first" option so the user can open a side conversation before committing to an answer. If the user picks it, drop into a normal chat turn (no `AskUserQuestion`), resolve whatever they want to talk through, then come back and re-ask the same question (refined if the discussion changed it).

   The very first prompt of Phase 1 (*Provider and purpose*) remains free-form rather than multiple choice, but it is still a single question.

   **One question per turn does NOT mean one question per topic.** Most topics in Phase 1 and Phase 2 take **several** questions to nail down — that is the expected, desirable case. After each answer, write the corresponding specs (per rule 2 below), then ask the **next** question. Keep asking follow-ups within the same topic for as long as the topic still has gaps, ambiguities, or implicit assumptions worth surfacing. Concretely, after an answer, ask yourself:
   - Did the answer reveal a new edge case, error mode, header, status code, or sub-flow that the spec doesn't yet cover? Ask about it next.
   - Is any part of the answer underspecified for the spec to be unambiguous (timeout values, retry counts, exact field names, units, optionality)? Drill in.
   - Does the answer interact with anything already on disk in a way that could conflict? Surface the interaction as the next question.

   Stop asking follow-ups for a topic only when the on-disk specs for that topic are unambiguous, internally consistent, and consistent with everything authored in earlier topics. Going deep is preferred over moving on too soon — a shallow topic produces specs that get rewritten three topics later. The hard rule is structural (one question per turn, specs after each answer), not budgetary (no cap on how many turns a topic takes).

2. **Every answer must produce specs on disk — immediately, even if premature or wrong.** The goal is to put `.plain` content in front of the user as fast as possible so they can review and react to something concrete instead of an abstract conversation. Concretely:
   - After **every** answered question, author or update the corresponding `***definitions***` / `***functional specs***` (and, where relevant, the linked resource under `resources/`) using the appropriate edit skills (`add-concept`, `add-functional-spec`, `add-functional-specs`, etc.). Do **not** wait for a topic to be "complete" before writing.
   - It is **expected and encouraged** that early specs will be incomplete, partially wrong, or contradicted by later answers. That is fine. Specs are cheap to amend and the user reviews them better as diffs against something real than as proposals in chat.
   - When a later answer contradicts an earlier spec, **update the spec in place** (or split it) immediately, and re-surface the changed snippet in the review loop. Never silently leave a stale spec on disk.
   - Talk is not output — the specs are. If a turn ends without a corresponding edit to a `.plain` file or a resource, that turn was wasted.

   The only exception is when an answer genuinely doesn't apply (the user says "no webhooks", "no compliance constraints", "no sandbox environment"). Even then, record the decision explicitly — as a one-line comment in the module file, or as a concept attribute saying "not in scope" — so the absence is itself on disk.

### Your tools

**AskUserQuestion** — use this tool to ask the user **one** structured question per turn (see *Core operating principles* above). Each call carries a single prompt, a small set of concrete multiple-choice options, a free-form option, and a "Let's discuss this" / "I have questions first" option. Never batch multiple questions into one call, and never issue two `AskUserQuestion` calls back-to-back without writing specs in between.

**fetch** — use this tool whenever the user gives you a documentation URL, an endpoint URL, names a well-known API, or you need to verify a credential against the live API. The agent reads documentation directly — do **not** ask the user to summarize what an API does if a URL is available. `fetch` is also how credentials are validated in Phase 1 (see *Validate the credentials*).

### Contract artifacts live in `resources/`

**Every structural contract this integration deals with — endpoint definitions, request/response schemas, error body shapes, webhook payloads, pagination envelopes, rate-limit headers, the integration's own I/O contract — lives in `resources/` as a linked resource.** Concepts and functional specs **reference** these resources; they do not restate their fields. This rule holds in every phase, for both embedded and standalone integrations.

Use the standard `***linked resource***` syntax from PLAIN_REFERENCE.md → *Linked Resources* to reference each file from the spec that needs it. Pick the right format per artifact type:

- **OpenAPI 3.1 (YAML or JSON)** — the canonical home for the **provider's REST surface**: every endpoint in scope, with `paths`, `parameters`, `requestBody`, `responses`, `components.schemas`, `components.securitySchemes`, and `servers`. One file per provider, conventionally `resources/<provider>.openapi.yaml`. If the provider publishes its own OpenAPI / Swagger, **download it verbatim** during Phase 1 topic 5b and use it as the seed — do not retype it.
- **JSON Schema (Draft 2020-12)** — for **data shapes outside the REST surface**: webhook payloads (one schema per event type, `resources/webhooks/<event>.schema.json`), the integration's own input/output contract (`resources/contract/<entry-point>.schema.json`), configuration objects (`resources/config.schema.json`), and error envelopes that aren't already captured under `components.schemas` in the OpenAPI file.
- **AsyncAPI 2.6+ (YAML)** — optional, for **rich webhook contracts** (multiple channels, bindings, message correlation). If webhooks are a single endpoint with a flat payload set, JSON Schema per event is simpler.
- **YAML enumerations** — for **static lookup tables** that don't fit a schema: provider error code → category mapping (`resources/error-map.yaml`), rate-limit header names (`resources/rate-limit-headers.yaml`), retryable-status-code list (`resources/retry-policy.yaml`).
- **Fixture files** — raw responses captured during live probing (Phase 1 topic 5b) are saved verbatim under `resources/fixtures/` (e.g. `resources/fixtures/<endpoint>.success.json`, `.empty.json`, `.404.json`, `.400.json`, `.429.json`). Conformance tests and schema validators in Phase 3 consume them directly.

Rules that flow from this:

- **Concepts carry references, not data.** An "endpoint" concept names the endpoint and points at its OpenAPI `paths.<path>.<method>` entry; it does not duplicate the request/response shape in concept attributes. Same for webhook concepts (point at the event's JSON Schema), error-model concepts (point at the error envelope schema and the error-map YAML), pagination concepts (point at the page-envelope schema), etc.
- **Functional specs consume linked resources.** A spec describes **behavior** ("call endpoint X, parse the response, classify errors, retry on 5xx") and links to the resource that supplies the **shape**. Field names, types, and validation rules live in the resource file.
- **Schemas are versioned by file path, not embedded version pragmas.** When the provider releases a new API version, copy the new OpenAPI file to a new path (e.g. `resources/<provider>.v2.openapi.yaml`); never mutate the v1 file in place.
- **The renderer generates language-native types from the resources.** For embedded integrations, the renderer reads the JSON Schema / OpenAPI components and emits Pydantic / TypeScript / Go types in `plain_modules/`. The spec does not need to (and must not) restate the field shapes inline — it only declares **which** schema to generate from, **where** the generated type should land, and **what host base class** it must subclass / implement (see *Embedded-integration spec writing rules* in Phase 2).

A single `.plain` module can (and typically will) reference many resources — the OpenAPI file once per endpoint spec, one or more JSON Schemas per webhook spec, one error-map YAML from the error-model concept, etc. That is the intended pattern; do not try to collapse them.

### Embedded into an existing codebase — discover before you ask

When the integration is going into an **existing codebase** (the *embedded* shape from Phase 2 topic 1 — also called the *embedded codebase*), the **why** and the **how** of the integration are already encoded in that codebase. They must be **deduced from the code on disk**, not extracted from the user through interview questions. The user's time goes only into the two things the codebase cannot tell you: **the third-party API** and **its authentication**.

Run this discovery **before** Phase 1's first question. Treat the results as ground truth for the rest of the workflow — every concept, functional spec, and contract artifact you later author must be consistent with what you find here.

**1. Locate where the `.plain` files live in the embedded codebase.** Search the codebase for an existing \*\*\*plain setup before assuming one needs to be created. Look for:

- A `.plain` file or a directory of `.plain` files (often under `plain/`, `specs/`, `plain_specs/`, or at the repo root).
- A `config.yaml` declaring `plain_source_dir`, `plain_modules_dir`, `resources_dir`, `test_scripts_dir`, and the render target — this file pins the layout authoritatively.
- A `plain_modules/` directory (generated output — read-only, never edit) and a `resources/` directory (linked resources).
- A `test_scripts/` directory (`prepare_environment`, `run_unittests`, `run_conformance_tests`).

If the codebase already has a \*\*\*plain setup, **adopt it verbatim**: the new integration module lands inside the existing `plain_source_dir` and `requires` the relevant base module (use `create-requires-module`). Do not create a parallel layout. If the codebase does **not** yet have a \*\*\*plain setup, choose conventional paths (`plain/`, `resources/`, `plain_modules/`, `test_scripts/`) at the repo root and record the decision in the `host-codebase` concept; do not ask the user to pick paths.

**2. Look for examples of other integrations in the same codebase.** If the host already ships one or more integrations, they are the strongest signal for how the new one should look. For each existing integration, read enough of its specs and code to extract:

- **Intent and scope.** What does it do, what does it explicitly *not* do, where does its boundary sit relative to the rest of the host. This sets the expected scope for the new integration.
- **Host base class / interface / protocol.** The class the integration's entry-point subclasses or implements (e.g. `host_project.integrations.base.IntegrationContract`). The new integration must subclass the same base unless the user explicitly says otherwise.
- **Package path and naming convention.** Where the integration lives in the host package tree, how it is named, how it is registered (entry-point registry, plugin manifest, dependency-injection container, explicit import). The new integration must follow the same pattern.
- **Configuration pattern.** How credentials, base URLs, and feature flags are read (env vars, settings module, secret manager). The new integration uses the same mechanism with the same naming convention.
- **Error / exception hierarchy.** Which exception classes the host uses to signal integration failures. The new integration raises from the same hierarchy.
- **Logging, metrics, tracing.** Which libraries and conventions the host already wires up. The new integration emits through the same channels.
- **Testing pattern.** How existing integrations are tested (live, recorded, mocked), which fixtures live where, how conformance tests are structured.

Capture each of these as facts in the `host-codebase` concept (Phase 2 topic 1). Cite the existing integration by file path so the reasoning is auditable.

**3. Deduce, do not ask.** When the integration is embedded, every question about the integration's **whys** (purpose, who calls it, why it exists, what it replaces) and **hows** (language, framework, dependency manager, packaging, error model, logging, lifecycle, contract shape, configuration mechanism, testing strategy) must be answered from the codebase — never from the user. If a Phase 1 or Phase 2 topic checklist asks something the codebase already answers, **skip the question** and author the spec directly from what you read. The only topics that genuinely need the user are:

- **The third-party API itself** — provider, documentation URLs, endpoints in scope, request/response shapes, edge cases, webhooks. (Phase 1 topics 1–3, 6–19.)
- **Authentication and credentials** — auth scheme, where credentials live, scopes, refresh strategy, the credential value itself for live probing. (Phase 1 topics 4 and 5.)

Everything else is a deduction. If a deduction is ambiguous (e.g. two existing integrations subclass two different base classes), surface the ambiguity with a one-question `AskUserQuestion` that quotes both code locations — but the question is about resolving a conflict the codebase itself contains, not about asking the user to design the integration.

**4. Reference embedded-codebase files as linked resources, never restated.** Whenever a `.plain` spec needs to point at code that already exists in the embedded codebase — a host base class, a configuration module, a registry, an existing integration used as a pattern reference, an exception class — add the file (or the relevant directory) under `resources/` as a **linked resource** using the `add-resource` skill, then reference it from the spec via the standard `\*\*\*linked resource\*\*\*` syntax. **Never** inline the file's contents into the spec, and **never** describe its shape from memory.

Concretely:

- For each host symbol the contract spec subclasses, implements, or imports, add the file that defines it as a linked resource (e.g. `resources/host/integrations/base.py`).

The `host-codebase` concept then carries the **fully qualified import paths** (as facts) plus `\*\*\*linked resource\*\*\*` references to each of the files above. Renderer directives in the contract spec (target FQN, base class import path, host-package pins) still belong in the spec; the shapes they refer to live in the linked resources.

This discovery step is finished when: the embedded-codebase `.plain` layout is known, every existing integration in the codebase has been read and summarized in the `host-codebase` concept, every host symbol the new integration will touch is on disk as a linked resource under `resources/host/…`, and the user has confirmed the deductions. Only then proceed to Phase 1's first question — which, for embedded integrations, will be the *Provider and purpose* question scoped strictly to the API side.

---

### Phase 1 — What are we integrating with?

Understand the provider, the contract it exposes, and every corner case the integration must survive in production. This is the most important phase and needs to be done thoroughly. **Drill into the API's behavior.** Surface assumptions early — if a behavior cannot be read out of the documentation, ask the user, or probe with `fetch` against a sandbox endpoint.

This phase is **incremental**. Do **not** ask everything up front and then write all the specs at the end. Instead, walk through the topics below in order, and for each topic run a tight loop:

1. **Ask** — use **AskUserQuestion** to ask **exactly one** question per turn (per *Core operating principles*). Give a short prompt, a small set of multiple-choice options, a free-form option, and a "Let's discuss this" / "I have questions first" option. The very first question of Phase 1 (*Provider and purpose*) is free-form rather than multiple choice, but it is still a single question. **Expect a topic to take several sequential ask→research→author→review iterations** — not one. Use the first question to surface the headline decision for the topic, then drill into follow-ups (edge cases, exact field names, units, ambiguous behaviors, interactions with already-authored specs) one at a time until the topic's on-disk specs are unambiguous and internally consistent. Going deep is the desirable case; a topic that ends after one question almost certainly left ambiguity on the table.
2. **Research** — whenever the user gives a documentation URL, an endpoint URL, or names a well-known API, use `fetch` to read the relevant pages directly. Quote concrete details (status codes, response shapes, header names, error formats) back into the specs you author. Never paraphrase from memory when a primary source is reachable.
3. **Author** — immediately translate the answer and research into `.plain` content. **Every answered question must produce a concrete edit on disk before the next question is asked**, even if the resulting spec is premature, partial, or likely to be revised by later answers (per *Core operating principles*). Translate the answer and research into:
   - The integration's **module file** with YAML frontmatter (`description`, any `import`/`requires` chain). If the integration will sit inside an existing project, treat the existing project's `.plain` setup as a given and add a new module that `requires` the relevant base. Use `create-import-module` / `create-requires-module` skills where applicable.
   - **`***definitions***`** — one concept per first-class entity that emerges from this topic: the provider, each endpoint, each auth scheme, each error category, the rate-limit model, the pagination model, the webhook event types, etc. Define every concept before it is referenced. Use the `add-concept` skill.
   - **`***functional specs***`** — translate behaviors and edge cases into chronological, incremental specs (each implying ≤200 lines of code change, language-agnostic, no conflicts). Use `add-functional-spec` for one new spec, and `add-functional-specs` for multiple new specs in the same pass (e.g. a single endpoint that decomposes into "call", "parse success", "handle 4xx", "handle 5xx with retry", "respect rate-limit headers"). Never hand-author the `***functional specs***` section directly.
   Do **not** add `***implementation reqs***`, `***test reqs***`, or `***acceptance tests***` in this phase — those belong to Phase 3 (handed off to `forge-plain`).

   When a later answer contradicts content already on disk, **update the affected spec or resource in place** (or split it) right now, before continuing. Never leave a stale spec around "to be reconciled later".
4. **Review** — trigger the review loop (see *Review the latest additions* below) on whatever was just authored or updated. Apply the user's responses back to the `.plain` files and re-surface any snippet that materially changed. Only move on to the next question once every flagged snippet has been explicitly approved.

Walk through these topics in order, running ask → research → author → review for each. Skip a topic only if it genuinely doesn't apply, and say so explicitly:

1. **Provider and purpose.** What system are we integrating with (Stripe, GitHub, Slack, Salesforce, internal API, …)? What does the integration need to accomplish in one sentence? Why does it need to exist (what problem is it solving, what would the user do without it)? Free-form, not multiple choice. Author: a stub `.plain` module with the purpose in the YAML frontmatter description and the provider captured as a concept. Review: the frontmatter and the provider concept.

2. **Documentation.** Ask for the canonical documentation URL(s) — REST reference, getting-started guide, authentication guide, webhooks guide, changelog/versioning page. **Immediately** fetch each URL with `fetch` and skim it for: base URL(s), auth scheme(s), pagination style, error format, rate-limit headers, sandbox/production environments, versioning policy. Author: one concept per primary doc reference (so future specs can cite it), and capture the base URL(s) as a concept. Review: the doc references and the base-URL concept.

3. **Endpoints in scope.** Which exact REST endpoints will the integration call? For each: HTTP method, path, required query / header parameters, request body shape, success response shape, all documented status codes. Push the user to enumerate **all** endpoints up front — adding endpoints later cascades into auth, error handling, and pagination decisions. **Author the structural contract into `resources/<provider>.openapi.yaml`** — one OpenAPI `paths.<path>.<method>` entry per endpoint, with `parameters`, `requestBody`, `responses` (every documented status code), and any shared types under `components.schemas`. If the provider publishes its own OpenAPI / Swagger (fetched in topic 5b), seed `resources/<provider>.openapi.yaml` from it and trim down to the endpoints in scope. Then author **one concept per endpoint** that references the OpenAPI path by its file location and operation id (e.g. "see `resources/<provider>.openapi.yaml#/paths/~1v1~1customers/get`") rather than restating the fields, and **one functional spec per endpoint** covering the **happy path only** that links to the same OpenAPI operation. Review: each endpoint concept and its happy-path spec.

4. **Authentication.** What auth scheme does the API use (static API key in header / query, HTTP basic, bearer token, OAuth2 — which flow: client_credentials, authorization_code, device, PKCE, refresh-token rotation, HMAC-signed requests, mTLS, AWS SigV4, custom)? Where do credentials live in the integration (env var name, secret manager, config file)? Token lifetime and refresh strategy? Scopes / permissions required? Author: an auth concept capturing scheme + credential source + scopes + refresh policy, and one functional spec for "obtain and attach credentials" (and a second spec for "refresh" if the scheme requires it). Review: the auth concept and the auth-attach / refresh specs.

5. **Validate the credentials and probe the live API.** Credentials are not just a yes/no gate — once they work, they're the most valuable research tool available, because they let you ground every later topic in **real** responses instead of paraphrased docs. Run this in two passes:

   **5a. Authenticate.** Ask the user whether they have credentials available now. If yes, ask which low-risk read-only endpoint can be hit to confirm them (e.g. `/v1/me`, `/account`, `/whoami`, `/health`). **Issue the call via `fetch`** with the user's credential value. Treat the value as sensitive: never echo it back in your responses, never write it into `.plain` files, never include it in summaries — reference it only by the env-var name pinned in topic 4.
   - On a 2xx, capture the verified account identifier / tenant / scopes returned by the response as facts in the auth concept (these are real, not assumed), and proceed to 5b.
   - On a 401/403, stop and resolve with the user (wrong key, wrong env, missing scopes, expired token, IP allowlist) — do **not** author further specs against unverified credentials.
   - On a 5xx or network error, note the provider may be down and retry once before escalating.
   - If the user does not have credentials yet, note it explicitly and continue, but flag in the module frontmatter description that credentials have not yet been validated and that Phases 6–18 below were authored without live grounding. Re-run **both 5a and 5b** as soon as the user obtains credentials.

   **5b. Probe the API for ground-truth data.** With working credentials in hand, use `fetch` to issue **read-only** calls that surface the concrete shapes the integration will deal with. The goal is to retire assumptions before they get baked into specs. For each call, redact the credential and any secrets / PII from the response before showing it to the user; quote only the structural details (field names, types, status codes, headers) into the specs.
     - **Discovery / schema endpoints.** If the provider exposes `/openapi.json`, `/swagger.json`, `/discovery`, `/schema`, a GraphQL introspection endpoint, or an `OPTIONS *` that lists resources, fetch it and **save the response body verbatim** to `resources/<provider>.openapi.yaml` (or `.json` — keep the provider's format). This file becomes the **seed** of the integration's OpenAPI contract; trim it to the endpoints in scope rather than retyping it. Link to it as a `***linked resource***` from the provider concept.
     - **List endpoints.** For each endpoint in scope (topic 3), issue a paginated `GET` with a small page size (e.g. `?limit=2`). **Save the redacted response body to `resources/fixtures/<endpoint>.success.json`** (and its headers, in a sidecar `.headers.json` if non-trivial) so conformance tests can replay it later. From the fixture, **update `resources/<provider>.openapi.yaml`** with the real shapes: the actual response envelope (top-level keys like `data`, `items`, `results`, `nodes`) goes into `components.schemas`, the actual pagination tokens go into the operation's response schema, the rate-limit headers go into `responses.<status>.headers`. Capture provider-specific request-id headers (`X-Request-Id`, `Cf-Ray`, …) in the OpenAPI `responses` headers as well. Do **not** restate any of this in the endpoint concept — the concept points at the OpenAPI fragment.
     - **Single-object retrieval.** Fetch one representative object per primary entity (e.g. one customer, one order, one repository, one message). Save the redacted body to `resources/fixtures/<entity>.example.json` and lift the schema into `components.schemas.<Entity>` of `resources/<provider>.openapi.yaml`. Record nullability of each field in practice (docs often lie about this), date/time format actually used, numeric precision (string vs. integer for IDs and money), and any undocumented fields the provider adds — all of it in the schema, not in concept text. These schemas ground the data-scope concepts in topic 15.
     - **Empty / boundary responses.** Fetch a list endpoint with a filter that returns zero results, and one with the page size pushed to (or past) the documented maximum. Save fixtures (`resources/fixtures/<endpoint>.empty.json`, `.overflow.json`). Capture how the API signals "empty" and how it handles `limit` overflow (silently clamps, 400 error, ignores) by extending the OpenAPI `responses` section with the additional status codes seen.
     - **Error shapes.** Deliberately trigger a 404 (request a non-existent ID) and a 400/422 (send a malformed payload to a known-safe endpoint, or omit a required parameter). Save the bodies to `resources/fixtures/<endpoint>.404.json` and `<endpoint>.400.json`, and lift the error envelope into `components.schemas.ErrorEnvelope` of the OpenAPI file (or a standalone `resources/error-envelope.schema.json` if errors are shared across multiple providers). This schema is the source of truth for the error-model concept in topic 11.
     - **Auth-edge cases.** Issue one call with the credential deliberately wrong (e.g. last character flipped) to see the real 401 body and any `WWW-Authenticate` header. Save it to `resources/fixtures/auth.401.json`. For OAuth, fetch one access token via the documented flow and save the token response to `resources/fixtures/oauth.token.json` (with the actual token value redacted to `"<redacted>"`); the lifetime / refresh fields become part of the auth concept's linked resource.
     - **Rate-limit headers.** On every probe call, capture the rate-limit headers returned (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, `Retry-After`, `RateLimit-*` per RFC 9331). Collect them into `resources/rate-limit-headers.yaml` (a flat mapping of header name → meaning / format), which the rate-limit concept in topic 10 links to.
     - **Webhook signing keys / setup endpoints.** If webhooks are likely in scope (topic 14), fetch the webhook configuration / signing-secret endpoint (if the API exposes one) to see what fields it returns. Save the redacted body to `resources/fixtures/webhook.config.json` and feed it into `resources/webhooks/<event>.schema.json` plus a `resources/webhook-signing.yaml` describing the signature scheme. Do **not** trigger a real webhook against the user's machine.

   **Safety rails on probing.** Only `GET` (and `HEAD` / `OPTIONS`) on this pass — no `POST`, `PATCH`, `PUT`, or `DELETE` against a real account without the user's per-call confirmation. If a mutating call is essential to validate something (e.g. confirming idempotency-key behavior), ask first, point at a sandbox account, and use obviously-fake values. Stop probing the moment the user signals enough; you can always come back when a later topic surfaces a specific question.

   **Authoring from probe results.** Every observation from 5b that contradicts or refines a doc-derived assumption goes back into the corresponding concept or functional spec as you reach its topic — don't author Phase 1 specs from the docs first and then "reconcile" later. Re-surface the affected snippet through the review loop so the user signs off on the live-data version.

6. **Environments.** Does the API distinguish sandbox / staging / production? What are the base URLs for each? How does the integration switch between them (env var, config flag, separate credentials)? Are there feature differences between environments (e.g. webhooks only in production)? Author: an environments concept, and a functional spec for "select base URL from configuration". Review: that snippet.

7. **API versioning.** How is the API version pinned (URL path like `/v1/`, `Api-Version` header, `Accept: application/vnd.provider.v2+json`, query string)? Which version will the integration target? What is the provider's deprecation policy? Author: a version concept, and a functional spec for "pin the API version on every request". Review: that snippet.

8. **Request shape & serialization.** Content type (`application/json`, `application/x-www-form-urlencoded`, multipart), date/time format (RFC 3339, Unix epoch, custom), numeric precision (integers vs. strings for money / IDs), nullability conventions, required custom headers (`User-Agent`, `Idempotency-Key`, correlation IDs). Author: encode the serialization rules into `components.schemas` and `components.parameters` of `resources/<provider>.openapi.yaml` (date formats as `format: date-time`, numeric strings as `type: string, pattern: ^[0-9]+$`, custom headers under `parameters` with `in: header`). Add a request-shape concept that **links** to those OpenAPI components rather than restating them, and refine the endpoint happy-path specs to reference the same components. Review: the request-shape concept and the affected OpenAPI components.

9. **Pagination.** Which style — cursor-based (`next_cursor`, `after`, opaque token), offset/limit, page-number, link header (`Link: <…>; rel="next"`), or none? Page size limits (default, max)? How does the integration know it has reached the end? Should it stream pages or buffer? Maximum records to fetch in one call (safety cap)? Author: capture the page-envelope shape in `components.schemas.PageEnvelope` of `resources/<provider>.openapi.yaml` (or a standalone `resources/pagination.schema.json` if envelopes vary per endpoint), plus a `resources/pagination.yaml` enumerating the style, defaults, and safety cap. Add a pagination concept that links to both, and one functional spec per paginated endpoint for "iterate all pages". Review: the pagination concept, the linked resource(s), and each iteration spec.

10. **Rate limits & quotas.** Documented limits (RPS, RPM, daily quota, per-resource limits, burst rules). Which response headers communicate remaining quota (`X-RateLimit-Remaining`, `Retry-After`, `RateLimit-Reset`)? What does the API return on exhaustion (status code, body, headers)? Should the integration self-throttle pre-emptively or only react on 429? Concurrency limits (max parallel requests)? Author: write the header inventory into `resources/rate-limit-headers.yaml` (header name → meaning / format / which response includes it) and the quota numbers into `resources/rate-limits.yaml` (RPS, RPM, daily, per-resource, burst). Add the 429 response and exhaustion body shape to `components.schemas.RateLimitError` of the OpenAPI file. Add a rate-limit concept that links to all three resources, plus a functional spec for "respect rate-limit headers" and one for "react to 429". Review: those snippets.

11. **Error model.** What HTTP status codes does the API use, and how does each one map to integration behavior? What is the error response body shape (single `error` field, `errors` array, problem+json, custom)? Are there application-level error codes inside successful HTTP responses (e.g. 200 with `{"ok": false, "error": "…"}`)? Which errors are retryable and which are permanent? How are validation errors distinguished from server errors? Author: the error body shape goes into `components.schemas.ErrorEnvelope` of `resources/<provider>.openapi.yaml` (or `resources/error-envelope.schema.json` if shared), and the status-code-to-category mapping goes into `resources/error-map.yaml` (e.g. `401: auth`, `403: auth`, `409: conflict`, `429: rate-limit`, `5xx: transient-server`). Add an error-model concept that links to both, and one functional spec per category covering "detect → classify → react". Review: the error-model concept and each category spec.

12. **Retries, timeouts, and backoff.** Connect / read / total timeouts. Retry strategy (exponential backoff with jitter, fixed delays, no retries). Maximum attempts. Which conditions trigger a retry (network errors, 408, 429, 5xx, idempotent methods only)? Should retries respect `Retry-After`? Circuit-breaker behavior on sustained failure? Author: encode the policy into `resources/retry-policy.yaml` (retryable status codes, max attempts, base/max backoff in ms, jitter strategy, `Retry-After` honored, circuit-breaker thresholds). Add a retry-policy concept that links to it, and a functional spec for "apply retry policy to each request". Review: that snippet and the policy file.

13. **Idempotency.** Does the API accept an idempotency key (header name, scope, TTL)? Which methods need one (typically `POST`, `PATCH`, `DELETE`)? How does the integration generate the key and persist it across retries? What does the API return on a duplicate (200 + cached body, 409, 422)? Author: add the idempotency header to `components.parameters` of `resources/<provider>.openapi.yaml` (with `in: header`, `required: true` on mutating operations) and capture the policy (key-generation strategy, persistence TTL, methods in scope, duplicate-response status codes) in `resources/idempotency.yaml`. Add an idempotency concept that links to both, and a functional spec for "attach idempotency key to mutating requests and handle replay responses". Review: that snippet.

14. **Webhooks / push callbacks.** Does the integration also need to **receive** events from the provider? If yes: which event types, what payload shape, signature scheme (HMAC algorithm, header name, signing key source), replay protection (timestamp window, nonce store), delivery guarantees (at-least-once, ordering), retry behavior on the provider's side. Endpoint exposed by the integration (path, method, expected status response). Author: **one JSON Schema file per event type** under `resources/webhooks/<event>.schema.json` (Draft 2020-12), plus `resources/webhook-signing.yaml` describing the signature scheme (algorithm, header name, signing-key env var, timestamp window). If webhooks are rich enough (multiple channels, bindings), promote them to a single `resources/webhooks.asyncapi.yaml` instead. Add a webhook concept per event type that links to its JSON Schema, a signature-verification concept that links to `webhook-signing.yaml`, and one functional spec each for "receive callback", "verify signature", "deduplicate", "dispatch event". Review: each snippet. If webhooks are not in scope, record the decision explicitly and skip.

15. **Data scope & direction.** What entities flow in/out (customers, orders, messages, …), in which direction (read-only, write-only, bidirectional sync), and which fields actually matter? Are there fields that must be transformed (e.g. provider uses cents, integration uses dollars)? Are there fields that must be **excluded** for privacy or size reasons? Author: **one JSON Schema entry per entity** under `components.schemas.<Entity>` of `resources/<provider>.openapi.yaml` (or as a standalone `resources/entities/<entity>.schema.json` if the entity is consumed outside the REST surface, e.g. by webhooks). Capture transformations and exclusions in `resources/data-mapping.yaml` (provider-field → integration-field, including unit conversions and redactions). Add one concept per entity that links to its schema, and a functional spec per direction (e.g. "fetch X from provider", "push Y to provider", "reconcile Z on conflict") that links to the entity schema and `data-mapping.yaml`. Review: each entity concept and each direction spec.

16. **Compliance & data sensitivity.** Does the integration handle PII / PHI / payment data / regulated data? Are there data-residency requirements? Are there fields that must be redacted from logs? Encryption-at-rest / in-transit requirements beyond HTTPS? Audit-log requirements? Author: a compliance concept capturing the constraints, and a functional spec for "redact sensitive fields from logs". Review: those snippets. If nothing applies, record that explicitly and skip.

17. **Observability.** What does each request need to log (method, path, status, latency, correlation ID, request ID returned by the provider)? Are there provider-specific request IDs (`X-Request-Id`, `Cf-Ray`) worth capturing? Metrics to emit (success / failure / latency / retry count)? Tracing (propagate `traceparent` to the provider, capture spans)? Author: an observability concept and functional specs for "log request lifecycle" and "emit metrics per request". Review: each snippet.

18. **Operational concerns.** Long-running / async operations on the provider's side (polling jobs, status endpoints)? Bulk APIs vs. per-record APIs? Caching of read responses (with what TTL, what cache key)? Background workers, schedulers, cron-style sync jobs? Graceful shutdown / in-flight request draining? Author: a concept per operational pattern in scope, and one functional spec per pattern. Review: each snippet.

19. **Anything else.** Anything provider-specific the user wants to add — quirks documented only in changelogs, known bugs, support contacts, undocumented endpoints the team relies on.

Keep asking follow-ups within a topic until every behavior is specific enough to become a single \*\*\*plain functional spec (implying ≤200 lines of code change each). If a behavior is too large (e.g. "handle all errors"), break it down together with the user before authoring.

When all topics are complete, summarize: the provider, the endpoints in scope, the auth scheme, every edge case captured (errors, retries, rate limits, pagination, idempotency, webhooks, compliance, observability), and the credential-validation result. Get an explicit overall confirmation before moving to Phase 2.

#### Review the latest additions

This is the review loop you trigger after each authoring step above. Walk through **only what just changed** with the user using **AskUserQuestion**, **one snippet at a time**. Do **not** re-review the whole file every iteration — pick the **single most relevant snippet** that warrants a decision (one concept, one functional spec, the module frontmatter) and embed it directly in the question prompt so the user sees exactly what they are approving.

For each snippet you raise, frame the question around one of:

- **Missing parts** — anything that should be in the spec but isn't (an error code, a header, a timeout value, an edge case the docs mention but the spec doesn't).
- **Possible extensions** — behavior or detail that could reasonably be expanded (additional retryable conditions, a richer error taxonomy, an extra log field).
- **Ambiguities** — wording, ordering, or relationships that could be read multiple ways (when exactly does a 409 trigger an idempotency replay vs. a conflict error?).

Each AskUserQuestion call offers concrete options such as "Approve as written", "Extend with …", "Clarify …", plus a free-form option and a "Let's discuss this" option (per *Core operating principles*). Never batch multiple review questions into one call — if more than one snippet needs review, ask about them sequentially, applying edits between each.

Apply the user's response back to the `.plain` files (using the appropriate edit skills) **immediately after each answer**, even if the edit is partial or you expect a follow-up to refine it. Re-surface any snippet that materially changed. Continue until every snippet you flagged has been explicitly approved before returning to the topic loop and moving on to the next question.

---

### Phase 2 — How does the integration integrate?

Decide the **shape of the integration's I/O contract** — the surface other code (or other systems) calls to use it. This is the boundary between the integration and whatever consumes it. Get it wrong and either the embedding project can't use it cleanly, or the standalone integration can't be deployed predictably.

This phase is **incremental**. Walk through the topics below in order, running ask → author → review for each.

1. **Ask** — use **AskUserQuestion** to ask **exactly one** question per turn (per *Core operating principles*). Each call carries a short prompt, a small set of multiple-choice options, a free-form option, and a "Let's discuss this" / "I have questions first" option. **Expect a topic to take several sequential ask→author→review iterations** — use the first question to settle the topic's headline decision (e.g. embedded vs. standalone, which entry points exist), then drill into follow-ups (exact input/output fields, lifecycle stages, configuration keys, concurrency behavior) one at a time until the contract spec and linked resource are unambiguous. Going deep is the desirable case; do not move on while the topic still has obvious gaps.
2. **Author** — translate the answer into specs **before asking the next question**, even if the resulting spec is premature or likely to be revised (per *Core operating principles*). When a later answer contradicts content already on disk, update the affected spec or schema file in place right now. Specifically, produce:
   - A **functional spec** that nails the entry point(s), inputs, outputs, side effects, configuration surface, and lifecycle (init / shutdown / token refresh / connection pooling).
   - The **contract artifact itself, always as a linked resource under `resources/`** — never inline in the spec. Per the *Contract artifacts live in `resources/`* rule:
     - **JSON Schema** (`resources/contract/<entry-point>.schema.json`) for in-process / library / queue / CLI entry-point inputs and outputs.
     - **OpenAPI** (`resources/contract/<integration>.openapi.yaml`) when the integration exposes its own HTTP surface (standalone HTTP service, webhook receiver).
     - **Configuration schema** (`resources/config.schema.json`) for the configuration surface in topic 6.
     The functional spec uses `***linked resource***` references; it does **not** restate field names, types, or validation rules. The choice of `embedded` vs. `standalone` in topic 1 controls **what the renderer emits from the schema** (a host-language class in `plain_modules/` vs. a packaged schema artifact for external consumers) — not whether the contract is a resource. The contract is always a resource.
3. **Review** — trigger the review loop (same shape as Phase 1, one snippet at a time) on whatever was just authored or updated.

Walk through these topics in order:

1. **Embedded vs. standalone.** Ask explicitly: is this integration built **into an existing codebase** (it lives as a library / module other code imports and calls in-process) or **standalone** (a service, daemon, CLI, scheduled job, or container that runs on its own)?

   **The contract artifact itself is identical across both shapes:** a JSON Schema (or OpenAPI) file under `resources/contract/`. What changes is **what the renderer emits from it** and **what extra context the spec carries**.

   - **Embedded** → the renderer generates a host-language class from the schema and wires it into the host's import path. **The host codebase dictates the tech stack** — language, framework, dependency manager, packaging layout, coding conventions. The integration must conform to the host; no separate stack decisions get made later. Collect, all in this step (read what you can directly from host files; only ask the user what cannot be inferred):
     - The absolute (or project-relative) path to the host codebase root.
     - The host language and its exact version — read from `pyproject.toml` / `package.json` / `go.mod` / `Cargo.toml` / equivalent.
     - The host's dependency manager and manifest file path (pip + `requirements.txt`, Poetry, uv, npm, pnpm, yarn, Go modules, Cargo, Maven, Gradle, …).
     - The package / module path inside the host where the integration will be consumed, and — if the integration must conform to an existing host class / interface / struct / protocol — its **fully qualified import path** (e.g. `host_project.integrations.base.IntegrationContract`).
     - Any host-specific conventions the contract must follow (custom base classes, exact Pydantic major version, sync vs. async style, exception hierarchy, dependency-injection seams, logging library).
     - The **target generated-class fully qualified name** under `plain_modules/` (e.g. `plain_modules.integrations.<provider>.Client`) and the host base class it should subclass.
   Author: the contract schema itself in `resources/contract/<entry-point>.schema.json` (JSON Schema Draft 2020-12). Then add a `host-codebase` concept capturing all of the above as facts (root path, language + version, manager + manifest, target package path, host base class import path, conventions, target generated-class FQN), and a "contract" functional spec that **links to the schema** and declares the **renderer directives** the embedded shape needs: target language, target file path, target class name, host base class import path to subclass / implement, and any host-package version pins. The spec must **not** restate the schema's fields — they live in the linked resource.
   - **Standalone** → the renderer treats the schema as the public artifact: it generates an internal implementation in `plain_modules/` and ships the schema verbatim (or wrapped in an OpenAPI document) for external consumers. Ask which surface(s) the integration exposes: HTTP (OpenAPI), CLI (flag spec), queue worker (JSON Schema for messages), scheduled job (JSON Schema for config), library published to a registry (JSON Schema for the package's public API). Author: the schema file(s) under `resources/contract/` and a "contract" functional spec that links to them and declares the publication surface (e.g. "served at `/openapi.json`", "published as `<package>` to npm", "emitted as `--help` output by the CLI"). The spec **must not** restate the schema's fields.
   Author this decision as a concept too — `integration-shape: embedded | standalone` — so later specs can reference it.

2. **Entry points.** What is each entry point the consumer (or external system) calls? For embedded: function / method / class names. For standalone: HTTP route + method, CLI command name + subcommands, queue topic / partition, scheduled-job name. List **all** of them — partial enumeration here cascades into ambiguity later.
   Author: one functional spec per entry point describing what calling it does end-to-end (which Phase 1 specs it composes — auth, the endpoint call, the retry policy, the error handling).

3. **Input contract.** For each entry point: every parameter (name, type, optionality, default, validation rules, allowed values, units). Document **what gets rejected** as clearly as what gets accepted. For embedded: type annotations. For standalone: schema field definitions with `type`, `format`, `enum`, `pattern`, `minimum`, `maximum`, `required`.
   Author: the contract spec(s) carry these inline (embedded) or reference the schema file (standalone). Reject-cases also become functional specs ("reject `amount` ≤ 0 with `InvalidAmount`").

4. **Output contract.** For each entry point: success shape, error shape, partial-failure handling (e.g. bulk operations that succeed for some records and fail for others). What does the consumer learn about retries that already happened internally — does the integration surface attempt counts, the underlying provider error, both? How are async / pending outcomes represented (a job ID + a `status()` call, a future, a callback)?
   Author: the contract spec(s) carry the output shapes; one functional spec per non-trivial output pattern.

5. **Side effects.** What does the integration mutate **outside** the provider call itself? Local DB writes, file writes, cache updates, emitted domain events, metrics, log lines. For each side effect: when does it happen (before / after the provider call), is it transactional with the provider call, what happens if the provider call succeeds but the side effect fails (and vice versa)?
   Author: one functional spec per side effect describing the ordering and the rollback / compensation strategy.

6. **Configuration surface.** Every config knob the consumer can set: env var names, config file keys, secrets, feature flags, regional selectors, timeouts, retry counts, base URL overrides. For each: type, default, required vs. optional, validation, where it is read (startup vs. per-call).
   Author: a configuration concept enumerating every key, and a functional spec for "load and validate configuration on startup". If standalone, this also lands in the schema file as a config object.

7. **Lifecycle.** Initialization (one-time setup, validating credentials at startup vs. lazy on first call, opening connection pools, registering webhook handlers), token / credential refresh (proactive vs. reactive, refresh lock to prevent thundering herd), graceful shutdown (drain in-flight requests, deadline for shutdown, what happens to retries in progress), health checks (what does "healthy" mean for this integration — last successful call, credential validity, provider's own `/health`).
   Author: one functional spec per lifecycle stage. Embedded integrations may collapse some of these into the host project's lifecycle; standalone integrations always need all of them explicitly.

8. **Concurrency & throughput.** Sync vs. async (in the host-language sense — `async def`, `Promise`, goroutines, threads). Expected throughput (requests per second the consumer will issue at peak). Connection pool size. Request queue depth. Backpressure behavior when the rate limit (from Phase 1, topic 10) and the consumer's demand collide — drop, queue, block, error?
   Author: a concurrency concept and a functional spec for "apply backpressure when local demand exceeds rate-limit budget".

9. **Versioning of the integration itself.** Separately from the provider's API version (Phase 1, topic 7), how is the **integration's own** contract versioned? Semver of the published library, OpenAPI `info.version`, CLI `--version`, schema `$id` versioning. Backwards-compatibility policy for the contract.
   Author: a contract-version concept; for standalone, embed the version in the schema file.

10. **Anything else.** Anything contract-shaped the user wants to add — error-type hierarchies, exception classes to expose, telemetry hooks consumers can plug into, dependency-injection seams.

When all topics are complete, summarize the final contract: integration shape (embedded / standalone), every entry point, the input and output contract for each, configuration surface, lifecycle, concurrency model. If standalone, the path(s) to the schema file(s) under `resources/`. If embedded, the host codebase root, host language + version, host dependency manager, and the host class import path the contract conforms to. Get an explicit overall confirmation before moving to Phase 3.

#### Embedded-integration spec writing rules

When the integration is embedded, the generated code in `plain_modules/` must **reuse** the host codebase's symbols at runtime — not redefine them — **and** be generated from the contract schema in `resources/`. The renderer can only get this right if the specs say so explicitly. Apply these rules to every spec authored from this point on:

- **The contract schema is the single source of truth for shapes.** Field names, types, validation rules, and nullability live in `resources/contract/<entry-point>.schema.json` (JSON Schema) or `resources/<provider>.openapi.yaml` (for endpoint shapes). Specs **link** to these; they never inline a class definition, an `interface`, a `struct`, or a field list. If a host base class adds fields the integration shouldn't redeclare, the contract schema uses `allOf` / `$ref` to extend the host's schema rather than duplicating fields.
- **Renderer directives go in the spec, not in the schema.** Each contract spec carries the **language-specific glue** the schema can't express: target generated-class fully qualified name (e.g. `plain_modules.integrations.<provider>.Client`), target file path under `plain_modules/`, host base class import path to subclass / implement, host-package version pins, and any framework-specific decorators or metaclasses (Pydantic `model_config`, FastAPI `Depends`, …). The renderer reads the directives from the spec and the shapes from the linked schema, and emits the host-language class.
- **Reference host symbols by fully qualified import path only.** Any host class, interface, struct, exception, or type alias that appears in a spec must be written with its full dotted/slashed import path (e.g. `host_project.integrations.base.IntegrationContract`, `@host/integrations#Contract`) and flagged in the spec text as "imported from the host codebase; do not redefine". The renderer is allowed to redefine **only** symbols the host does not provide and the contract schema does not capture.
- **Contract spec must declare inheritance, not duplication.** The entry-point class/interface/struct in the contract spec must `subclass` / `implements` / `embeds` the host symbol, again by its full import path. The spec must not restate the parent's fields or methods — it should describe only the integration-specific additions and overrides, all of which are themselves expressed in the linked schema.
- **Pin host-package versions the contract depends on.** If the contract relies on a host-side library version (e.g. Pydantic v2 model semantics, a specific FastAPI version's `BaseModel` behavior), the contract spec must name the package and the acceptable version range. These pins also feed Phase 3's transcribed `***implementation reqs***`.
- **Single source of truth for the host root.** The `host-codebase` concept holds the host codebase root path as a fact. Test scripts, `prepare_environment`, and any configuration loading spec must read it from that one fact (via the env var declared in the configuration concept), never hardcode it.
- **No host-overlapping reqs.** Implementation reqs added in Phase 3 must not contradict anything in the host codebase — same language, same dependency manager, same packaging layout. If a Phase 3 question seems to push back on a host rule, treat the host as ground truth and rewrite the question.

#### Review the latest additions

Same shape as the Phase 1 review loop. Ask **one** review question at a time via `AskUserQuestion`, framed around **Missing parts / Possible extensions / Ambiguities**. Embed the snippet (the contract spec text, the schema file excerpt, the inline class) directly in the prompt, and offer "Approve as written / Extend with … / Clarify …" plus a free-form option and a "Let's discuss this" option. Apply responses back to the spec or schema file **immediately after each answer** and re-surface anything that materially changed before moving on.

---

### Phase 3 — Build the \*\*\*plain project (delegate to `forge-plain`)

At this point the integration's **product** is fully captured: every concept, every endpoint behavior, every edge case, and the I/O contract are in `***definitions***` and `***functional specs***` on disk and approved by the user. What remains — picking the implementation language and libraries, deciding the testing strategy, generating scripts, building the `config.yaml`, validating with `plain-healthcheck`, and presenting the render command — is **identical** to what `forge-plain` does for any other project.

**Hand off to `forge-plain` now**, starting at its **Phase 2 — What technologies should it use?** Treat the work already on disk as if it had come out of `forge-plain`'s own Phase 1. Specifically:

1. **Skip `forge-plain` Phase 1 entirely.** The functional specs and definitions already exist. Do not re-run the "What is the app? / Who uses it? / Core entities / Key features" interview — those questions were answered, in integration-specific form, by this skill's Phases 1 and 2.
2. **Run `forge-plain` Phase 2 — tech stack.**
   - **If embedded:** the tech stack is **inherited** from the host codebase, not chosen. Do **not** re-ask language, framework, dependency manager, packaging layout, coding standards, or architecture/layering — those are facts captured in the `host-codebase` concept from this skill's Phase 2 topic 1, and they must match the host exactly. Instead, **transcribe** the host stack into `***implementation reqs***` verbatim: the host language and exact version, the host framework + version, the dependency manager and manifest path, the packaging layout, the host conventions the contract must follow, and every host-package version the contract pins. Confirm the transcription with the user (so a misread of the host files gets corrected), then move on. Only re-open a stack question when the host is **genuinely silent** on something the integration needs (e.g. the host doesn't ship an HTTP client and the integration must pick one) — and even then, prefer a library already in the host's transitive dependency tree.
   - **If standalone:** run `forge-plain` Phase 2 normally. Pick the implementation language, the HTTP client library, the framework (Flask, FastAPI, Express, …), the data storage (if any — for idempotency-key persistence, webhook dedup store, OAuth token cache), and the architecture/layering.
3. **Run `forge-plain` Phase 3 — testing.** Pick the testing framework. Decide on conformance testing (strongly recommended for integrations — the API surface is exactly the kind of thing acceptance tests catch regressions on). Generate `run_unittests`, `prepare_environment`, and `run_conformance_tests` as appropriate. Wire up `config.yaml`. Verify the environment with `check-plain-env`.
   - **Integration-specific testing notes** to surface to the user during Phase 3:
     - **Live vs. recorded tests.** Will conformance tests hit the live provider (requires sandbox creds in CI, may be rate-limited), use recorded fixtures (VCR-style cassettes, prerecorded responses), or a local mock server? Each has tradeoffs — document the chosen approach as a test req.
     - **Sandbox credentials in CI.** If live tests are in scope, where do CI credentials come from, and what is the rotation / leak-response policy? Capture as a test req.
     - **Webhook tests.** If webhooks are in scope (Phase 1, topic 14), conformance tests must cover signature verification — including invalid signatures and replay attempts.
     - **Rate-limit tests.** Tests that exercise the 429 path must not actually exhaust the live API's quota. Use a local mock for those cases.
     - **Merging the host codebase with `plain_modules/` (embedded integrations only).** When the integration is embedded, generated code in `plain_modules/` imports symbols from the host codebase (e.g. `from host_project.integrations.base import IntegrationContract`). For *anything* to run — unit tests, conformance tests, the integration itself — the host codebase and `plain_modules/` must resolve as a single import graph at runtime. The three test scripts under `test_scripts/` are the only place this gets wired up, so spell it out in both the scripts and a dedicated `***test reqs***` entry:
       - **`prepare_environment`** installs **both** sets of dependencies — the host's manifest **and** the integration's extra dependencies — into the same environment. Pick the language-appropriate primitive:
         - **Python:** `pip install -e <host>` (preferred — exposes the host package on `sys.path` automatically), or `pip install -r <host>/requirements.txt` for a non-package host; then install the integration's own extras on top.
         - **Node.js:** `npm install --prefix <host>` (or `pnpm` / `yarn` equivalent), then either `npm link` the host or set `NODE_PATH` to include `<host>/node_modules`.
         - **Go:** add a `replace` directive in the integration's `go.mod` pointing at the host module path, then `go mod tidy`.
         - **Java / Kotlin:** install the host artifact into the local Maven/Gradle cache (e.g. `mvn install -f <host>`), then depend on it from the integration.
         - **Rust:** add the host crate as a `path = "<host>"` dependency in `Cargo.toml`.
       - **`run_unittests`** and **`run_conformance_tests`** invoke the test runner with the import path configured so both `<host>` and `plain_modules/` are visible as one. Examples:
         - **Python:** `PYTHONPATH="<host>:$(pwd)/plain_modules:$PYTHONPATH" pytest …` (skip `PYTHONPATH` entirely if `prepare_environment` did an editable install — the host is already on `sys.path`).
         - **Node.js:** `NODE_PATH="<host>/node_modules:$(pwd)/plain_modules/node_modules" node …`, or rely on `npm link` set up in `prepare_environment`.
         - **Go:** rely on the `replace` directive — no per-invocation flags needed.
         The exact incantation must match the language and packaging chosen. Pass the host root and the merging strategy into `implement-unit-testing-script` and `implement-conformance-testing-script` as inputs so they generate the right script body.
       - **Host codebase root is a parameter, not a literal.** None of the three scripts may hardcode an absolute host path. Read the host root from an env var (e.g. `HOST_CODEBASE_ROOT`) with a sensible default that matches the user's layout (e.g. `../host_project`). Surface the env var in each script's `--help` / usage banner. Capture this env var in the integration's configuration concept (Phase 2 topic 6) so it has exactly one declared name across specs, scripts, and runtime.
       - **No new `config.yaml` key is needed** — the merging happens inside the scripts. But the `***test reqs***` entry documenting the strategy is mandatory: it must name the merging primitive (`pip install -e`, `NODE_PATH`, `replace` directive, …), the env var the host root is read from, and the resulting import contract. The renderer reads this req and uses it to decide which host symbols to `import` versus redefine.
4. **Run `forge-plain` Phase 4 — validate and hand off.** Pick the render target (last module in the dependency chain), build the final `config.yaml` with `init-config-file`, validate with `plain-healthcheck`, then present the render command to the user. Identical to `forge-plain` Phase 4.

If at any point during Phase 3 a tech-stack or testing decision **reopens** an integration-shaped question (e.g. "we picked Python, so we need to revisit whether the embedded contract should be a Pydantic model or a `dataclass`"), drop back into this skill's Phase 2 review loop, settle the question against the contract spec, then return to `forge-plain`'s phase you were in. Do not silently rewrite the contract from Phase 3.

---

### Adding endpoints or features to an existing integration

Once the initial integration \*\*\*plain specs are written, the user will come back with new endpoints, new event types, new failure modes to handle, or new entry points on the contract. Use the `add-feature` skill — it runs the same ask → author → review loop scoped to a single feature against an existing `.plain` file. When the feature is integration-shaped (a new endpoint, a new auth scope, a new webhook type), reuse the topic checklist from this skill's Phase 1 to make sure the same edge-case coverage (pagination, rate limits, errors, retries, idempotency) is applied to the new endpoint before the feature is considered done.

---

## Question style

The questions you put to the user must use simple grammatical structures:

- Prefer short, direct sentences over compound or nested clauses.
- Use plain words over jargon when both convey the same meaning.
- One idea per sentence. If a sentence needs a comma-separated list of clauses, split it.

Simpler grammar must not come at the cost of detail. Keep every constraint, edge case, option, and piece of context the user needs to answer accurately. If simplifying a sentence would drop a detail, split it into more sentences instead.

---

## Production-readiness checklist

Before declaring Phase 1 done, every item below must be either captured in a `.plain` spec **or as a linked resource under `resources/`** — or explicitly recorded as "not applicable" with the user's acknowledgement:

- [ ] Provider, purpose, and canonical documentation URL(s) captured as concepts
- [ ] `resources/<provider>.openapi.yaml` exists and contains every endpoint in scope (method, path, parameters, request body schema, response body schema, every documented status code)
- [ ] Endpoint concepts each link to their OpenAPI `paths.<path>.<method>` entry rather than restating fields
- [ ] Auth scheme captured, credential source pinned by env-var name, refresh policy specified; `components.securitySchemes` in the OpenAPI file matches
- [ ] Credentials validated against the live API via `fetch` (or the gap explicitly acknowledged)
- [ ] Probe-result fixtures saved under `resources/fixtures/` for at least: one success response, one empty/boundary response, one 4xx error, one 401 (or the gap acknowledged)
- [ ] Sandbox / production base URLs and the switch mechanism captured (and reflected in `servers` of the OpenAPI file)
- [ ] API version pinning strategy captured
- [ ] Request serialization (content type, date format, numeric precision, custom headers) captured in `components.schemas` / `components.parameters`
- [ ] Pagination model captured as `components.schemas.PageEnvelope` (or standalone `resources/pagination.schema.json`) plus `resources/pagination.yaml` — or "not applicable" recorded
- [ ] Rate-limit model captured as `resources/rate-limit-headers.yaml` + `resources/rate-limits.yaml` + `components.schemas.RateLimitError`
- [ ] Error model captured as `components.schemas.ErrorEnvelope` + `resources/error-map.yaml`, with one functional spec per category
- [ ] Retry policy captured in `resources/retry-policy.yaml`
- [ ] Idempotency strategy captured in `resources/idempotency.yaml` + idempotency header in `components.parameters` — or "not applicable" recorded
- [ ] Webhook contracts captured as `resources/webhooks/<event>.schema.json` per event type + `resources/webhook-signing.yaml` — or "not in scope" recorded
- [ ] Data mapping (entity schemas + transformations / exclusions) captured as entity schemas + `resources/data-mapping.yaml`
- [ ] Compliance / data-sensitivity constraints captured — or "none apply" recorded
- [ ] Observability requirements captured (log fields, metrics, tracing)
- [ ] No structural contract (field names, types, status codes, header names) is restated inline in any concept or functional spec; every such detail lives in a linked resource

Before declaring Phase 2 done:

- [ ] Embedded vs. standalone decision recorded as a concept
- [ ] Every entry point enumerated and captured in a functional spec
- [ ] Input and output contract on disk as a linked resource under `resources/contract/` — JSON Schema (in-process / library / queue / CLI) or OpenAPI (HTTP surface). The functional spec links to it and **never** restates field names or types
- [ ] Configuration surface captured as `resources/config.schema.json` and linked from the configuration concept
- [ ] Lifecycle (init, refresh, shutdown, health) specified
- [ ] Concurrency / backpressure behavior specified
- [ ] Integration's own version / compatibility policy recorded (pinned in the contract schema `$id` / OpenAPI `info.version`)
- [ ] **If embedded:** `host-codebase` concept records host root path, host language + version, host dependency manager + manifest, target package path, host base class import path, and the target generated-class FQN under `plain_modules/`
- [ ] **If embedded:** the contract spec carries renderer directives (target language, target file path, target class name, host base class to subclass, host-package pins) and links to the contract schema; no class body is inlined in the spec
- [ ] **If embedded:** every host symbol referenced in any spec uses its fully qualified import path and is tagged "do not redefine"

Before handing off to `forge-plain` Phase 3 (and through Phase 4), additionally for **embedded** integrations:

- [ ] `forge-plain` Phase 2's tech-stack decisions transcribed verbatim from the host (no independent stack choices)
- [ ] Host-package version pins copied into `***implementation reqs***`
- [ ] `prepare_environment` installs both the host's and the integration's dependencies into one environment
- [ ] `run_unittests` and `run_conformance_tests` resolve `<host>` and `plain_modules/` as a single import graph (via editable install, `PYTHONPATH`, `NODE_PATH`, Go `replace`, or the language-appropriate primitive)
- [ ] Host codebase root is read from a named env var (default value documented in each script's usage) — never hardcoded
- [ ] A `***test reqs***` entry documents the merging strategy (primitive used, env var name, import contract)

---

### Reference

- Full `\*\*\*plain` language guide: PLAIN_REFERENCE.md (loaded via `load-plain-reference`)
- Parent workflow this skill specializes: `.claude/skills/forge-plain/SKILL.md`
- Skills for editing specs are in `.claude/skills/`
- Templates go in `template/`, but import paths omit the `template/` prefix. Resources (including standalone schema files) go in `resources/`
- Generated code lands in `plain_modules/` (read-only, never edit)
- Test scripts are in `test_scripts/`
