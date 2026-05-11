import path from "node:path";
import type { BuildContext, Runtime } from "../../bin/lib.ts";
import { copyFile, ensureDir, symlinkRelative } from "../../bin/lib.ts";

/**
 * Claude Code runtime adapter.
 *
 * Generates the on-disk layout that Claude Code's plugin loader and the
 * `/plugin install plain-forge@plain-forge` flow expect at the repo root:
 *
 *   .claude/skills          -> ../forge/skills     (symlink)
 *   .claude/rules           -> ../forge/rules      (symlink)
 *   .claude/docs            -> ../forge/docs       (symlink)
 *   .claude/settings.json                          (copy of template)
 *   .claude/hooks/check-plain-spec.sh              (copy of template, +x)
 *   .claude-plugin/plugin.json                     (copy of template)
 *   .claude-plugin/marketplace.json                (copy of template)
 *
 * Anything else that lives under .claude/ (e.g. settings.local.json) is left
 * untouched so per-user state survives a rebuild.
 */
const claudeRuntime: Runtime = {
  managedPaths: [
    ".claude/skills",
    ".claude/rules",
    ".claude/docs",
    ".claude/settings.json",
    ".claude/hooks/check-plain-spec.sh",
    ".claude-plugin/plugin.json",
    ".claude-plugin/marketplace.json",
  ],

  build(ctx: BuildContext): void {
    const { repoRoot, forgeDir, templatesDir, log } = ctx;
    const claudeDir = path.join(repoRoot, ".claude");
    const pluginDir = path.join(repoRoot, ".claude-plugin");

    ensureDir(claudeDir);
    ensureDir(path.join(claudeDir, "hooks"));
    ensureDir(pluginDir);

    symlinkRelative(path.join(claudeDir, "skills"), path.join(forgeDir, "skills"));
    log("linked .claude/skills -> ../forge/skills");

    symlinkRelative(path.join(claudeDir, "rules"), path.join(forgeDir, "rules"));
    log("linked .claude/rules -> ../forge/rules");

    symlinkRelative(path.join(claudeDir, "docs"), path.join(forgeDir, "docs"));
    log("linked .claude/docs -> ../forge/docs");

    copyFile(
      path.join(templatesDir, "settings.json"),
      path.join(claudeDir, "settings.json"),
    );
    log("wrote .claude/settings.json");

    copyFile(
      path.join(templatesDir, "hooks", "check-plain-spec.sh"),
      path.join(claudeDir, "hooks", "check-plain-spec.sh"),
    );
    log("wrote .claude/hooks/check-plain-spec.sh");

    copyFile(
      path.join(templatesDir, "plugin.json"),
      path.join(pluginDir, "plugin.json"),
    );
    log("wrote .claude-plugin/plugin.json");

    copyFile(
      path.join(templatesDir, "marketplace.json"),
      path.join(pluginDir, "marketplace.json"),
    );
    log("wrote .claude-plugin/marketplace.json");
  },
};

export default claudeRuntime;
