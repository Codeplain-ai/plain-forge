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

function usage() {
  console.log(`Usage: plain-forge install [options]

Options:
  --agent <claude|codex|forgecode|universal>   Target agent layout
  --scope <project|global>                     Install into cwd or $HOME
  -h, --help                                   Show this help

Examples:
  plain-forge install --agent claude --scope project
  plain-forge install --agent universal --scope global

Missing flags are prompted interactively.`);
}

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--agent") out.agent = argv[++i];
    else if (a === "--scope") out.scope = argv[++i];
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
        output.write(`  \x1b[32m${choices[index]}\x1b[0m\n`);
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

function copyTree(srcDir, destDir) {
  if (!fs.existsSync(srcDir)) return 0;
  fs.mkdirSync(destDir, { recursive: true });
  let count = 0;
  for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
    const src = path.join(srcDir, entry.name);
    const dest = path.join(destDir, entry.name);
    if (entry.isDirectory()) {
      fs.cpSync(src, dest, { recursive: true, force: true, dereference: true });
    } else {
      fs.copyFileSync(src, dest);
    }
    count++;
  }
  return count;
}

async function cmdInstall(args) {
  let agent = args.agent;
  if (!agent) agent = await promptChoice("Which agent?", Object.keys(AGENTS));
  if (!Object.hasOwn(AGENTS, agent)) {
    console.error(
      `unknown agent "${agent}". valid: ${Object.keys(AGENTS).join(", ")}`,
    );
    process.exit(2);
  }

  let scope = args.scope;
  if (!scope) scope = await promptChoice("Scope?", SCOPES);
  if (!SCOPES.includes(scope)) {
    console.error(`unknown scope "${scope}". valid: ${SCOPES.join(", ")}`);
    process.exit(2);
  }

  const root = scope === "global" ? os.homedir() : process.cwd();
  const baseDir = path.join(root, AGENTS[agent]);

  const skillsCount = copyTree(
    path.join(forgeDir, "skills"),
    path.join(baseDir, "skills"),
  );
  const rulesCount = copyTree(
    path.join(forgeDir, "rules"),
    path.join(baseDir, "rules"),
  );
  const docsCount = copyTree(
    path.join(forgeDir, "docs"),
    path.join(baseDir, "docs"),
  );

  console.log(`installed into ${baseDir}`);
  console.log(`  skills: ${skillsCount}`);
  console.log(`  rules:  ${rulesCount}`);
  console.log(`  docs:   ${docsCount}`);
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
    default:
      console.error(`unknown command "${cmd}"`);
      usage();
      process.exit(2);
  }
}

main().catch((err) => {
  if (err instanceof Error && err.message === "cancelled") {
    process.exit(130);
  }
  console.error(err instanceof Error ? (err.stack ?? err.message) : err);
  process.exit(1);
});
