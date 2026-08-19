When rendering .plain spec files, there are two alternative skills (renderers) to use: `run-codeplain` (default) or `pyro-render`.

When user asks to render .plain spec files, check first if the skill `pyro-render` is available.
* If `pyro-render` is available, ask the user if he wants to use pyro to render specs.
* If `pyro-render` is not available, or the user doesn't want to use pyro, then use `run-codeplain` skill.
