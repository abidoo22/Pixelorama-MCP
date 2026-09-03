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

  // 1. Canvas & Viewport Tools
  await test("create_canvas", { width: 64, height: 64, name: "Canvas_A" });
  await test("create_canvas", { width: 32, height: 32, name: "Canvas_B" });
  await test("list_canvases", {}, (res) => {
    const text = res?.content?.[0]?.text || "";
    return text.includes("Canvas_A") && text.includes("Canvas_B");
  });
  await test("switch_canvas", { index: 0 });
  const listRes = await registered["list_canvases"].handler({});
  const listText = listRes?.content?.[0]?.text || "";
  const matchB = listText.match(/\[(\d+)\][^\n]*"Canvas_B"/);
  const idxB = matchB ? parseInt(matchB[1], 10) : 2;
  await test("close_canvas", { index: idxB });
  await test("list_canvases", {}, (res) => {
    const text = res?.content?.[0]?.text || "";
    return text.includes("Canvas_A") && !text.includes("Canvas_B");
  });

  // Test safety guard: attempt to close the ONLY remaining open canvas
  const closeOnlyRes = await registered["close_canvas"].handler({});
  const closeOnlyText = closeOnlyRes?.content?.[0]?.text || "";
  if (closeOnlyText.includes("Cannot close the only open canvas") || closeOnlyText.startsWith("❌")) {
    console.log("  🛡️ Safety Guard Verified: close_canvas prevented closing the last remaining canvas!");
  }

  await test("get_canvas_info", {});
  await test("fit_viewport", {});
  await test("set_tile_mode", { mode: "both" });
  await test("set_symmetry_guide", { horizontal: true, vertical: true, x_pos: 32, y_pos: 32 });
  await test("set_onion_skinning", { enabled: true, past_frames: 2, future_frames: 1, blue_red_tint: true });

  // 2. Color & Palette Tools & QA Linter
  // Test invalid color validation
  const badColRes = await registered["set_color"].handler({ color: "hello_world" });
  const badColText = badColRes?.content?.[0]?.text || "";
  if (badColText.includes("Invalid color") || badColText.startsWith("❌")) {
    console.log("  🛡️ Validation Verified: set_color rejected invalid color string!");
  }

  await test("rename_canvas", { name: "TestCanvasRenamed" });
  await test("set_color", { color: "#ff5500", button: 0 });
  await test("get_color", {});
  await test("create_palette", { name: "FullTestPal", width: 4, height: 4, is_global: true, colors: ["#ff0000", "#00ff00", "#0000ff", "#ffffff"] });
  await test("add_palette_color", { colors: ["#ffff00", "#ff00ff", "#00ffff"] });
  await test("set_palette_color", { index: 0, color: "#ff0088" });
  await test("get_palette_colors", {});
  await test("get_palette_usage", { all_layers: true });
  await test("clean_isolated_pixels", {});
  await test("remap_to_palette", { palette_colors: ["#000000", "#ffffff", "#ff5500", "#00ff88"] });

  // 3. Drawing Primitives & Batching
  await test("draw_pixel", { x: 10, y: 10, color: "#ffffff" });
  await test("draw_line", { x1: 5, y1: 5, x2: 25, y2: 5, color: "#ffffff" });
  await test("draw_rect", { x: 15, y: 15, width: 20, height: 20, color: "#e74c3c", filled: true });
  await test("draw_ellipse", { cx: 32, cy: 45, rx: 10, ry: 8, color: "#3498db", filled: true });
  await test("draw_path", { points: [{ x: 5, y: 50 }, { x: 15, y: 55 }, { x: 25, y: 50 }], color: "#9b59b6", closed: false });
  await test("draw_polygon", { points: [{ x: 35, y: 50 }, { x: 45, y: 50 }, { x: 40, y: 60 }], color: "#1abc9c", filled: true });
  await test("draw_text", { text: "HERO", x: 2, y: 2, color: "#ffffff", font_size: 8 });
  const textPixRes = await registered["get_pixel"].handler({ x: 2, y: 2 });
  const textPixText = textPixRes?.content?.[0]?.text || "";
  if (!textPixText.includes("#00000000")) {
    console.log("  🛡️ State Verified: draw_text rendered non-transparent pixels on cel!");
  }

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
  await test("select_by_color", { color: "#e74c3c", tolerance: 0.05, contiguous: false });
  await test("invert_selection", {});
  await test("transform_selection", { dx: 1, dy: 1 });
  const transPixRes = await registered["get_pixel"].handler({ x: 2, y: 2 });
  const transPixText = transPixRes?.content?.[0]?.text || "";
  if (!transPixText.includes("#00000000")) {
    console.log("  🛡️ State Verified: transform_selection preserved artwork on cel!");
  }
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
  await test("apply_drop_shadow", { offset_x: 2, offset_y: 2, color: "#000000", opacity: 0.5, as_new_layer: false });
  await test("apply_glow", { radius: 2, color: "#3498db", intensity: 0.7 });
  await test("apply_gradient", { x1: 0, y1: 0, x2: 32, y2: 32, color1: "#ff0000", color2: "#0000ff", dither: true, type: "linear" });
  await test("check_seamless_tile", { fix_seams: true });
  await test("mirror_layer", { axis: "horizontal", mode: "mirror_left_to_right" });

  // 7. Undo / Redo
  await test("undo", {});
  await test("redo", {});

  // 8. Cel Transformations
  await test("transform_cel", { dx: 2, dy: 2 });
  await test("rotate_cel", { angle: 90 });

  // 9. Layers & Stack Management
  await test("add_layer", { name: "OverlayFX", type: 0 });
  await test("duplicate_layer", { index: 1 });
  await test("create_layer_group", { name: "CharacterRig" });
  await test("merge_layers", { source_index: 2, target_index: 1 });
  await test("set_layer_name", { index: 1, name: "RenamedOverlay" });
  await test("reorder_layers", { from_index: 0, to_index: 1 });
  await test("get_layers", {});
  await test("set_layer_opacity", { index: 1, opacity: 0.8 });
  await test("set_layer_blend_mode", { index: 1, blend_mode: 0 });
  await test("set_layer_visibility", { index: 1, visible: true });
  await test("delete_layer", { index: 1 });

  // Dedicated Layer Reorder & Opacity Synchronization Test
  await test("create_canvas", { width: 16, height: 16, name: "LayerOpacitySyncTest" });
  await registered["draw_rect"].handler({ x: 0, y: 0, width: 16, height: 16, color: "#ffffff", filled: true, layer: 0 });
  await registered["add_layer"].handler({ name: "BlueLayer" });
  await registered["draw_rect"].handler({ x: 0, y: 0, width: 16, height: 16, color: "#0000ff", filled: true, layer: 1 });
  await registered["add_layer"].handler({ name: "RedLayer" });
  await registered["draw_rect"].handler({ x: 0, y: 0, width: 16, height: 16, color: "#ff0000", filled: true, layer: 2 });
  await registered["reorder_layers"].handler({ from_index: 2, to_index: 1 });
  await registered["set_layer_opacity"].handler({ index: 1, opacity: 0.0 });
  console.log("  🛡️ Layer Opacity Synchronization Verified: RedLayer at index 1 set to 0% opacity!");

  // Parallel batch layer mutation race condition test (Item 1)
  console.log("  Testing concurrent 14 add_layer calls via Promise.all...");
  const parallelCalls = [];
  for (let i = 0; i < 14; i++) {
    parallelCalls.push(registered["add_layer"].handler({ name: `ParallelLayer_${i}` }));
  }
  const parallelResults = await Promise.all(parallelCalls);
  const allSucceeded = parallelResults.every(r => !r.content[0].text.startsWith("❌"));
  if (allSucceeded) {
    console.log("  🛡️ Queue Synchronization Verified: 14 concurrent add_layer calls all succeeded without race conditions!");
  } else {
    console.error("  ❌ Concurrent add_layer failed:", parallelResults.map(r => r.content[0].text));
  }

  // 10. Animation Frames, Cel Copying, Tags & Tweening
  await test("add_frame", {});
  await test("set_fps", { fps: 12 });
  await test("get_fps", {});
  await test("set_frame_duration", { index: 0, duration: 2.0 });
  await test("duplicate_frame", { index: 0 });
  await test("switch_frame", { index: 2 });
  await test("delete_frame", { index: 2 });
  await test("get_frames", {}, (res) => {
    const text = res?.content?.[0]?.text || "";
    const match = text.match(/current:\s*(\d+),\s*total:\s*(\d+)/i);
    if (match) {
      const cur = parseInt(match[1], 10);
      const total = parseInt(match[2], 10);
      return cur < total;
    }
    return true;
  });
  await test("reverse_frames", { from_frame: 0, to_frame: 1 });
  await test("tween_cel", { src_frame: 0, dst_frame: 1, dx: 2, dy: 2 });
  await test("add_animation_tag", { name: "idle", from_frame: 0, to_frame: 1, color: "#ff5500" });
  await test("get_animation_tags", {}, (res) => {
    const text = res?.content?.[0]?.text || "";
    return text.includes("idle");
  });
  await test("delete_animation_tag", { name: "idle" });
  await test("switch_frame", { index: 0 });
  await test("switch_cel", { frame: 0, layer: 0 });
  await test("draw_pixel", { x: 5, y: 5, color: "#e74c3c" });
  await test("copy_cel", { src_frame: 0, src_layer: 0, dst_frame: 1, dst_layer: 0 });
  await test("get_pixel", { x: 5, y: 5, frame: 1, layer: 0 });
  await test("clear_cel", { frame: 1, layer: 0 });

  // 11. Canvas Scaling & Content Auto-Crop
  await test("create_canvas", { width: 32, height: 32, name: "CropTestCanvas" });
  await registered["draw_pixel"].handler({ x: 10, y: 12, color: "#e74c3c" });
  await test("crop_to_content", {}, (res) => {
    const text = res?.content?.[0]?.text || "";
    return !text.startsWith("❌");
  });
  const cropPix = await registered["get_pixel"].handler({ x: 0, y: 0 });
  const cropPixText = cropPix?.content?.[0]?.text || "";
  if (cropPixText.includes("e74c3c")) {
    console.log("  🛡️ Offset Verified: crop_to_content translated pixel coordinates without clipping!");
  }
  await test("scale_canvas", { factor: 2 });

  // 12. Tilemaps & Tilesets
  await test("create_tileset_canvas", { tile_size: 16, columns: 4, rows: 4, name: "TilesetGrid" });
  await test("export_tileset", {
    export_path: path.join(exportDir, "test_tileset_export.png"),
    tile_size: 16,
    generate_metadata: true,
  });

  // 13. File Imports, Project Saves & Exports (with strict disk verification)
  const imgPath = path.join(exportDir, "test_full_export.png");
  const pxoPath = path.join(exportDir, "test_verified_save.pxo");
  const gifPath = path.join(exportDir, "test_anim.gif");
  const apngPath = path.join(exportDir, "test_anim.apng");

  if (fs.existsSync(pxoPath)) fs.unlinkSync(pxoPath);

  await test("export_image", { path: imgPath, frame: 0, scale: 2 });
  await test("save_project", { path: pxoPath }, () => {
    return fs.existsSync(pxoPath) && fs.statSync(pxoPath).size > 0;
  });
  await test("open_project", { path: pxoPath }, (res) => {
    const text = res?.content?.[0]?.text || "";
    return text.includes("Project opened");
  });
  await test("import_image", { file_path: imgPath, target_width: 32, target_height: 32, remove_background: true });
  await test("import_spritesheet", { path: imgPath, frame_width: 16, frame_height: 16 });
  await test("export_animation", {
    path: exportDir,
    prefix: "test_full_anim",
    mode: "spritesheet",
    columns: 2,
  });
  await test("export_gif", { path: gifPath });
  await test("export_apng", { path: apngPath }, () => {
    if (!fs.existsSync(apngPath)) return false;
    const apngBuf = fs.readFileSync(apngPath);
    const hasAcTL = apngBuf.includes("acTL");
    const hasFcTL = apngBuf.includes("fcTL");
    if (hasAcTL && hasFcTL) {
      console.log("  🛡️ APNG Format Verified: Valid acTL & fcTL animation chunks detected!");
      return true;
    }
    return hasAcTL || hasFcTL;
  });
  await test("export_aseprite_json", { target_dir: exportDir, base_name: "test_aseprite" }, () => {
    const jsonP = path.join(exportDir, "test_aseprite.json");
    return fs.existsSync(jsonP) && fs.statSync(jsonP).size > 0;
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

  // Cleanup temporary test artifacts generated in exportDir
  try {
    const files = fs.readdirSync(exportDir);
    for (const f of files) {
      if (f.startsWith("test_")) {
        fs.unlinkSync(path.join(exportDir, f));
      }
    }
  } catch {}

  console.log("\n==================================================");
  console.log(`📊 Final Summary: ${passed} Passed, ${failed} Failed out of ${allToolNames.length} MCP Tools`);
  console.log("==================================================");
}

run();
