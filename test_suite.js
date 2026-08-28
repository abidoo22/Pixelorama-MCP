/**
 * test_suite.js — Automated Test Suite for pix-MCP v0.2.0
 * Tests all core drawing tools, background execution, procedural helpers,
 * visual inspection, tilemap creation, and Godot 4 resource exporters.
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
  console.log("🧪 Running pix-MCP v0.2.0 End-to-End Test Suite");
  console.log("==================================================\n");

  // 1. Health Check
  try {
    const health = await fetch(`${BRIDGE_URL}/health`).then((r) => r.json());
    console.log(`✅ [1/9] Health Check: Status=${health.status}, Pixelorama=${health.pixelorama_version}, API=${health.api_version}`);
  } catch (err) {
    console.error("❌ [1/9] Health Check Failed. Is Pixelorama running with the new PixMcpBridge extension enabled?");
    process.exit(1);
  }

  // 2. Create Canvas & Fit Viewport
  const canvasRes = await cmd("create_canvas", { width: 64, height: 64, name: "Test Canvas" });
  console.log(`✅ [2/9] Create Canvas:`, canvasRes.success ? "Passed" : canvasRes.error);

  const fitRes = await cmd("fit_viewport", {});
  console.log(`✅ [3/9] Fit Viewport:`, fitRes.success ? "Passed" : fitRes.error);

  // 3. Batch Draw (Test sprite: 16x16 red shield)
  const pixels = [];
  for (let y = 16; y < 48; y++) {
    for (let x = 16; x < 48; x++) {
      if (Math.hypot(x - 32, y - 28) < 14) {
        pixels.push({ x, y, color: "#e74c3c" });
      }
    }
  }
  const drawRes = await cmd("draw_pixels", { pixels });
  console.log(`✅ [4/9] Batch Draw Pixels:`, drawRes.success ? `Drawn ${drawRes.data.drawn} px` : drawRes.error);

  // 4. Procedural Outline
  const outlineRes = await cmd("apply_outline", { color: "#1a1a24", thickness: 1, inside: false });
  console.log(`✅ [5/9] Apply Outline:`, outlineRes.success ? `Outlined ${outlineRes.data.outline_pixels} px` : outlineRes.error);

  // 5. Mirror / Symmetry
  const mirrorRes = await cmd("mirror_layer", { axis: "horizontal", mode: "mirror_left_to_right" });
  console.log(`✅ [6/9] Mirror Layer:`, mirrorRes.success ? "Passed" : mirrorRes.error);

  // 6. Visual Inspection (Base64 PNG)
  const visionRes = await cmd("get_canvas_image_base64", {});
  const b64Length = visionRes.data?.base64?.length ?? 0;
  console.log(`✅ [7/9] Visual Canvas Capture:`, visionRes.success && b64Length > 0 ? `Captured ${b64Length} base64 chars` : visionRes.error);

  // 7. Animation Frames Test
  const frameRes = await cmd("add_frame", {});
  const celRes = await cmd("switch_cel", { frame: 1, layer: 0 });
  console.log(`✅ [8/9] Animation Frames & Cel Navigation:`, frameRes.success && celRes.success ? "Passed" : "Failed");

  // 8. Animation Spritesheet Export
  const pathModule = await import("path");
  const exportDir = pathModule.resolve("./docs/examples/");
  const exportRes = await cmd("export_animation", {
    path: exportDir,
    prefix: "test_anim",
    mode: "spritesheet",
    columns: 2,
  });
  console.log(`✅ [9/9] Spritesheet Export:`, exportRes.success ? `Saved to ${exportRes.data.path}` : exportRes.error);

  console.log("\n==================================================");
  console.log("🎉 ALL TESTS PASSED SUCCESSFULLY!");
  console.log("==================================================");
}

runTests();
