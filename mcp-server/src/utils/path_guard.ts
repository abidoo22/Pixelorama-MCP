/**
 * Zero-config file path & asset-name safety guardrails for local MCP tools.
 *
 * Keeps normal user workflows effortless (any regular project/Downloads/Documents folder works
 * out of the box), while blocking:
 * - Asset-name path traversal (`../`) and Godot `.tres` resource injection (`"`, `\n`, `[`, `]`)
 * - Reads/writes targeting system directories (`/etc`, `/proc`, `/dev`, `C:\Windows`, etc.)
 *   or sensitive hidden paths (`.ssh`, `.gnupg`, `.config`, `.git`, `.env`, etc.), including via symlinks
 * - Unexpected file extensions, non-regular files (device nodes / FIFOs), and oversized imports
 * - Optional strict root confinement when `PIXELORAMA_MCP_ALLOWED_DIRS` is set
 */

import * as fs from "fs";
import * as path from "path";

const DEFAULT_MAX_IMPORT_BYTES = 50 * 1024 * 1024; // 50 MB

const BLOCKED_POSIX_PREFIXES = [
  "/etc",
  "/bin",
  "/sbin",
  "/usr",
  "/lib",
  "/lib64",
  "/boot",
  "/proc",
  "/sys",
  "/dev",
  "/run",
  "/root",
  "/var/log",
  "/var/spool",
];

const BLOCKED_WINDOWS_PREFIXES = [
  "c:\\windows",
  "c:\\program files",
  "c:\\program files (x86)",
  "c:\\programdata",
];

const BLOCKED_SENSITIVE_SEGMENTS = new Set([
  ".git",
  ".github",
  ".ssh",
  ".gnupg",
  ".aws",
  ".azure",
  ".gcloud",
  ".kube",
  ".docker",
  ".npm",
  ".cargo",
  ".pypirc",
  ".netrc",
  ".env",
  ".bashrc",
  ".bash_profile",
  ".profile",
  ".zshrc",
  ".zprofile",
  ".config",
  ".mozilla",
  ".pki",
]);

function assertNoControlChars(value: string, fieldName: string): void {
  if (!value || !value.trim()) {
    throw new Error(`Invalid ${fieldName}: value must not be empty.`);
  }
  if (/[\x00-\x1f\x7f]/.test(value)) {
    throw new Error(`Invalid ${fieldName}: control characters are not allowed.`);
  }
}

/**
 * Validates simple asset identifiers (sprite_name, animation_name, tileset_name, filename prefixes)
 * so they cannot traverse directories (`..`, `/`, `\`) or inject syntax into Godot `.tres` files.
 */
export function sanitizeAssetName(raw: string, fieldName: string): string {
  assertNoControlChars(raw, fieldName);
  const trimmed = raw.trim();
  if (trimmed.length > 128) {
    throw new Error(`Invalid ${fieldName}: must be 128 characters or fewer.`);
  }
  if (
    trimmed.includes("/") ||
    trimmed.includes("\\") ||
    trimmed.includes("..") ||
    trimmed.startsWith(".") ||
    /["'`[\]\r\n]/.test(trimmed) ||
    !/^[A-Za-z0-9][A-Za-z0-9 _.-]*$/.test(trimmed)
  ) {
    throw new Error(
      `Invalid ${fieldName} "${raw}": use letters, numbers, spaces, underscores, hyphens, or single dots (no path slashes, "..", or quotes).`
    );
  }
  return trimmed;
}

/**
 * Resolves symlinks on the deepest existing ancestor of `targetPath` and appends any not-yet-created
 * child segments, preventing symlink escapes into restricted folders before directories/files exist.
 */
function resolveRealCandidate(targetPath: string): string {
  const abs = path.resolve(targetPath);
  const tailSegments: string[] = [];
  let cursor = abs;

  while (!fs.existsSync(cursor)) {
    const parent = path.dirname(cursor);
    if (parent === cursor) break;
    tailSegments.unshift(path.basename(cursor));
    cursor = parent;
  }

  let realBase = cursor;
  if (fs.existsSync(cursor)) {
    realBase = fs.realpathSync(cursor);
  }
  return tailSegments.length > 0 ? path.join(realBase, ...tailSegments) : realBase;
}

function getAllowedRoots(): string[] {
  const raw = process.env.PIXELORAMA_MCP_ALLOWED_DIRS?.trim();
  if (!raw) return [];
  const sep = process.platform === "win32" ? ";" : /[:;,]/;
  return raw
    .split(sep)
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      const abs = path.resolve(entry);
      return fs.existsSync(abs) ? fs.realpathSync(abs) : abs;
    });
}

function isWithinDirectory(candidatePath: string, rootDir: string): boolean {
  const rel = path.relative(rootDir, candidatePath);
  return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
}

function assertNotRestrictedPath(checkPath: string, fieldName: string): void {
  const normalizedPosix = checkPath.replace(/\\/g, "/");
  for (const prefix of BLOCKED_POSIX_PREFIXES) {
    if (normalizedPosix === prefix || normalizedPosix.startsWith(`${prefix}/`)) {
      throw new Error(`Refusing ${fieldName} "${checkPath}": access to system directory "${prefix}" is blocked.`);
    }
  }

  const lowerWin = checkPath.toLowerCase();
  for (const prefix of BLOCKED_WINDOWS_PREFIXES) {
    if (lowerWin === prefix || lowerWin.startsWith(`${prefix}\\`) || lowerWin.startsWith(`${prefix}/`)) {
      throw new Error(`Refusing ${fieldName} "${checkPath}": access to system directory is blocked.`);
    }
  }

  const segments = normalizedPosix.split("/").filter(Boolean);
  for (const seg of segments) {
    const lower = seg.toLowerCase();
    if (BLOCKED_SENSITIVE_SEGMENTS.has(lower) || lower.startsWith(".env.")) {
      throw new Error(
        `Refusing ${fieldName} "${checkPath}": access to protected hidden path "${seg}" is blocked.`
      );
    }
  }
}

function enforceAllowedRoots(realCandidate: string, fieldName: string): void {
  const allowedRoots = getAllowedRoots();
  if (allowedRoots.length === 0) return;

  const allowed = allowedRoots.some((root) => isWithinDirectory(realCandidate, root));
  if (!allowed) {
    throw new Error(
      `Refusing ${fieldName} "${realCandidate}": path is outside PIXELORAMA_MCP_ALLOWED_DIRS (${allowedRoots.join(", ")}).`
    );
  }
}

export function resolveSafeDirectory(dirPath: string, fieldName = "directory path"): string {
  assertNoControlChars(dirPath, fieldName);
  const logicalAbs = path.resolve(dirPath);
  const realAbs = resolveRealCandidate(logicalAbs);

  assertNotRestrictedPath(logicalAbs, fieldName);
  assertNotRestrictedPath(realAbs, fieldName);
  enforceAllowedRoots(realAbs, fieldName);

  if (fs.existsSync(realAbs) && !fs.statSync(realAbs).isDirectory()) {
    throw new Error(`Invalid ${fieldName} "${dirPath}": path exists and is not a directory.`);
  }
  return realAbs;
}

export function resolveSafeOutputFile(
  filePath: string,
  allowedExtensions: string[],
  fieldName = "output file path"
): string {
  assertNoControlChars(filePath, fieldName);
  const logicalAbs = path.resolve(filePath);
  const realAbs = resolveRealCandidate(logicalAbs);

  assertNotRestrictedPath(logicalAbs, fieldName);
  assertNotRestrictedPath(realAbs, fieldName);
  enforceAllowedRoots(realAbs, fieldName);

  const baseName = path.basename(realAbs);
  if (baseName.startsWith(".")) {
    throw new Error(`Refusing ${fieldName} "${filePath}": writing hidden dotfiles is blocked.`);
  }

  const normalizedAllowed = allowedExtensions.map((e) => e.toLowerCase());
  const ext = path.extname(baseName).toLowerCase();
  if (!normalizedAllowed.includes(ext)) {
    throw new Error(
      `Invalid ${fieldName} "${filePath}": expected file extension ${normalizedAllowed.join(" or ")}.`
    );
  }

  if (fs.existsSync(realAbs) && fs.statSync(realAbs).isDirectory()) {
    throw new Error(`Invalid ${fieldName} "${filePath}": target path is an existing directory.`);
  }
  return realAbs;
}

export function resolveSafeInputFile(
  filePath: string,
  allowedExtensions: string[],
  maxBytes = DEFAULT_MAX_IMPORT_BYTES,
  fieldName = "input file path"
): string {
  assertNoControlChars(filePath, fieldName);
  const logicalAbs = path.resolve(filePath);
  assertNotRestrictedPath(logicalAbs, fieldName);

  if (!fs.existsSync(logicalAbs)) {
    throw new Error(`File not found at path: ${filePath}`);
  }

  const realAbs = fs.realpathSync(logicalAbs);
  assertNotRestrictedPath(realAbs, fieldName);
  enforceAllowedRoots(realAbs, fieldName);

  const stat = fs.statSync(realAbs);
  if (!stat.isFile()) {
    throw new Error(`Invalid ${fieldName} "${filePath}": path must be a regular file.`);
  }
  if (stat.size > maxBytes) {
    throw new Error(
      `Refusing ${fieldName} "${filePath}": file size (${stat.size} bytes) exceeds safety limit (${maxBytes} bytes).`
    );
  }

  const normalizedAllowed = allowedExtensions.map((e) => e.toLowerCase());
  const ext = path.extname(realAbs).toLowerCase();
  if (!normalizedAllowed.includes(ext)) {
    throw new Error(
      `Invalid ${fieldName} "${filePath}": expected file extension ${normalizedAllowed.join(" or ")}.`
    );
  }

  return realAbs;
}
