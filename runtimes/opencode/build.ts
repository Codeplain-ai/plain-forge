import path from "node:path";
import type { BuildContext, Runtime } from "../../bin/lib.ts";
import { copyFile, ensureDir, symlinkRelative } from "../../bin/lib.ts";

/**
 * OpenCode runtime adapter.
 *
 * Generates the .opencode/ layout OpenCode expects at the repo root:
 *
 *   .opencode/skills        -> ../forge/skills     (symlink)
 *   .opencode/rules         -> ../forge/rules      (symlink)
 *   .opencode/docs          -> ../forge/docs       (symlink)
 *   .opencode/package.json                         (copy of template; OpenCode plugin dep)
 *   .opencode/.gitignore                           (copy of template; ignores node_modules etc.)
 *
 * Note: the previous layout symlinked .opencode/* into .claude/*; we now
 * symlink directly into forge/ so .claude/ and .opencode/ are parallel,
 * runtime-agnostic-content siblings.
 */
const opencodeRuntime: Runtime = {
  managedPaths: [
    ".opencode/skills",
    ".opencode/rules",
    ".opencode/docs",
    ".opencode/package.json",
    ".opencode/.gitignore",
  ],

  build(ctx: BuildContext): void {
    const { repoRoot, forgeDir, templatesDir, log } = ctx;
    const opencodeDir = path.join(repoRoot, ".opencode");

    ensureDir(opencodeDir);

    symlinkRelative(path.join(opencodeDir, "skills"), path.join(forgeDir, "skills"));
    log("linked .opencode/skills -> ../forge/skills");

    symlinkRelative(path.join(opencodeDir, "rules"), path.join(forgeDir, "rules"));
    log("linked .opencode/rules -> ../forge/rules");

    symlinkRelative(path.join(opencodeDir, "docs"), path.join(forgeDir, "docs"));
    log("linked .opencode/docs -> ../forge/docs");

    copyFile(
      path.join(templatesDir, "package.json"),
      path.join(opencodeDir, "package.json"),
    );
    log("wrote .opencode/package.json");

    copyFile(
      path.join(templatesDir, ".gitignore"),
      path.join(opencodeDir, ".gitignore"),
    );
    log("wrote .opencode/.gitignore");
  },
};

export default opencodeRuntime;
