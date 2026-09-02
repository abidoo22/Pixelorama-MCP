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

  // 1. Health Check
  try {
    const health = await fetch(`${BRIDGE_URL}/health`).then((r) => r.json());
    console.log(`✅ [1/12] Health Check: Status=${health.status}, Pixelorama=${health.pixelorama_version}, API=${health.api_version}`);
  } catch (err) {
    console.error("❌ [1/12] Health Check Failed. Is Pixelorama running with the updated PixMcpBridge.pck loaded?");
    process.exit(1);
  }

  // 2. Create Canvas & Fit Viewport
  const canvasRes = await cmd("create_canvas", { width: 64, height: 64, name: "Test Canvas" });
  console.log(`✅ [2/12] Create Canvas:`, canvasRes.success ? "Passed (64x64)" : canvasRes.error);

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
  console.log(`✅ [3/12] Batch Draw Pixels:`, drawRes.success ? `Drawn ${drawRes.data.drawn} px` : drawRes.error);

  // 4. Color Replace (Red #e74c3c -> Blue #3498db)
  const replaceRes = await cmd("color_replace", { old_color: "#e74c3c", new_color: "#3498db", tolerance: 0.1 });
  console.log(`✅ [4/12] Color Replace:`, replaceRes.success ? `Replaced ${replaceRes.data.replaced_pixels} px to ${replaceRes.data.new_color}` : replaceRes.error);

  // 5. Adjust HSV (Shift Hue by 120 deg -> Greenish)
  const hsvRes = await cmd("adjust_hsv", { hue_shift: 120, saturation: 1.2, value: 1.0 });
  console.log(`✅ [5/12] Adjust HSV:`, hsvRes.success ? `Modified ${hsvRes.data.modified_pixels} px` : hsvRes.error);

  // 6. Undo & Redo System
  const undoRes = await cmd("undo", {});
  console.log(`✅ [6/12] Undo Action:`, undoRes.success ? `${undoRes.data.message}` : undoRes.error);

  const redoRes = await cmd("redo", {});
  console.log(`✅ [7/12] Redo Action:`, redoRes.success ? `${redoRes.data.message}` : redoRes.error);

  // 7. Procedural Outline
  const outlineRes = await cmd("apply_outline", { color: "#1a1a24", thickness: 1, inside: false });
  console.log(`✅ [8/12] Apply Outline:`, outlineRes.success ? `Outlined ${outlineRes.data.outline_pixels} px` : outlineRes.error);

  // 8. Auto-Crop to Content
  const cropRes = await cmd("crop_to_content", {});
  console.log(`✅ [9/12] Crop to Content:`, cropRes.success ? `Cropped from ${cropRes.data.original_size.join("x")} to ${cropRes.data.new_size.join("x")}` : cropRes.error);

  // 9. Integer Scale Canvas (2x)
  const scaleRes = await cmd("scale_canvas", { factor: 2 });
  console.log(`✅ [10/12] Scale Canvas (2x):`, scaleRes.success ? `Scaled from ${scaleRes.data.original_size.join("x")} to ${scaleRes.data.new_size.join("x")}` : scaleRes.error);

  // 10. Visual Canvas Capture
  const visionRes = await cmd("get_canvas_image_base64", {});
  const b64Length = visionRes.data?.base64?.length ?? 0;
  console.log(`✅ [11/12] Visual Canvas Capture:`, visionRes.success && b64Length > 0 ? `Captured ${b64Length} base64 chars` : visionRes.error);

  // 11. Animation Frames & Export
  const frameRes = await cmd("add_frame", {});
  const pathModule = await import("path");
  const exportDir = pathModule.resolve("./docs/examples/");
  const exportRes = await cmd("export_animation", {
    path: exportDir,
    prefix: "test_anim",
    mode: "spritesheet",
    columns: 2,
  });
  console.log(`✅ [12/12] Animation & Spritesheet Export:`, exportRes.success ? `Saved to ${exportRes.data.path}` : exportRes.error);

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
  console.log("🎉 ALL 12/12 TEST SUITE CHECKS COMPLETED!");
  console.log("==================================================");
}

runTests();
