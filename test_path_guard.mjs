// Verification suite for mcp-server/src/utils/path_guard.ts (Issue #4 remediation)

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import {
  sanitizeAssetName,
  resolveSafeDirectory,
  resolveSafeOutputFile,
  resolveSafeInputFile,
} from "./mcp-server/dist/utils/path_guard.js";

function assert(cond, msg) {
  if (!cond) throw new Error(`Assertion failed: ${msg}`);
}

function assertThrows(fn, label) {
  let threw = false;
  try {
    fn();
  } catch {
    threw = true;
  }
  if (!threw) {
    throw new Error(`Expected failure for: ${label}`);
  }
}

const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "pix-mcp-guard-test-"));

try {
  // 1. Asset-name sanitization (Findings #5 & #6)
  assert(sanitizeAssetName("knight", "sprite_name") === "knight", "valid sprite_name");
  assert(sanitizeAssetName("Dungeon Tiles 16x16", "tileset_name") === "Dungeon Tiles 16x16", "valid tileset_name with spaces");
  assertThrows(() => sanitizeAssetName("../escape", "animation_name"), "dot-dot in animation_name");
  assertThrows(() => sanitizeAssetName("sub/path", "tileset_name"), "slash in tileset_name");
  assertThrows(() => sanitizeAssetName('idle"\n[ext_resource]', "animation_name"), ".tres quote/newline injection");
  assertThrows(() => sanitizeAssetName(".hidden", "sprite_name"), "leading dot in asset name");
  console.log("✅ [1/5] Asset-name sanitization blocks traversal & .tres injection while allowing normal names");

  // 2. Zero-config normal directories & PNG outputs work out of the box
  const gameDir = path.join(tmpRoot, "my.godot.game", "assets");
  const resolvedDir = resolveSafeDirectory(gameDir, "target_dir");
  assert(resolvedDir.endsWith(path.join("my.godot.game", "assets")), "normal game folder allowed");

  const outPng = resolveSafeOutputFile(path.join(gameDir, "tileset.png"), [".png"], "export_path");
  assert(outPng.endsWith("tileset.png"), "normal .png output allowed");
  console.log("✅ [2/5] Normal game project folders (including dotted folder names) work with zero config");

  // 3. System directories, sensitive dot-paths, dotfiles, and bad extensions are blocked
  assertThrows(() => resolveSafeDirectory("/etc/pix-test", "target_dir"), "/etc blocked");
  assertThrows(() => resolveSafeDirectory(path.join(os.homedir(), ".ssh"), "target_dir"), "~/.ssh blocked");
  assertThrows(() => resolveSafeDirectory(path.join(tmpRoot, ".git", "hooks"), "target_dir"), ".git blocked");
  assertThrows(() => resolveSafeOutputFile(path.join(tmpRoot, ".bashrc"), [".png"], "export_path"), "dotfile blocked");
  assertThrows(() => resolveSafeOutputFile(path.join(tmpRoot, "script.sh"), [".png"], "export_path"), "wrong extension blocked");
  assertThrows(() => resolveSafeInputFile("/dev/zero", [".png"], undefined, "file_path"), "/dev/zero blocked");
  console.log("✅ [3/5] System dirs, sensitive dot-folders (.ssh/.git/.config), and wrong extensions blocked");

  // 4. Symlinks pointing into restricted directories are caught and blocked
  const symToEtc = path.join(tmpRoot, "innocent_link");
  fs.symlinkSync("/etc", symToEtc);
  assertThrows(() => resolveSafeDirectory(path.join(symToEtc, "sub"), "target_dir"), "symlink to /etc blocked");
  console.log("✅ [4/5] Symlink escape into restricted directory blocked");

  // 5. Optional PIXELORAMA_MCP_ALLOWED_DIRS confines reads and writes when configured
  const allowedSubdir = path.join(tmpRoot, "allowed_workspace");
  const outsideSubdir = path.join(tmpRoot, "outside_workspace");
  fs.mkdirSync(allowedSubdir, { recursive: true });
  fs.mkdirSync(outsideSubdir, { recursive: true });

  const pngSample = path.join(allowedSubdir, "ok.png");
  const outsidePng = path.join(outsideSubdir, "nope.png");
  fs.writeFileSync(pngSample, Buffer.from([0x89, 0x50, 0x4e, 0x47]));
  fs.writeFileSync(outsidePng, Buffer.from([0x89, 0x50, 0x4e, 0x47]));

  process.env.PIXELORAMA_MCP_ALLOWED_DIRS = allowedSubdir;
  try {
    assert(resolveSafeInputFile(pngSample, [".png"]).endsWith("ok.png"), "inside allowed dir succeeds");
    assertThrows(() => resolveSafeInputFile(outsidePng, [".png"]), "outside allowed dir blocked");
    assertThrows(() => resolveSafeDirectory(outsideSubdir), "outside target_dir blocked");
  } finally {
    delete process.env.PIXELORAMA_MCP_ALLOWED_DIRS;
  }
  console.log("✅ [5/5] Optional PIXELORAMA_MCP_ALLOWED_DIRS confinement verified");

  console.log("\n🎉 All 5/5 path_guard security & usability checks passed!");
} finally {
  fs.rmSync(tmpRoot, { recursive: true, force: true });
}
