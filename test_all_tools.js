/**
 * test_all_tools.js — Comprehensive verification suite for all 50+ tools in pix-MCP.
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

async function run() {
  console.log("==================================================");
  console.log("🧪 Comprehensive Verification of ALL pix-MCP Tools");
  console.log("==================================================\n");

  let passed = 0;
  let failed = 0;

  async function test(name, tool, params, validate = (r) => r.success) {
    process.stdout.write(`Testing [${tool}] (${name})... `);
    try {
      const res = await cmd(tool, params);
      if (validate(res)) {
        console.log(`✅ Passed`);
        passed++;
      } else {
        console.log(`❌ Failed: ${res.error || JSON.stringify(res)}`);
        failed++;
      }
    } catch (err) {
      console.log(`❌ Exception: ${err.message}`);
      failed++;
    }
  }

  // 1. Canvas & Viewport
  await test("Create 64x64 Canvas", "create_canvas", { width: 64, height: 64, name: "TestProject" });
  await test("Get Canvas Info", "get_canvas_info", {}, (r) => r.success && r.data?.width === 64);
  await test("Fit Viewport", "fit_viewport", {});

  // 2. Colors & Palettes
  await test("Set Color (Foreground)", "set_color", { color: "#ff5500", button: 0 });
  await test("Get Colors", "get_color", {}, (r) => r.success && r.data?.foreground);
  await test("Create Palette", "create_palette", { name: "TestPal", width: 4, height: 4, is_global: true });
  await test("Add Palette Color", "add_palette_color", { color: "#00ff88" });
  await test("Set Palette Color", "set_palette_color", { index: 0, color: "#ff0088" });
  await test("Get Palette Colors", "get_palette_colors", {}, (r) => r.success && Array.isArray(r.data?.colors));

  // 3. Drawing Primitives
  await test("Draw Single Pixel", "draw_pixel", { x: 10, y: 10, color: "#ffffff" });
  await test("Draw Line", "draw_line", { x1: 5, y1: 5, x2: 25, y2: 5, color: "#ffffff" });
  await test("Draw Rect (Filled)", "draw_rect", { x: 15, y: 15, width: 20, height: 20, color: "#e74c3c", filled: true });
  await test("Draw Rect (Outline)", "draw_rect", { x: 40, y: 15, width: 15, height: 15, color: "#f1c40f", filled: false });
  await test("Draw Ellipse", "draw_ellipse", { cx: 32, cy: 45, rx: 10, ry: 8, color: "#3498db", filled: true });
  await test("Draw Path", "draw_path", { points: [{ x: 5, y: 50 }, { x: 15, y: 55 }, { x: 25, y: 50 }], color: "#9b59b6", closed: false });
  await test("Draw Polygon", "draw_polygon", { points: [{ x: 35, y: 50 }, { x: 45, y: 50 }, { x: 40, y: 60 }], color: "#1abc9c", filled: true });
  await test("Flood Fill", "fill_area", { x: 16, y: 16, color: "#2ecc71" });
  await test("Batch Draw Pixels", "draw_pixels", {
    pixels: [
      { x: 1, y: 1, color: "#e74c3c" },
      { x: 2, y: 1, color: "#e74c3c" },
      { x: 1, y: 2, color: "#e74c3c" },
      { x: 2, y: 2, color: "#e74c3c" },
    ],
  });

  // 4. Color manipulation & Procedural
  await test("Color Replace (#e74c3c -> #e67e22)", "color_replace", { old_color: "#e74c3c", new_color: "#e67e22", tolerance: 0.1 });
  await test("Adjust HSV (Hue shift +30)", "adjust_hsv", { hue_shift: 30, saturation: 1.1, value: 1.0 });
  await test("Apply Outline", "apply_outline", { color: "#000000", thickness: 1, inside: false });
  await test("Mirror Layer", "mirror_layer", { axis: "horizontal", mode: "mirror_left_to_right" });

  // 5. Selections & Inspection
  await test("Select Rect", "select_rect", { x: 0, y: 0, width: 32, height: 32, operation: 0 });
  await test("Select All", "select_all", {});
  await test("Deselect", "deselect", {});
  await test("Get Canvas Snapshot", "get_canvas_snapshot", { x: 0, y: 0, width: 16, height: 16 }, (r) => r.success && r.data?.grid);
  await test("Get Canvas Image (Base64)", "get_canvas_image_base64", {}, (r) => r.success && typeof r.data?.base64 === "string");

  // 6. Layers
  await test("Add Pixel Layer", "add_layer", { name: "OverlayLayer", type: 0 });
  await test("Get Layers", "get_layers", {}, (r) => r.success && r.data?.layers?.length >= 2);
  await test("Set Layer Opacity", "set_layer_opacity", { index: 1, opacity: 0.8 });
  await test("Set Layer Blend Mode", "set_layer_blend_mode", { index: 1, blend_mode: 0 });
  await test("Set Layer Visibility", "set_layer_visibility", { index: 1, visible: true });
  await test("Delete Layer", "delete_layer", { index: 1 });

  // 7. Animation Frames & Navigation
  await test("Add Frame", "add_frame", {});
  await test("Set FPS", "set_fps", { fps: 12 });
  await test("Get FPS", "get_fps", {}, (r) => r.success && r.data?.fps === 12);
  await test("Set Frame Duration", "set_frame_duration", { index: 0, duration: 2.0 });
  await test("Duplicate Frame", "duplicate_frame", { index: 0 });
  await test("Get Frames", "get_frames", {}, (r) => r.success && r.data?.frames?.length >= 3);
  await test("Switch Frame", "switch_frame", { index: 1 });
  await test("Switch Cel", "switch_cel", { frame: 1, layer: 0 });
  await test("Copy Cel (0,0 -> 1,0)", "copy_cel", { src_frame: 0, src_layer: 0, dst_frame: 1, dst_layer: 0 });
  await test("Clear Cel", "clear_cel", { frame: 1, layer: 0 });
  await test("Delete Frame", "delete_frame", { index: 2 });

  // 8. Transformations (Auto-Crop & Scaling)
  await test("Crop to Content", "crop_to_content", {}, (r) => r.success && r.data?.new_size);
  await test("Scale Canvas (2x)", "scale_canvas", { factor: 2 }, (r) => r.success && r.data?.new_size);

  // 9. Exports
  const pathModule = await import("path");
  const exportDir = pathModule.resolve("./docs/examples/");
  await test("Export Image (PNG)", "export_image", { path: pathModule.join(exportDir, "test_full_export.png"), frame: 0 });
  await test("Export Animation (Spritesheet)", "export_animation", {
    path: exportDir,
    prefix: "test_full_anim",
    mode: "spritesheet",
    columns: 2,
  });

  console.log("\n==================================================");
  console.log(`📊 Summary: ${passed} Passed, ${failed} Failed out of ${passed + failed} Tests`);
  console.log("==================================================");
}

run();
