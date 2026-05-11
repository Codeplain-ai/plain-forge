import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import type { Runtime, BuildContext } from "./lib.ts";
import { rmrf } from "./lib.ts";

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), "..");
const forgeDir = path.join(repoRoot, "forge");
const runtimesRoot = path.join(repoRoot, "runtimes");

function listRuntimes(): string[] {
  return fs
    .readdirSync(runtimesRoot, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort();
}

async function loadRuntime(name: string): Promise<Runtime> {
  const buildPath = path.join(runtimesRoot, name, "build.ts");
  if (!fs.existsSync(buildPath)) {
    throw new Error(`Runtime "${name}" has no build.ts at ${buildPath}`);
  }
  const mod = (await import(pathToFileURL(buildPath).href)) as {
    default?: Runtime;
  };
  if (!mod.default) {
    throw new Error(`Runtime "${name}" build.ts must \`export default\` a Runtime object`);
  }
  return mod.default;
}

function makeContext(name: string): BuildContext {
  const runtimeDir = path.join(runtimesRoot, name);
  return {
    repoRoot,
    forgeDir,
    runtimeDir,
    templatesDir: path.join(runtimeDir, "templates"),
    log: (msg: string) => console.log(`[${name}] ${msg}`),
  };
}

async function main(): Promise<void> {
  const args = new Set(process.argv.slice(2));
  const clean = args.has("--clean");
  const cleanOnly = args.has("--clean-only");

  const names = listRuntimes();
  if (names.length === 0) {
    console.log("No runtimes found under runtimes/. Nothing to do.");
    return;
  }

  for (const name of names) {
    const ctx = makeContext(name);
    const runtime = await loadRuntime(name);

    if (clean || cleanOnly) {
      for (const rel of runtime.managedPaths) {
        const abs = path.join(repoRoot, rel);
        rmrf(abs);
        ctx.log(`cleaned ${rel}`);
      }
    }

    if (cleanOnly) continue;

    await runtime.build(ctx);
    ctx.log("done");
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.stack ?? err.message : err);
  process.exit(1);
});
