---
name: add-resource
description: >-
  Add a linked resource (external file reference) to a ***plain spec. Use when
  the user wants to reference a JSON schema, API spec, data file, or other
  external file from within a functional spec, definition, or implementation
  requirement.
---

# Add Resource

For full ***plain syntax details, see [PLAIN_REFERENCE.md](../../PLAIN_REFERENCE.md).

Linked resources are external files referenced from within a `.plain` spec using markdown link syntax. The file contents are passed to the renderer alongside the spec, providing additional context for code generation.

## Workflow

1. **Identify or create the resource file.** It should be in the `resources/` directory or in the same folder (or a subfolder) as the `.plain` file.
2. **Add the markdown link** at the appropriate place in the spec.
3. **Verify the file path** is relative to the `.plain` file location.
4. **Read the file back** to confirm correct link syntax and path.

## Format

Use standard markdown link syntax inside any spec section:

```plain
***definitions***
- :AuthData: is the authentication data structure. Its format is defined
  in the [auth schema](resources/auth_schema.json).

***implementation reqs***
- When transforming :BackupData:, use the JOLT transform defined in
  [backup_transform.jolt](resources/backup_transform.jolt).

***functional specs***
- The system should expose an API conforming to the
  [API specification](resources/api_spec.yaml).
```

## Path Rules

- Paths are resolved **relative to the `.plain` file location**.
- Only files in the same folder or subfolders are supported.
- **No external URLs** — only local file references.
- No absolute paths.

## Common Resource Types

| Type | Typical location | Use case |
|------|-----------------|----------|
| JSON Schema | `resources/*.json` | Defining data structure contracts |
| OpenAPI / Swagger spec | `resources/*.yaml` | API endpoint definitions |
| Data transforms | `resources/*.jolt` | Data transformation rules |
| Test fixtures | `resources/*.json`, `resources/*.csv` | Sample data for tests |
| Configuration examples | `resources/*.yaml` | Reference configurations |

## When to Use Resources

- The information is too detailed or structured to express inline in the spec (e.g., a full JSON schema).
- The same data is referenced by multiple specs or sections.
- The resource is an industry-standard format (OpenAPI, JSON Schema) that the renderer can interpret directly.

## When NOT to Use Resources

- The information is short enough to include inline in the spec text.
- The file is generated code (those belong in `plain_modules/`, not `resources/`).

## Validation Checklist

- [ ] Resource file exists at the specified path
- [ ] Path is relative to the `.plain` file, not absolute
- [ ] File is in the same folder or a subfolder (no `../` references)
- [ ] Markdown link syntax is correct: `[display text](relative/path)`
- [ ] Resource content is relevant and adds value beyond what the spec text says
- [ ] No external URLs used
