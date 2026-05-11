import path from "node:path";
import type { BuildContext, Runtime } from "../../bin/lib.ts";
import { copyFile, ensureDir } from "../../bin/lib.ts";

/**
 * Codex (OpenAI Codex CLI) runtime adapter.
 *
 * Codex installs plugins via `codex plugin marketplace add owner/repo`. When a
 * repo is added as a marketplace, Codex looks for a marketplace catalog and a
 * plugin manifest at known paths in the repo root. The repo itself acts as the
 * plugin root.
 *
 * Generated layout at the repo root:
 *
 *   .codex-plugin/plugin.json                  Codex plugin manifest
 *                                              (its "skills" field points directly at ./forge/skills/,
 *                                              so no symlink is needed at the repo root)
 *   .agents/plugins/marketplace.json           Codex-native marketplace catalog
 *
 * Codex can also read `.claude-plugin/marketplace.json` (the Claude-style format
 * which we already emit via the claude runtime), so the .agents/... file is a
 * Codex-native fallback rather than a hard requirement.
 */
const codexRuntime: Runtime = {
  managedPaths: [
    ".codex-plugin/plugin.json",
    ".agents/plugins/marketplace.json",
  ],

  build(ctx: BuildContext): void {
    const { repoRoot, templatesDir, log } = ctx;
    const pluginDir = path.join(repoRoot, ".codex-plugin");
    const marketplaceDir = path.join(repoRoot, ".agents", "plugins");

    ensureDir(pluginDir);
    ensureDir(marketplaceDir);

    copyFile(
      path.join(templatesDir, "plugin.json"),
      path.join(pluginDir, "plugin.json"),
    );
    log("wrote .codex-plugin/plugin.json");

    copyFile(
      path.join(templatesDir, "agents", "plugins", "marketplace.json"),
      path.join(marketplaceDir, "marketplace.json"),
    );
    log("wrote .agents/plugins/marketplace.json");
  },
};

export default codexRuntime;
