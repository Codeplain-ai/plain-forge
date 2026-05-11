import fs from "node:fs";
import path from "node:path";

export interface BuildContext {
  repoRoot: string;
  forgeDir: string;
  runtimeDir: string;
  templatesDir: string;
  log: (msg: string) => void;
}

export interface Runtime {
  /** Files and directories the runtime owns inside the repo root. Used by clean. */
  managedPaths: string[];
  /** Build the runtime's outputs into the repo root. */
  build: (ctx: BuildContext) => Promise<void> | void;
}

/** Recursively remove a file, symlink, or directory; tolerate missing paths. */
export function rmrf(target: string): void {
  if (!fs.existsSync(target) && !isSymlink(target)) return;
  fs.rmSync(target, { recursive: true, force: true });
}

/** True iff `target` is a symlink (even if dangling). */
export function isSymlink(target: string): boolean {
  try {
    return fs.lstatSync(target).isSymbolicLink();
  } catch {
    return false;
  }
}

/** mkdir -p */
export function ensureDir(dir: string): void {
  fs.mkdirSync(dir, { recursive: true });
}

/**
 * Create a relative symlink at `linkPath` pointing at `targetPath`.
 * Both paths are absolute; the on-disk symlink stores the relative form so the
 * tree is portable across clones and checkouts. Idempotent: replaces existing
 * symlinks; refuses to overwrite a real file/dir to avoid surprises.
 */
export function symlinkRelative(linkPath: string, targetPath: string): void {
  const linkDir = path.dirname(linkPath);
  const relative = path.relative(linkDir, targetPath);

  if (isSymlink(linkPath)) {
    const existing = fs.readlinkSync(linkPath);
    if (existing === relative) return;
    fs.unlinkSync(linkPath);
  } else if (fs.existsSync(linkPath)) {
    throw new Error(
      `Refusing to overwrite non-symlink at ${linkPath} (would create symlink -> ${relative})`,
    );
  }

  ensureDir(linkDir);
  fs.symlinkSync(relative, linkPath);
}

/** Copy a single file, preserving the source file's mode. Overwrites destination. */
export function copyFile(src: string, dest: string): void {
  ensureDir(path.dirname(dest));
  fs.copyFileSync(src, dest);
  const srcMode = fs.statSync(src).mode;
  fs.chmodSync(dest, srcMode);
}
