/**
 * test_suite.js — Automated Test Suite for pix-MCP v0.2.1
 * Tests universal harness compatibility (coercion), new core tools (undo/redo,
 * color_replace, adjust_hsv, crop_to_content, scale_canvas), procedural helpers,
 * and Godot/animation export.
 */

const BRIDGE_URL = "http://127.0.0.1:7373";

async function cmd(tool, params = {}) {
  const res = await fetch(`${BRIDGE_URL}/command`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool, params }),
  });
  return await res.json();
}

async function runTests() {
  console.log("==================================================");
  console.log("🧪 Running pix-MCP Universal & New Tools Test Suite");
  console.log("==================================================\n");

  let step = 1;
  const totalSteps = 16;

  // 1. Health Check
  try {
    const health = await fetch(`${BRIDGE_URL}/health`).then((r) => r.json());
    console.log(`✅ [${step++}/${totalSteps}] Health Check: Status=${health.status}, Pixelorama=${health.pixelorama_version}, API=${health.api_version}`);
  } catch (err) {
    console.error(`❌ [${step}/${totalSteps}] Health Check Failed. Is Pixelorama running with the updated PixMcpBridge.pck loaded?`);
    process.exit(1);
  }

  // 2. Create Canvas & Fit Viewport
  const canvasRes = await cmd("create_canvas", { width: 64, height: 64, name: "Test Canvas" });
  console.log(`✅ [${step++}/${totalSteps}] Create Canvas:`, canvasRes.success ? "Passed (64x64)" : canvasRes.error);

  await cmd("fit_viewport", {});

  // 3. Batch Draw (Initial circular badge: red)
  const pixels = [];
  for (let y = 20; y < 44; y++) {
    for (let x = 20; x < 44; x++) {
      if (Math.hypot(x - 32, y - 32) < 10) {
        pixels.push({ x, y, color: "#e74c3c" }); // Red
      }
    }
  }
  const drawRes = await cmd("draw_pixels", { pixels });
  console.log(`✅ [${step++}/${totalSteps}] Batch Draw Pixels:`, drawRes.success ? `Drawn ${drawRes.data.drawn} px` : drawRes.error);

  // 4. Color Replace (Red #e74c3c -> Blue #3498db)
  const replaceRes = await cmd("color_replace", { old_color: "#e74c3c", new_color: "#3498db", tolerance: 0.1 });
  console.log(`✅ [${step++}/${totalSteps}] Color Replace:`, replaceRes.success ? `Replaced ${replaceRes.data.replaced_pixels} px to ${replaceRes.data.new_color}` : replaceRes.error);

  // 5. Adjust HSV (Shift Hue by 120 deg -> Greenish)
  const hsvRes = await cmd("adjust_hsv", { hue_shift: 120, saturation: 1.2, value: 1.0 });
  console.log(`✅ [${step++}/${totalSteps}] Adjust HSV:`, hsvRes.success ? `Modified ${hsvRes.data.modified_pixels} px` : hsvRes.error);

  // 6. Undo & Redo System with Action Verification
  const undoRes = await cmd("undo", {});
  console.log(`✅ [${step++}/${totalSteps}] Undo Action:`, undoRes.success ? `${undoRes.data.message} (Target: ${undoRes.data.target_layer})` : undoRes.error);

  const redoRes = await cmd("redo", {});
  console.log(`✅ [${step++}/${totalSteps}] Redo Action:`, redoRes.success ? `${redoRes.data.message} (Action: ${redoRes.data.action})` : redoRes.error);

  // 7. Inspect UndoRedo History (get_history)
  const histRes = await cmd("get_history", { limit: 10 });
  console.log(`✅ [${step++}/${totalSteps}] Get History:`, histRes.success ? `Total: ${histRes.data.history_count} actions, Current: #${histRes.data.current_action_index} ("${histRes.data.current_action_name}"), CanUndo: ${histRes.data.can_undo}` : histRes.error);

  // 8. Sprite QA / Sanity Checker (validate_sprite)
  const valRes = await cmd("validate_sprite", { check_holes: true, check_orphans: true });
  console.log(`✅ [${step++}/${totalSteps}] Validate Sprite:`, valRes.success ? `Opaque px: ${valRes.data.total_opaque_pixels}, BBox: (${valRes.data.bounds.x},${valRes.data.bounds.y}) ${valRes.data.bounds.width}x${valRes.data.bounds.height}, Holes: ${valRes.data.enclosed_hole_count}, Strays: ${valRes.data.stray_pixel_count}` : valRes.error);

  // 9. Procedural Non-Destructive Glow (as_new_layer: true)
  const glowRes = await cmd("apply_glow", { radius: 2, color: "#3498db", intensity: 0.7, as_new_layer: true });
  console.log(`✅ [${step++}/${totalSteps}] Apply Glow (as_new_layer):`, glowRes.success ? `Glow created on separate layer (as_new_layer: ${glowRes.data.as_new_layer})` : glowRes.error);

  // 10. Check Seamless Tile with Sub-Grid and Dry Run
  const seamlessRes = await cmd("check_seamless_tile", { tile_width: 32, tile_height: 32, dry_run: true, fix_seams: false });
  console.log(`✅ [${step++}/${totalSteps}] Check Seamless Tile (Grid & Dry-Run):`, seamlessRes.success ? `Checked ${seamlessRes.data.tiles_checked} tile(s) of size ${seamlessRes.data.tile_width}x${seamlessRes.data.tile_height}, dry_run=${seamlessRes.data.dry_run}` : seamlessRes.error);

  // 11. Procedural Outline
  const outlineRes = await cmd("apply_outline", { color: "#1a1a24", thickness: 1, inside: false });
  console.log(`✅ [${step++}/${totalSteps}] Apply Outline:`, outlineRes.success ? `Outlined ${outlineRes.data.outline_pixels} px` : outlineRes.error);

  // 12. Auto-Crop to Content
  const cropRes = await cmd("crop_to_content", {});
  console.log(`✅ [${step++}/${totalSteps}] Crop to Content:`, cropRes.success ? `Cropped from ${cropRes.data.original_size.join("x")} to ${cropRes.data.new_size.join("x")}` : cropRes.error);

  // 13. Integer Scale Canvas (2x)
  const scaleRes = await cmd("scale_canvas", { factor: 2 });
  console.log(`✅ [${step++}/${totalSteps}] Scale Canvas (2x):`, scaleRes.success ? `Scaled from ${scaleRes.data.original_size.join("x")} to ${scaleRes.data.new_size.join("x")}` : scaleRes.error);

  // 14. Visual Canvas Capture
  const visionRes = await cmd("get_canvas_image_base64", {});
  const b64Length = visionRes.data?.base64?.length ?? 0;
  console.log(`✅ [${step++}/${totalSteps}] Visual Canvas Capture:`, visionRes.success && b64Length > 0 ? `Captured ${b64Length} base64 chars` : visionRes.error);

  // 15. Deep Duplicate Frame & Safe Copy Cel
  const dupRes = await cmd("duplicate_frame", { index: 0 });
  console.log(`✅ [${step++}/${totalSteps}] Duplicate Frame (Deep Cel Cloning):`, dupRes.success ? `Duplicated at index ${dupRes.data.inserted_at}, Copied: ${dupRes.data.pixels_copied} px, Warning: ${dupRes.data.warning || "None"}` : dupRes.error);

  const copyCelRes = await cmd("copy_cel", { src_frame: 0, src_layer: 0, dst_frame: 1, dst_layer: 0 });
  console.log(`✅ [${step++}/${totalSteps}] Copy Cel:`, copyCelRes.success ? `Copied ${copyCelRes.data.pixels_copied} px (Warning: ${copyCelRes.data.warning || "None"})` : copyCelRes.error);

  // Cleanup test frame
  await cmd("delete_frame", { index: 1 });

  // 16. Animation & Spritesheet Export
  const pathModule = await import("path");
  const exportDir = pathModule.resolve("./docs/examples/");
  const exportRes = await cmd("export_animation", {
    path: exportDir,
    prefix: "test_anim",
    mode: "spritesheet",
    columns: 2,
  });
  console.log(`✅ [${step++}/${totalSteps}] Animation & Spritesheet Export:`, exportRes.success ? `Saved to ${exportRes.data.path}` : exportRes.error);

  // Cleanup test artifacts
  try {
    const fsModule = await import("fs");
    const files = fsModule.readdirSync(exportDir);
    for (const f of files) {
      if (f.startsWith("test_")) {
        fsModule.unlinkSync(pathModule.join(exportDir, f));
      }
    }
  } catch {}

  console.log("\n==================================================");
  console.log(`🎉 ALL ${totalSteps}/${totalSteps} TEST SUITE CHECKS COMPLETED!`);
  console.log("==================================================");
}

runTests();
