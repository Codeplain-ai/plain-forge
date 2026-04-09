---
name: analyze-if-func-spec-too-complex
description: >-
  Analyze a functional spec to determine if it is too complex for the renderer.
  A spec is too complex if it would produce more than 200 lines of code changes.
  Use after drafting a new functional requirement (during add-functional-requirement)
  to verify it fits within the complexity limit before inserting it.
---

# Analyze If Functional Spec Is Too Complex

For full ***plain syntax details, see [PLAIN_REFERENCE.md](../../PLAIN_REFERENCE.md).

## Why This Matters

The renderer enforces a hard complexity limit: each functional spec must imply a **maximum of 200 changed lines of code**. If a spec exceeds this, the renderer rejects it with "Functional spec too complex!" and the spec must be broken down. Catching this before insertion saves a failed render cycle.

## Input

A drafted functional spec (not yet inserted into the file), plus the full context of the `.plain` file it will be added to — definitions, implementation reqs, and existing functional specs.

## Workflow

1. **Read the full `.plain` file** (and any `requires`/`import` modules) to understand the current codebase context — what already exists and what the new spec builds on.
2. **Read the drafted functional spec** carefully.
3. **Run the complexity analysis** using the checklist below.
4. **Report the verdict**: ACCEPTABLE or TOO COMPLEX, with reasoning.
5. **If TOO COMPLEX**, propose a breakdown into smaller specs.

## Complexity Analysis Checklist

Work through each indicator. A single "yes" does not automatically mean the spec is too complex, but multiple "yes" answers are a strong signal.

### 1. Number of Distinct Behaviors

Does the spec describe more than one independently testable behavior?

```
Too complex:
- :User: should be able to create, edit, delete, and archive :Task: items,
  with validation on all fields and confirmation dialogs for destructive actions.

Acceptable (one behavior each):
- :User: should be able to create :Task:. Only valid :Task: items can be added.
- :User: should be able to edit :Task:.
- :User: should be able to delete :Task:.
- :User: should be able to archive :Task:.
```

### 2. Number of Concepts Introduced or Modified

Does the spec require introducing new data structures, UI components, API endpoints, or other constructs that don't already exist? Count them.

- 0–1 new constructs → likely fine
- 2–3 new constructs → borderline, examine closely
- 4+ new constructs → almost certainly too complex

### 3. Branching Logic and Conditions

Does the spec describe multiple conditional paths, modes, or special cases?

```
Too complex:
- The system should process :Order: differently based on :OrderType:.
  Standard orders are validated and stored. Express orders skip validation
  and are queued for immediate dispatch. Bulk orders are split into
  sub-orders of 100 items each, validated individually, and processed
  in parallel with progress tracking.

Acceptable (separate the modes):
- The system should process standard :Order: by validating and storing it.
- The system should process express :Order: by queuing it for immediate dispatch
  without validation.
- The system should process bulk :Order: by splitting it into sub-orders of 100
  items each and processing them individually.
```

### 4. Cross-Cutting Concerns

Does the spec bundle core functionality with cross-cutting concerns like error handling, logging, retry logic, pagination, or caching?

```
Too complex:
- The system should fetch :Resource: items from the external API with
  pagination support, retry on transient errors with exponential backoff,
  cache results for 5 minutes, and log all API calls.

Acceptable (separate concerns):
- The system should fetch :Resource: items from the external API.
- The system should paginate when fetching :Resource: items from the external API.
- The system should retry fetching :Resource: on transient errors using
  exponential backoff.
```

### 5. UI Complexity

Does the spec describe a complete screen or page with multiple interactive elements, layouts, and state transitions?

```
Too complex:
- Display a dashboard showing :User: profile, recent :Task: items in a
  sortable table, a notification bell with unread count, and a sidebar
  with navigation links that highlights the active page.

Acceptable (build incrementally):
- Display a dashboard page for :User:.
- Show recent :Task: items in a sortable table on the dashboard.
- Show a notification indicator with the unread count on the dashboard.
```

### 6. Data Transformation Complexity

Does the spec involve complex data mapping, aggregation, or transformation across multiple entities?

- Simple field mapping or filtering → likely fine
- Multi-step transformations, joins across entities, or aggregations → likely too complex

### 7. Rough LOC Estimation

Mentally estimate the implementation. Consider:
- New files that need to be created
- New functions/methods
- Data model changes (schema, migrations, types)
- UI components (if applicable)
- Test setup and assertions (unit tests are auto-generated alongside)
- Error handling paths
- Import statements and boilerplate

If the estimate exceeds ~150 LOC, the spec is at high risk of being too complex (leave headroom for the renderer to add necessary boilerplate).

## Output Format

### ACCEPTABLE

```
Verdict: ACCEPTABLE

Estimated complexity: ~[N] LOC
Reasoning: [Brief explanation of why the spec fits within the limit]
```

### TOO COMPLEX

```
Verdict: TOO COMPLEX

Estimated complexity: ~[N] LOC
Triggers: [Which checklist items flagged — e.g., "Multiple distinct behaviors (#1),
           4 new constructs (#2), branching logic (#3)"]

Suggested breakdown:
1. [First smaller spec]
2. [Second smaller spec]
3. [Third smaller spec, if needed]
...

Each suggested spec should imply ≤ 200 LOC independently.
```

## Integration with add-functional-requirement

This skill is called during step 3 of the `add-functional-requirement` workflow, after drafting the spec but **before** inserting it into the file. If the verdict is TOO COMPLEX:

1. Present the breakdown to the user.
2. Get confirmation on the proposed split.
3. Insert each smaller spec individually (running conflict checks on each).
