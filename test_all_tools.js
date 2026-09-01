/**
 * test_all_tools.js — Comprehensive verification suite for ALL 67 MCP Tools in Pixelorama-MCP.
 */

import { createServer } from "./mcp-server/dist/server.js";
import path from "path";
import fs from "fs";

async function run() {
  console.log("==================================================");
  console.log("🧪 Comprehensive Verification of ALL 67 Pixelorama-MCP Tools");
  console.log("==================================================\n");

  const server = createServer();
  const registered = server._registeredTools || {};
  const allToolNames = Object.keys(registered);

  console.log(`Registered Tools in MCP Server (${allToolNames.length} total):\n`);

  let passed = 0;
  let failed = 0;
  const testedTools = new Set();
  const exportDir = path.resolve("./docs/examples/");
  if (!fs.existsSync(exportDir)) {
    fs.mkdirSync(exportDir, { recursive: true });
  }

  async function test(toolName, params = {}, validate = (r) => r && !r.isError && Array.isArray(r.content)) {
    testedTools.add(toolName);
    const tool = registered[toolName];
    if (!tool) {
      console.log(`❌ Tool [${toolName}] NOT FOUND in server registry!`);
      failed++;
      return;
    }

    process.stdout.write(`Testing [${toolName}]... `);
    try {
      const res = await tool.handler(params);
      const outputText = res?.content?.map((c) => c.text || "").join(" ") || "";
      const isErr = res?.isError || outputText.startsWith("❌");
      if (!isErr && validate(res)) {
        console.log(`✅ Passed`);
        passed++;
      } else {
        console.log(`❌ Failed: ${outputText || JSON.stringify(res)}`);
        failed++;
      }
    } catch (err) {
      console.log(`❌ Exception: ${err.message}`);
      failed++;
    }
  }

  // 1. Canvas & Viewport Tools (including multi-canvas tab navigation)
  await test("create_canvas", { width: 64, height: 64, name: "Canvas_A" });
  await test("create_canvas", { width: 32, height: 32, name: "Canvas_B" });
  await test("list_canvases", {});
  await test("switch_canvas", { index: 0 });
  await test("get_canvas_info", {});
  await test("close_canvas", { index: 1 });
  await test("fit_viewport", {});

  // 2. Color & Palette Tools
  await test("set_color", { color: "#ff5500", button: 0 });
  await test("get_color", {});
  await test("create_palette", { name: "FullTestPal", width: 4, height: 4, is_global: true });
  await test("add_palette_color", { color: "#00ff88" });
  await test("set_palette_color", { index: 0, color: "#ff0088" });
  await test("get_palette_colors", {});

  // 3. Drawing Primitives & Batching
  await test("draw_pixel", { x: 10, y: 10, color: "#ffffff" });
  await test("draw_line", { x1: 5, y1: 5, x2: 25, y2: 5, color: "#ffffff" });
  await test("draw_rect", { x: 15, y: 15, width: 20, height: 20, color: "#e74c3c", filled: true });
  await test("draw_ellipse", { cx: 32, cy: 45, rx: 10, ry: 8, color: "#3498db", filled: true });
  await test("draw_path", { points: [{ x: 5, y: 50 }, { x: 15, y: 55 }, { x: 25, y: 50 }], color: "#9b59b6", closed: false });
  await test("draw_polygon", { points: [{ x: 35, y: 50 }, { x: 45, y: 50 }, { x: 40, y: 60 }], color: "#1abc9c", filled: true });
  await test("fill_area", { x: 16, y: 16, color: "#2ecc71" });
  await test("draw_pixels", {
    pixels: [
      { x: 1, y: 1, color: "#e74c3c" },
      { x: 2, y: 1, color: "#e74c3c" },
      { x: 1, y: 2, color: "#e74c3c" },
      { x: 2, y: 2, color: "#e74c3c" },
    ],
  });

  // 4. Selections & Inspection
  await test("select_rect", { x: 0, y: 0, width: 32, height: 32, operation: 0 });
  await test("select_all", {});
  await test("deselect", {});
  await test("get_pixel", { x: 10, y: 10 });
  await test("get_pixels", { coords: [{ x: 10, y: 10 }, { x: 0, y: 0 }] });
  await test("get_region", { x: 0, y: 0, width: 8, height: 8 });
  await test("get_canvas_snapshot", { x: 0, y: 0, width: 16, height: 16 });

  // 5. Vision & AI Helpers
  await test("capture_canvas_image", {});
  await test("describe_canvas", {});
  await test("suggest_palette", { theme: "retro", list_all: false });
  await test("generate_sprite", { description: "red potion bottle", width: 16, height: 16, style: "pico8" });

  // 6. Color manipulation & Procedural Art
  await test("color_replace", { old_color: "#e74c3c", new_color: "#e67e22", tolerance: 0.1 });
  await test("adjust_hsv", { hue_shift: 30, saturation: 1.1, value: 1.0 });
  await test("generate_color_ramp", { base_color: "#e74c3c" });
  await test("apply_dithering", { x: 0, y: 0, width: 8, height: 8, color1: "#e74c3c", color2: "#3498db" });
  await test("apply_outline", { color: "#000000", thickness: 1, inside: false });
  await test("mirror_layer", { axis: "horizontal", mode: "mirror_left_to_right" });

  // 7. Undo / Redo
  await test("undo", {});
  await test("redo", {});

  // 8. Cel Transformations
  await test("transform_cel", { dx: 2, dy: 2 });
  await test("rotate_cel", { angle: 90 });

  // 9. Layers & Stack Management
  await test("add_layer", { name: "OverlayFX", type: 0 });
  await test("set_layer_name", { index: 1, name: "RenamedOverlay" });
  await test("reorder_layers", { from_index: 0, to_index: 1 });
  await test("get_layers", {});
  await test("set_layer_opacity", { index: 1, opacity: 0.8 });
  await test("set_layer_blend_mode", { index: 1, blend_mode: 0 });
  await test("set_layer_visibility", { index: 1, visible: true });
  await test("delete_layer", { index: 1 });

  // 10. Animation Frames & Navigation
  await test("add_frame", {});
  await test("set_fps", { fps: 12 });
  await test("get_fps", {});
  await test("set_frame_duration", { index: 0, duration: 2.0 });
  await test("duplicate_frame", { index: 0 });
  await test("get_frames", {});
  await test("switch_frame", { index: 1 });
  await test("switch_cel", { frame: 1, layer: 0 });
  await test("copy_cel", { src_frame: 0, src_layer: 0, dst_frame: 1, dst_layer: 0 });
  await test("clear_cel", { frame: 1, layer: 0 });
  await test("delete_frame", { index: 2 });

  // 11. Canvas Scaling & Content Auto-Crop
  await test("crop_to_content", {});
  await test("scale_canvas", { factor: 2 });

  // 12. Tilemaps & Tilesets
  await test("create_tileset_canvas", { tile_size: 16, columns: 4, rows: 4, name: "TilesetGrid" });
  await test("export_tileset", {
    export_path: path.join(exportDir, "test_tileset_export.png"),
    tile_size: 16,
    generate_metadata: true,
  });

  // 13. File Imports, Project Saves & Exports
  const imgPath = path.join(exportDir, "test_full_export.png");
  await test("export_image", { path: imgPath, frame: 0 });
  await test("save_project", { path: path.join(exportDir, "test_project.pxo") });
  await test("import_image", { file_path: imgPath, target_width: 32, target_height: 32, remove_background: true });
  await test("export_animation", {
    path: exportDir,
    prefix: "test_full_anim",
    mode: "spritesheet",
    columns: 2,
  });

  // 14. Direct Godot 4 Resource Exporters
  await test("export_godot_spriteframes", {
    target_dir: exportDir,
    sprite_name: "test_hero",
    animation_name: "idle",
    fps: 10,
    loop: true,
  });
  await test("export_godot_tileset", {
    target_dir: exportDir,
    tileset_name: "test_dungeon",
    tile_size: 16,
  });

  // Check for any untested tools
  const missing = allToolNames.filter((t) => !testedTools.has(t));
  if (missing.length > 0) {
    console.log(`\n⚠️ Untested Tools (${missing.length}):`, missing);
  } else {
    console.log(`\n✨ Perfect: Every single one of all ${allToolNames.length} registered tools was tested!`);
  }

  console.log("\n==================================================");
  console.log(`📊 Final Summary: ${passed} Passed, ${failed} Failed out of ${allToolNames.length} MCP Tools`);
  console.log("==================================================");
}

run();
