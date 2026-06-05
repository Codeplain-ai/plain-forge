import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { after, beforeEach, describe, test } from "node:test";

import {
  collectPruneCandidates,
  compareVersions,
  copyTreeTracked,
  deleteForgeFile,
  detectInstalls,
  FORGE_SIGNATURE_SKILLS,
  hasForgeSignature,
  isUpToDate,
  parseArgs,
  readManifest,
  removeEmptyDirsUpward,
  toPosix,
  writeManifest,
} from "../bin/cli.mjs";

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), "..");
const CLI = path.join(repoRoot, "bin", "cli.mjs");

// All temp dirs created during the run, cleaned up at the end.
const tmpDirs = [];
function mkTmp(prefix = "pf-test-") {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  tmpDirs.push(dir);
  return dir;
}
function write(file, contents = "x") {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, contents);
}
// Plant a manifest-less plain-forge install: all flagship skill dirs present.
function plantLegacySignature(baseDir) {
  for (const skill of FORGE_SIGNATURE_SKILLS) {
    write(path.join(baseDir, "skills", skill, "SKILL.md"), "legacy");
  }
}
// Rewrite an existing manifest's version (and optionally append files) to
// simulate an older install that `update` should refresh.
function ageManifest(baseDir, version, extraFiles = []) {
  const p = path.join(baseDir, ".plain-forge", "manifest.json");
  const m = JSON.parse(fs.readFileSync(p, "utf8"));
  m.version = version;
  m.files = [...m.files, ...extraFiles];
  fs.writeFileSync(p, JSON.stringify(m, null, 2));
}

after(() => {
  for (const dir of tmpDirs) fs.rmSync(dir, { recursive: true, force: true });
});

describe("parseArgs", () => {
  test("parses commands, flags, and values", () => {
    const a = parseArgs(["install", "--agent", "claude", "--scope", "global"]);
    assert.deepEqual(a._, ["install"]);
    assert.equal(a.agent, "claude");
    assert.equal(a.scope, "global");
  });

  test("recognizes -y / --yes and -h / --help", () => {
    assert.equal(parseArgs(["update", "-y"]).yes, true);
    assert.equal(parseArgs(["update", "--yes"]).yes, true);
    assert.equal(parseArgs(["-h"]).help, true);
    assert.equal(parseArgs(["--help"]).help, true);
    assert.equal(parseArgs(["update"]).yes, undefined);
  });
});

describe("toPosix", () => {
  test("normalizes OS separators to forward slashes", () => {
    assert.equal(toPosix(path.join("skills", "a", "b.md")), "skills/a/b.md");
  });
});

describe("compareVersions", () => {
  test("orders dotted numeric versions", () => {
    assert.equal(compareVersions("1.0.10", "1.0.9"), 1);
    assert.equal(compareVersions("1.0.9", "1.0.10"), -1);
    assert.equal(compareVersions("1.2.0", "1.2.0"), 0);
    assert.equal(compareVersions("1.1", "1.1.0"), 0); // missing parts → 0
  });

  test("returns null when a version is not purely numeric", () => {
    assert.equal(compareVersions("unknown", "1.0.0"), null);
    assert.equal(compareVersions("1.0.0", "1.0.0-beta"), null);
  });
});

describe("isUpToDate", () => {
  test("true when current did not increase over installed", () => {
    assert.equal(isUpToDate("1.0.10", "1.0.10"), true); // equal
    assert.equal(isUpToDate("1.0.10", "1.0.9"), true); // current older
  });
  test("false when current is newer or indeterminate", () => {
    assert.equal(isUpToDate("1.0.9", "1.0.10"), false);
    assert.equal(isUpToDate(undefined, "1.0.10"), false);
    assert.equal(isUpToDate("unknown", "1.0.10"), false);
  });
});

describe("copyTreeTracked", () => {
  test("copies files recursively and returns relative paths", () => {
    const src = mkTmp();
    const dest = mkTmp();
    write(path.join(src, "top.md"));
    write(path.join(src, "nested", "deep", "leaf.md"));

    const written = copyTreeTracked(src, dest).map(toPosix).sort();
    assert.deepEqual(written, ["nested/deep/leaf.md", "top.md"]);
    assert.ok(fs.existsSync(path.join(dest, "nested", "deep", "leaf.md")));
  });

  test("dereferences a symlinked directory into real files", () => {
    const src = mkTmp();
    const real = mkTmp();
    write(path.join(real, "inner.md"), "real");
    fs.symlinkSync(real, path.join(src, "linked"));

    const dest = mkTmp();
    const written = copyTreeTracked(src, dest).map(toPosix);
    assert.deepEqual(written, ["linked/inner.md"]);
    const copied = path.join(dest, "linked", "inner.md");
    assert.equal(fs.lstatSync(copied).isSymbolicLink(), false);
    assert.equal(fs.readFileSync(copied, "utf8"), "real");
  });

  test("returns empty list for a missing source", () => {
    assert.deepEqual(copyTreeTracked(path.join(mkTmp(), "nope"), mkTmp()), []);
  });
});

describe("manifest read/write", () => {
  test("round-trips files (sorted, posix) with name and version", () => {
    const base = mkTmp();
    writeManifest(base, ["skills/b.md", "rules/a.md", "skills/a.md"]);
    const m = readManifest(base);
    assert.equal(m.name, "plain-forge");
    assert.match(m.version, /\d+\.\d+\.\d+/);
    assert.deepEqual(m.files, ["rules/a.md", "skills/a.md", "skills/b.md"]);
  });

  test("returns null when absent or malformed", () => {
    const base = mkTmp();
    assert.equal(readManifest(base), null);
    write(path.join(base, ".plain-forge", "manifest.json"), "{ not json");
    assert.equal(readManifest(base), null);
  });
});

describe("collectPruneCandidates", () => {
  test("only returns old files that are gone and still on disk", () => {
    const base = mkTmp();
    write(path.join(base, "skills", "stale.md"));
    write(path.join(base, "skills", "kept.md"));
    // "skills/missing.md" is in the manifest but not on disk → not a candidate.
    const candidates = collectPruneCandidates(
      base,
      ["skills/stale.md", "skills/kept.md", "skills/missing.md"],
      ["skills/kept.md"],
    );
    assert.deepEqual(candidates, ["skills/stale.md"]);
  });
});

describe("deleteForgeFile + removeEmptyDirsUpward", () => {
  test("removes the file and prunes now-empty parent dirs up to base", () => {
    const base = mkTmp();
    const rel = path.join("skills", "gone", "x.md");
    write(path.join(base, rel));

    assert.equal(deleteForgeFile(base, rel), true);
    assert.equal(fs.existsSync(path.join(base, rel)), false);
    assert.equal(fs.existsSync(path.join(base, "skills", "gone")), false);
    // base itself is never removed.
    assert.equal(fs.existsSync(base), true);
  });

  test("stops at a non-empty directory and never touches base", () => {
    const base = mkTmp();
    write(path.join(base, "skills", "a", "x.md"));
    write(path.join(base, "skills", "a", "y.md"));
    deleteForgeFile(base, path.join("skills", "a", "x.md"));
    // sibling kept → dir survives.
    assert.equal(fs.existsSync(path.join(base, "skills", "a", "y.md")), true);

    removeEmptyDirsUpward(path.join(base, "skills", "a"), base);
    assert.equal(fs.existsSync(path.join(base, "skills", "a")), true);
  });
});

describe("hasForgeSignature", () => {
  test("true only when every flagship skill is present", () => {
    const base = mkTmp();
    // A subset is not enough — avoids misdetecting an unrelated agent dir.
    write(path.join(base, "skills", FORGE_SIGNATURE_SKILLS[0], "SKILL.md"));
    assert.equal(hasForgeSignature(base), false);

    plantLegacySignature(base);
    assert.equal(hasForgeSignature(base), true);
  });
});

describe("detectInstalls", () => {
  const realCwd = process.cwd();
  const realHome = process.env.HOME;

  beforeEach(() => {
    process.chdir(realCwd);
    process.env.HOME = realHome;
  });
  after(() => {
    process.chdir(realCwd);
    process.env.HOME = realHome;
  });

  test("finds manifest-tracked and legacy installs across both scopes", () => {
    const project = mkTmp();
    const home = mkTmp();
    process.chdir(project);
    process.env.HOME = home;

    // project/.claude → manifest-tracked
    writeManifest(path.join(project, ".claude"), ["skills/x.md"]);
    // home/.codex → legacy (all flagship skills, no manifest)
    plantLegacySignature(path.join(home, ".codex"));
    // home/.agents → not plain-forge: one flagship skill + an unrelated one,
    // but not the full signature → ignored
    write(path.join(home, ".agents", "skills", "forge-plain", "SKILL.md"));
    write(path.join(home, ".agents", "skills", "someone-else", "SKILL.md"));

    const found = detectInstalls().map((i) => `${i.agent}:${i.scope}`).sort();
    assert.deepEqual(found, ["claude:project", "codex:global"]);

    const claude = detectInstalls().find((i) => i.agent === "claude");
    assert.ok(claude.manifest, "manifest install carries its manifest");
    const codex = detectInstalls().find((i) => i.agent === "codex");
    assert.equal(codex.manifest, null, "legacy install has no manifest");
  });

  test("returns nothing when neither scope has an install", () => {
    process.chdir(mkTmp());
    process.env.HOME = mkTmp();
    assert.deepEqual(detectInstalls(), []);
  });
});

// ── Black-box integration tests: spawn the real CLI in an isolated HOME/cwd ──

function runCli(args, { cwd, home, input } = {}) {
  return spawnSync("node", [CLI, ...args], {
    cwd,
    input,
    encoding: "utf8",
    env: { ...process.env, HOME: home, USERPROFILE: home },
  });
}

describe("cli install (integration)", () => {
  test("fresh install writes content + manifest, refuses re-install, allows other agent", () => {
    const project = mkTmp();
    const home = mkTmp();

    const first = runCli(["install", "--agent", "claude", "--scope", "project"], {
      cwd: project,
      home,
    });
    assert.equal(first.status, 0, first.stderr);
    const manifest = readManifest(path.join(project, ".claude"));
    assert.ok(manifest && manifest.files.length > 0);
    assert.ok(
      fs.existsSync(path.join(project, ".claude", "skills", "forge-plain")),
    );

    // The reported skill count is the number of skill DIRECTORIES, not the
    // total file count (a skill can span several files).
    const skillDirs = fs
      .readdirSync(path.join(repoRoot, "forge", "skills"), {
        withFileTypes: true,
      })
      .filter((e) => e.isDirectory()).length;
    assert.match(first.stdout, new RegExp(`skills:\\s+${skillDirs}\\b`));

    // Re-installing the same agent/scope is refused.
    const again = runCli(["install", "--agent", "claude", "--scope", "project"], {
      cwd: project,
      home,
    });
    assert.equal(again.status, 1);
    assert.match(again.stderr, /already installed/);

    // A different agent into the same folder still works.
    const codex = runCli(["install", "--agent", "codex", "--scope", "project"], {
      cwd: project,
      home,
    });
    assert.equal(codex.status, 0, codex.stderr);
    assert.ok(fs.existsSync(path.join(project, ".codex", "skills")));
  });
});

describe("cli update (integration)", () => {
  test("no installs → guidance message, exit 0", () => {
    const res = runCli(["update"], { cwd: mkTmp(), home: mkTmp() });
    assert.equal(res.status, 0, res.stderr);
    assert.match(res.stdout, /no existing plain-forge installations/);
  });

  test("auto-detects an older install and refreshes it", () => {
    const project = mkTmp();
    const home = mkTmp();
    assert.equal(
      runCli(["install", "--agent", "claude", "--scope", "project"], {
        cwd: project,
        home,
      }).status,
      0,
    );
    // Simulate an install from an earlier release so update has work to do.
    ageManifest(path.join(project, ".claude"), "0.0.1");

    const res = runCli(["update"], { cwd: project, home });
    assert.equal(res.status, 0, res.stderr);
    assert.match(res.stdout, /updated claude \(project\)/);
    assert.match(res.stdout, /updated 1 installation\(s\)/);
  });

  test("reports up-to-date when the version did not increase", () => {
    const project = mkTmp();
    const home = mkTmp();
    runCli(["install", "--agent", "claude", "--scope", "project"], {
      cwd: project,
      home,
    });

    // Manifest version equals the current package version → nothing to do.
    const res = runCli(["update"], { cwd: project, home });
    assert.equal(res.status, 0, res.stderr);
    assert.match(res.stdout, /claude \(project\) is already up to date/);
    assert.match(res.stdout, /already using the up-to-date plain-forge/);
    assert.doesNotMatch(res.stdout, /updated 1 installation\(s\)/);
  });

  test("--yes prunes a deprecated file; user files are never touched", () => {
    const project = mkTmp();
    const home = mkTmp();
    runCli(["install", "--agent", "claude", "--scope", "project"], {
      cwd: project,
      home,
    });

    const base = path.join(project, ".claude");
    // Inject a stale file recorded in the manifest, plus a user-owned skill.
    const stale = path.join(base, "skills", "deprecated-skill.md");
    write(stale, "stale");
    const mine = path.join(base, "skills", "my-skill", "SKILL.md");
    write(mine, "mine");
    // Age the manifest (older version) so update runs, and track the stale file.
    ageManifest(base, "0.0.1", ["skills/deprecated-skill.md"]);

    const res = runCli(["update", "--yes"], { cwd: project, home });
    assert.equal(res.status, 0, res.stderr);
    assert.equal(fs.existsSync(stale), false, "deprecated file pruned");
    assert.equal(fs.existsSync(mine), true, "user file untouched");
    const after = readManifest(base);
    assert.ok(!after.files.includes("skills/deprecated-skill.md"));
  });

  test("non-interactive without --yes keeps deprecated files and keeps tracking them", () => {
    const project = mkTmp();
    const home = mkTmp();
    runCli(["install", "--agent", "claude", "--scope", "project"], {
      cwd: project,
      home,
    });

    const base = path.join(project, ".claude");
    const stale = path.join(base, "skills", "deprecated-skill.md");
    write(stale, "stale");
    // Age the manifest so update runs, and track the stale file.
    ageManifest(base, "0.0.1", ["skills/deprecated-skill.md"]);

    // No TTY (spawned, no input) and no --yes → promptConfirm defaults to "no".
    const res = runCli(["update"], { cwd: project, home, input: "" });
    assert.equal(res.status, 0, res.stderr);
    assert.equal(fs.existsSync(stale), true, "deprecated file kept");
    const after = readManifest(base);
    assert.ok(
      after.files.includes("skills/deprecated-skill.md"),
      "kept file stays tracked for the next update",
    );
  });

  test("legacy install (no manifest) is refreshed overwrite-only", () => {
    const project = mkTmp();
    const home = mkTmp();
    const base = path.join(project, ".claude");
    // Simulate a pre-manifest install: all flagship skills present, no manifest.
    plantLegacySignature(base);
    const orphan = path.join(base, "skills", "orphan.md");
    write(orphan, "orphan");

    const res = runCli(["update"], { cwd: project, home });
    assert.equal(res.status, 0, res.stderr);
    // No manifest → version check is skipped, so it is refreshed (never
    // reported "up to date") even though we run the current package version.
    assert.doesNotMatch(res.stdout, /already up to date/);
    assert.match(res.stdout, /updated claude \(project\)/);
    assert.match(res.stdout, /pruned: skipped/);
    assert.equal(fs.existsSync(orphan), true, "nothing pruned without manifest");
    // A manifest is created at the end, stamped with the current version, so
    // the next update can use the version check and prune.
    const created = readManifest(base);
    assert.ok(created, "gains a manifest going forward");
    assert.match(created.version, /\d+\.\d+\.\d+/);
  });
});
