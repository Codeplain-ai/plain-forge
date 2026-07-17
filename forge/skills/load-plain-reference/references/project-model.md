# ***plain project model

Use this reference for project structure and language features not owned by a section-specific
authoring rule.

## Source-of-truth model

`.plain` files are the source of truth. They describe observable behavior, implementation choices,
and testing requirements. The renderer produces generated implementation and test artifacts from
those specifications.

## Typical repository structure

```text
*.plain                  # Root specification modules
template/*.plain         # Reusable import modules
resources/               # Linked text artifacts such as schemas and fixtures
plain_modules/           # Generated implementation and unit tests
conformance_tests/       # Generated conformance tests, grouped by module and functionality
test_scripts/            # Unit, environment-preparation, and conformance runners
config.yaml              # codeplain CLI configuration
```

The exact template directory can be configured. Follow the module and linked-resource rules for
what these directories may contain and how a spec refers to them.

## Template inclusion

In addition to frontmatter `import`, ***plain supports parameterized template inclusion:

```plain
{% include "python-console-app-template.plain", main_executable_file_name: "my_app.py" %}
```

Parameters are key-value pairs. Templates access them with `{{ variable_name }}`. Only variable
substitution is supported; conditionals, loops, and other Liquid features are not available.

## Comments

Lines beginning with `>` are ignored during rendering:

```plain
> This is a comment in ***plain.
```

Comments explain the specification to human authors. Do not use comments to carry requirements the
renderer must implement.
