#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import readline from "node:readline";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const pkgRoot = path.resolve(path.dirname(__filename), "..");
const forgeDir = path.join(pkgRoot, "forge");

const AGENTS = {
  claude: ".claude",
  codex: ".codex",
  forgecode: ".forgecode",
  universal: ".agents",
};
const SCOPES = ["project", "global"];

// Subfolders plain-forge writes under an agent directory.
const CONTENT_DIRS = ["skills", "rules", "docs"];
// Manifest recording exactly which files this package installed, so `update`
// can prune our own stale files without touching user or third-party content.
const MANIFEST_REL = path.join(".plain-forge", "manifest.json");
// Flagship skills every plain-forge install ships. Used to recognize legacy
// installs that predate the manifest: if all of these skill directories are
// present, plain-forge is installed even without a manifest.
const FORGE_SIGNATURE_SKILLS = [
  "forge-plain",
  "add-feature",
  "debug-specs",
  "load-plain-reference",
];

// True when baseDir looks like a plain-forge install by its skill footprint
// alone (the manifest-less fallback). Requires every flagship skill so an
// unrelated agent dir with one similarly-named skill is not misdetected.
function hasForgeSignature(baseDir) {
  return FORGE_SIGNATURE_SKILLS.every((skill) =>
    fs.existsSync(path.join(baseDir, "skills", skill)),
  );
}

const BANNER = `\x1b[38;2;224;255;110m██████╗ ██╗      █████╗ ██╗███╗   ██╗      ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
██╔══██╗██║     ██╔══██╗██║████╗  ██║      ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
██████╔╝██║     ███████║██║██╔██╗ ██║█████╗█████╗  ██║   ██║██████╔╝██║  ███╗█████╗
██╔═══╝ ██║     ██╔══██║██║██║╚██╗██║╚════╝██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
██║     ███████╗██║  ██║██║██║ ╚████║      ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝      ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝\x1b[0m
`;

const TAGLINE = "turn ideas into ***plain specs.";

function stripAnsi(s) {
  return s.replace(/\x1b\[[0-9;]*m/g, "");
}

function bannerWidth() {
  return stripAnsi(BANNER)
    .split("\n")
    .reduce((max, line) => Math.max(max, line.length), 0);
}

function printBanner() {
  if (!process.stdout.isTTY) return;
  process.stdout.write("\n" + BANNER + "\n");

  const width = bannerWidth();
  const pad = Math.max(0, Math.floor((width - TAGLINE.length) / 2));
  const tag = TAGLINE.replace(
    "***plain",
    "\x1b[38;2;121;252;150m***plain\x1b[0m",
  );
  process.stdout.write(" ".repeat(pad) + tag + "\n\n");
}

function usage() {
  console.log(`Usage: plain-forge <command> [options]

Commands:
  install   Install plain-forge into an agent directory
  update    Refresh every existing plain-forge install in cwd and $HOME

Install options:
  --agent <claude|codex|forgecode|universal>   Target agent layout
  --scope <project|global>                     Install into cwd or $HOME
  -h, --help                                   Show this help

Update options:
  -y, --yes                                    Remove deprecated files without
                                               confirming each one

Examples:
  plain-forge install --agent claude --scope project
  plain-forge install --agent universal --scope global
  plain-forge update
  plain-forge update --yes

"install" fails if plain-forge is already installed at the target — use
"update" to refresh it. Missing install flags are prompted interactively.
"update" auto-detects installs and prunes only files plain-forge wrote
(confirming each removal), leaving your own and third-party skills untouched.`);
}

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--agent") out.agent = argv[++i];
    else if (a === "--scope") out.scope = argv[++i];
    else if (a === "-y" || a === "--yes") out.yes = true;
    else if (a === "-h" || a === "--help") out.help = true;
    else out._.push(a);
  }
  return out;
}

function promptChoice(question, choices) {
  const input = process.stdin;
  const output = process.stdout;
  if (!input.isTTY) {
    return Promise.reject(
      new Error(
        `cannot prompt for "${question}" — stdin is not a TTY. Pass the value as a flag instead.`,
      ),
    );
  }

  return new Promise((resolve, reject) => {
    let index = 0;
    let rendered = 0;

    const render = () => {
      if (rendered > 0) {
        readline.moveCursor(output, 0, -rendered);
        readline.clearScreenDown(output);
      }
      output.write(`? ${question} (use arrow keys, enter to select)\n`);
      for (let i = 0; i < choices.length; i++) {
        const pointer = i === index ? "\x1b[36m>\x1b[0m" : " ";
        const label = i === index ? `\x1b[36m${choices[i]}\x1b[0m` : choices[i];
        output.write(`  ${pointer} ${label}\n`);
      }
      rendered = choices.length + 1;
    };

    const cleanup = () => {
      input.removeListener("keypress", onKey);
      input.setRawMode(false);
      input.pause();
      output.write("\x1b[?25h"); // show cursor
    };

    const onKey = (_str, key) => {
      if (!key) return;
      if (key.name === "up" || (key.ctrl && key.name === "p")) {
        index = (index - 1 + choices.length) % choices.length;
        render();
      } else if (key.name === "down" || (key.ctrl && key.name === "n")) {
        index = (index + 1) % choices.length;
        render();
      } else if (key.name === "return") {
        cleanup();
        output.write(`  \x1b[32m${choices[index]}\x1b[0m\n\n`);
        resolve(choices[index]);
      } else if (key.name === "escape" || (key.ctrl && key.name === "c")) {
        cleanup();
        output.write("\n");
        reject(new Error("cancelled"));
      }
    };

    readline.emitKeypressEvents(input);
    input.setRawMode(true);
    input.resume();
    output.write("\x1b[?25l"); // hide cursor
    input.on("keypress", onKey);
    render();
  });
}

// Ask a yes/no question. Defaults to "no" when stdin is not a TTY, so a
// non-interactive run never deletes anything without an explicit --yes.
function promptConfirm(question) {
  const input = process.stdin;
  const output = process.stdout;
  if (!input.isTTY) return Promise.resolve(false);

  const rl = readline.createInterface({ input, output });
  return new Promise((resolve) => {
    rl.question(`${question} [y/N] `, (answer) => {
      rl.close();
      resolve(/^y(es)?$/i.test(answer.trim()));
    });
  });
}

const toPosix = (p) => p.split(path.sep).join("/");

function readPkgVersion() {
  try {
    const pkg = JSON.parse(
      fs.readFileSync(path.join(pkgRoot, "package.json"), "utf8"),
    );
    return pkg.version ?? "unknown";
  } catch {
    return "unknown";
  }
}

// Compare two dotted numeric versions. Returns 1 if a > b, -1 if a < b, 0 if
// equal, or null when either version is not purely numeric (e.g. "unknown").
function compareVersions(a, b) {
  const parse = (v) => String(v).split(".").map(Number);
  const pa = parse(a);
  const pb = parse(b);
  if (pa.some(Number.isNaN) || pb.some(Number.isNaN)) return null;
  const len = Math.max(pa.length, pb.length);
  for (let i = 0; i < len; i++) {
    const x = pa[i] ?? 0;
    const y = pb[i] ?? 0;
    if (x > y) return 1;
    if (x < y) return -1;
  }
  return 0;
}

// An install is up to date when the package version did not increase over the
// version recorded in its manifest. Indeterminate versions ("unknown", or a
// missing manifest version) are never treated as up to date, so the refresh
// proceeds rather than silently skipping.
function isUpToDate(installedVersion, currentVersion) {
  const cmp = compareVersions(currentVersion, installedVersion);
  return cmp !== null && cmp <= 0;
}

// Copy srcDir into destDir file-by-file (dereferencing symlinks), returning the
// list of file paths written, each relative to destDir.
function copyTreeTracked(srcDir, destDir) {
  const written = [];
  if (!fs.existsSync(srcDir)) return written;

  const walk = (rel) => {
    const srcPath = path.join(srcDir, rel);
    const destPath = path.join(destDir, rel);
    const stat = fs.statSync(srcPath); // follows symlinks → dereferences
    if (stat.isDirectory()) {
      fs.mkdirSync(destPath, { recursive: true });
      for (const entry of fs.readdirSync(srcPath)) {
        walk(path.join(rel, entry));
      }
    } else {
      fs.mkdirSync(path.dirname(destPath), { recursive: true });
      fs.copyFileSync(srcPath, destPath);
      written.push(rel);
    }
  };

  for (const entry of fs.readdirSync(srcDir)) {
    walk(entry);
  }
  return written;
}

// Copy every content dir into baseDir. Returns the flat list of files written
// (each relative to baseDir, for the manifest) and the per-dir counts. A count
// is the number of top-level items in that dir — i.e. the number of skills
// (each a directory) or rules, not the total file count, since a single skill
// can span several files.
function writeContent(baseDir) {
  const counts = {};
  const files = [];
  for (const dir of CONTENT_DIRS) {
    const written = copyTreeTracked(
      path.join(forgeDir, dir),
      path.join(baseDir, dir),
    );
    const topLevel = new Set(written.map((rel) => rel.split(path.sep)[0]));
    counts[dir] = topLevel.size;
    for (const rel of written) files.push(path.join(dir, rel));
  }
  return { counts, files };
}

function manifestPathFor(baseDir) {
  return path.join(baseDir, MANIFEST_REL);
}

function readManifest(baseDir) {
  try {
    const data = JSON.parse(fs.readFileSync(manifestPathFor(baseDir), "utf8"));
    if (data && Array.isArray(data.files)) return data;
  } catch {
    /* missing or malformed manifest → treat as absent */
  }
  return null;
}

function writeManifest(baseDir, files) {
  const target = manifestPathFor(baseDir);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const manifest = {
    name: "plain-forge",
    version: readPkgVersion(),
    files: files.map(toPosix).sort(),
  };
  fs.writeFileSync(target, JSON.stringify(manifest, null, 2) + "\n");
}

// Remove now-empty directories from `dir` upward, stopping at (and never
// removing) stopAt.
function removeEmptyDirsUpward(dir, stopAt) {
  let cur = dir;
  while (cur !== stopAt && cur.startsWith(stopAt + path.sep)) {
    try {
      if (fs.readdirSync(cur).length > 0) break;
      fs.rmdirSync(cur);
      cur = path.dirname(cur);
    } catch {
      break;
    }
  }
}

// Files present in the prior manifest but absent from the fresh copy, that
// still exist on disk. Only paths plain-forge itself recorded are ever
// considered — user/third-party files are never in the manifest.
function collectPruneCandidates(baseDir, oldFiles, newFiles) {
  const keep = new Set(newFiles.map(toPosix));
  const candidates = [];
  for (const rel of oldFiles) {
    if (keep.has(toPosix(rel))) continue;
    if (fs.existsSync(path.join(baseDir, rel))) candidates.push(toPosix(rel));
  }
  return candidates;
}

function deleteForgeFile(baseDir, rel) {
  const target = path.join(baseDir, rel);
  try {
    fs.rmSync(target, { force: true });
    removeEmptyDirsUpward(path.dirname(target), baseDir);
    return true;
  } catch {
    return false;
  }
}

// Find every plain-forge install in cwd and $HOME. An install is recognized by
// its manifest, or — for installs predating the manifest — by the presence of
// the flagship skill.
function detectInstalls() {
  const installs = [];
  for (const scope of SCOPES) {
    const root = scope === "global" ? os.homedir() : process.cwd();
    for (const [agent, dirName] of Object.entries(AGENTS)) {
      const baseDir = path.join(root, dirName);
      if (!fs.existsSync(baseDir)) continue;
      const manifest = readManifest(baseDir);
      const isLegacy = !manifest && hasForgeSignature(baseDir);
      if (manifest || isLegacy) {
        installs.push({ agent, scope, baseDir, manifest });
      }
    }
  }
  return installs;
}

async function cmdInstall(args) {
  printBanner();

  let agent = args.agent;
  if (!agent) agent = await promptChoice("Which agent ?", Object.keys(AGENTS));
  if (!Object.hasOwn(AGENTS, agent)) {
    console.error(
      `unknown agent "${agent}". valid: ${Object.keys(AGENTS).join(", ")}`,
    );
    process.exit(2);
  }

  let scope = args.scope;
  if (!scope) scope = await promptChoice("Scope ?", SCOPES);
  if (!SCOPES.includes(scope)) {
    console.error(`unknown scope "${scope}". valid: ${SCOPES.join(", ")}`);
    process.exit(2);
  }

  const root = scope === "global" ? os.homedir() : process.cwd();
  const baseDir = path.join(root, AGENTS[agent]);

  const alreadyInstalled =
    readManifest(baseDir) !== null || hasForgeSignature(baseDir);
  if (alreadyInstalled) {
    console.error(`plain-forge is already installed in ${baseDir}.`);
    console.error(`run "plain-forge update" to refresh it.`);
    process.exit(1);
  }

  const { counts, files } = writeContent(baseDir);
  writeManifest(baseDir, files);

  console.log(`installed into ${baseDir}`);
  console.log(`  skills: ${counts.skills}`);
  console.log(`  rules:  ${counts.rules}`);
  console.log(`  docs:   ${counts.docs}`);
  console.log();
  printNextSteps(agent);
}

async function cmdUpdate(args) {
  printBanner();

  const installs = detectInstalls();
  if (installs.length === 0) {
    console.log(
      "no existing plain-forge installations found in this folder or your home directory.",
    );
    console.log(`run "plain-forge install" to set one up.`);
    return;
  }

  const version = readPkgVersion();
  let updated = 0;
  for (const inst of installs) {
    const hasManifest = inst.manifest != null;

    // The up-to-date check applies only to manifest-tracked installs. With no
    // manifest there is no recorded version to compare against, so the version
    // check is skipped and the install is always refreshed — a manifest is then
    // written for it at the end of this iteration (see writeManifest below).
    if (hasManifest && isUpToDate(inst.manifest.version, version)) {
      console.log(
        `${inst.agent} (${inst.scope}) is already up to date (v${inst.manifest.version}).`,
      );
      console.log();
      continue;
    }

    const oldFiles = inst.manifest?.files ?? [];
    const { counts, files } = writeContent(inst.baseDir);

    console.log(`updated ${inst.agent} (${inst.scope}) → ${inst.baseDir}`);
    console.log(
      `  skills: ${counts.skills}  rules: ${counts.rules}  docs: ${counts.docs}`,
    );

    // Pruning only applies to manifest-tracked installs. Each deprecated file
    // is confirmed individually before removal; denied files stay on disk and
    // remain tracked so the next update re-offers them.
    const kept = [];
    if (!hasManifest) {
      console.log(`  pruned: skipped (no manifest from prior install)`);
    } else {
      const candidates = collectPruneCandidates(inst.baseDir, oldFiles, files);
      let pruned = 0;
      for (const rel of candidates) {
        console.log(
          `  The file corresponds to a plain-forge file that has been deprecated or removed:`,
        );
        console.log(`    ${rel}`);
        const remove = args.yes
          ? true
          : await promptConfirm("  Please confirm its removal.");
        if (remove && deleteForgeFile(inst.baseDir, rel)) {
          pruned++;
        } else {
          kept.push(rel);
        }
      }
      console.log(
        `  pruned: ${pruned}${kept.length ? `  kept: ${kept.length}` : ""}`,
      );
    }

    // Manifest reflects what's actually on disk: the fresh files plus any
    // deprecated files the user chose to keep.
    writeManifest(inst.baseDir, files.concat(kept));
    console.log();
    updated++;
  }

  if (updated === 0) {
    console.log(
      `you are already using the up-to-date plain-forge (v${version}).`,
    );
  } else {
    console.log(`updated ${updated} installation(s) to v${version}.`);
  }
}

function printNextSteps(agent) {
  const bold = (s) => `\x1b[1;97m${s}\x1b[0m`;
  const dim = (s) => `\x1b[2m${s}\x1b[0m`;
  const plain = (s) => `\x1b[38;2;121;252;150m${s}\x1b[0m`;
  const codeplain = (s) => `\x1b[38;2;224;255;110m${s}\x1b[0m`;
  const link = (s) => `\x1b[4;38;2;95;175;255m${s}\x1b[0m`;

  console.log(`\x1b[1mnext steps:\x1b[0m`);
  console.log(
    `  1. open a project folder and start your ${agentLabel(agent)} session.`,
  );
  console.log(`  2. invoke one of:`);
  console.log(
    `       ${bold("forge-plain")}        — start a brand-new ${plain("***plain")} project from scratch`,
  );
  console.log(
    `       ${bold("init-plain-project")} — scaffold a minimal ${plain("***plain")} project to grow feature-by-feature`,
  );
  console.log(
    `       ${bold("add-feature")}        — add a feature to an existing ${plain("***plain")} project`,
  );
  console.log();
  console.log(
    `prerequisite: install the ${codeplain("codeplain")} CLI to render your specs into code — ${link("https://www.codeplain.ai/")}`,
  );
  console.log(
    `usage guide: ${link("https://github.com/Codeplain-ai/plain-forge#usage")}`,
  );
  console.log();
}

function agentLabel(agent) {
  switch (agent) {
    case "claude":
      return "Claude Code";
    case "codex":
      return "Codex";
    case "forgecode":
      return "ForgeCode";
    case "universal":
      return "AI coding agent";
    default:
      return "agent";
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || args._.length === 0) {
    usage();
    return;
  }
  const cmd = args._[0];
  switch (cmd) {
    case "install":
      await cmdInstall(args);
      break;
    case "update":
      await cmdUpdate(args);
      break;
    default:
      console.error(`unknown command "${cmd}"`);
      usage();
      process.exit(2);
  }
}

// Only run the CLI when executed directly — importing this module (e.g. from
// the test suite) must not trigger main() or process.exit().
// `__filename` (from import.meta.url) is realpath-resolved by Node, but
// process.argv[1] is the path as invoked — under npx / a global install it's a
// symlink in node_modules/.bin or the npx cache. Resolve both through realpath
// so the comparison survives symlinked bins; otherwise main() silently never
// runs (spinner, then nothing).
function isInvokedDirectly() {
  const invoked = process.argv[1];
  if (!invoked) return false;
  try {
    return fs.realpathSync(invoked) === __filename;
  } catch {
    return path.resolve(invoked) === __filename;
  }
}
const invokedDirectly = isInvokedDirectly();
if (invokedDirectly) {
  main().catch((err) => {
    if (err instanceof Error && err.message === "cancelled") {
      process.exit(130);
    }
    console.error(err instanceof Error ? (err.stack ?? err.message) : err);
    process.exit(1);
  });
}

export {
  AGENTS,
  SCOPES,
  CONTENT_DIRS,
  MANIFEST_REL,
  FORGE_SIGNATURE_SKILLS,
  hasForgeSignature,
  parseArgs,
  toPosix,
  readPkgVersion,
  compareVersions,
  isUpToDate,
  copyTreeTracked,
  writeContent,
  manifestPathFor,
  readManifest,
  writeManifest,
  removeEmptyDirsUpward,
  collectPruneCandidates,
  deleteForgeFile,
  detectInstalls,
  promptConfirm,
};
