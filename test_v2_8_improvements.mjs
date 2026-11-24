// Comprehensive automated verification suite for pix-MCP v2.8 improvements
import assert from "node:assert";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { createServer } from "./mcp-server/dist/server.js";

const BRIDGE_URL = "http://127.0.0.1:7373";

async function sendCmd(tool, params = {}) {
  const res = await fetch(`${BRIDGE_URL}/command`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool, params }),
  });
  return await res.json();
}

function readPngDimensions(filePath) {
  const buf = fs.readFileSync(filePath);
  assert.strictEqual(buf.subarray(0, 8).toString("hex"), "89504e470d0a1a0a", `Invalid PNG signature: ${filePath}`);
  assert.strictEqual(buf.subarray(12, 16).toString("ascii"), "IHDR", `Missing IHDR chunk: ${filePath}`);
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20),
    buf,
  };
}

function readApngFrameCount(buf) {
  let offset = 8;
  while (offset + 8 <= buf.length) {
    const length = buf.readUInt32BE(offset);
    const type = buf.subarray(offset + 4, offset + 8).toString("ascii");
    if (type === "acTL") {
      return buf.readUInt32BE(offset + 8);
    }
    offset += 12 + length;
  }
  return 0;
}

function readGifHeader(filePath) {
  const buf = fs.readFileSync(filePath);
  const sig = buf.subarray(0, 6).toString("ascii");
  assert(sig === "GIF89a" || sig === "GIF87a", `Invalid GIF signature: ${sig}`);
  return {
    signature: sig,
    width: buf.readUInt16LE(6),
    height: buf.readUInt16LE(8),
  };
}

async function run() {
  console.log("=== Running pix-MCP v2.8 Improvements Verification Suite ===\n");
  const server = createServer();
  const mcpTools = server._registeredTools;
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "pix-mcp-v28-"));

  try {
    // ------------------------------------------------------------------
    // 1. draw_text: full ASCII 32–126 + lowercase + symbols + shadow/outline + cell_width
    // ------------------------------------------------------------------
    console.log("[1/7] Testing draw_text (ASCII 32–126, lowercase, symbols, shadow/outline, cell_width)...");
    await sendCmd("create_canvas", { width: 512, height: 64, name: "Text_ASCII_Test" });
    let allAscii = "";
    for (let code = 32; code <= 126; code++) {
      allAscii += String.fromCharCode(code);
    }
    const asciiRes = await sendCmd("draw_text", { text: allAscii, x: 2, y: 4, scale: 1, color: "#ffffff" });
    assert(asciiRes.success, `draw_text full ASCII failed: ${asciiRes.error}`);
    assert.strictEqual(asciiRes.data.chars_drawn, 95, "Expected all 95 printable ASCII chars");
    assert.strictEqual(asciiRes.data.unsupported_chars, 0, "Expected 0 unsupported chars for ASCII 32..126");

    // Verify lowercase 'a' differs from uppercase 'A'
    await sendCmd("create_canvas", { width: 32, height: 16, name: "CaseDiffTest" });
    await sendCmd("draw_text", { text: "A", x: 0, y: 0, scale: 1, color: "#ffffff" });
    const regUpperA = await sendCmd("get_region", { x: 0, y: 0, width: 5, height: 6 });
    await sendCmd("clear_cel", {});
    await sendCmd("draw_text", { text: "a", x: 0, y: 0, scale: 1, color: "#ffffff" });
    const regLowerA = await sendCmd("get_region", { x: 0, y: 0, width: 5, height: 6 });
    assert.notDeepStrictEqual(regUpperA.data.grid, regLowerA.data.grid, "Lowercase 'a' must NOT fold to uppercase 'A'");

    // Verify symbols do NOT render the 3x5 hollow box fallback
    const fallbackBox = [
      ["#ffffffff", "#ffffffff", "#ffffffff"],
      ["#ffffffff", "#00000000", "#ffffffff"],
      ["#ffffffff", "#00000000", "#ffffffff"],
      ["#ffffffff", "#00000000", "#ffffffff"],
      ["#ffffffff", "#ffffffff", "#ffffffff"],
    ];
    for (const sym of ["/", "[", "]", "{", "}", "(", ")", "@", "#", "%", "&", "*", "=", "_", "~"]) {
      await sendCmd("clear_cel", {});
      const sr = await sendCmd("draw_text", { text: sym, x: 0, y: 0, scale: 1, color: "#ffffff" });
      assert(sr.success && sr.data.unsupported_chars === 0, `Symbol '${sym}' must be supported`);
      const reg = await sendCmd("get_region", { x: 0, y: 0, width: 3, height: 5 });
      assert.notDeepStrictEqual(reg.data.grid, fallbackBox, `Symbol '${sym}' must not render as fallback box`);
    }

    // Verify shadow_color + outline_color + cell_width
    await sendCmd("create_canvas", { width: 48, height: 24, name: "TextFXTest" });
    const fxRes = await sendCmd("draw_text", {
      text: "I",
      x: 10,
      y: 6,
      scale: 1,
      color: "#ffffff",
      outline_color: "#00ff00",
      outline_mode: "cardinal",
      shadow_color: "#220044",
      shadow_offset_x: 2,
      shadow_offset_y: 2,
      cell_width: 8,
    });
    assert(fxRes.success, `draw_text FX failed: ${fxRes.error}`);
    assert.strictEqual(fxRes.data.bounding_box.advance, 8, "cell_width=8 must produce advance=8");
    // 'I' has ink at (10,6), (11,6), (12,6)
    const inkPx = await sendCmd("get_pixel", { x: 11, y: 6 });
    assert.strictEqual(inkPx.data.color, "#ffffffff", "Main ink must sit on top");
    const outlinePx = await sendCmd("get_pixel", { x: 11, y: 5 });
    assert.strictEqual(outlinePx.data.color, "#00ff00ff", "Cardinal outline pixel above 'I'");
    // Bottom-right of 'I' outline at (12, 11) shifted by (+2,+2) -> (14, 13) should have shadow
    const shadowPx = await sendCmd("get_pixel", { x: 14, y: 12 });
    assert.strictEqual(shadowPx.data.color, "#220044ff", "Drop shadow pixel behind outline/ink");
    console.log("  ✅ draw_text ASCII 32–126, lowercase, symbols, shadow, outline, and cell_width verified");

    // ------------------------------------------------------------------
    // 2. export_animation, export_gif, export_apng (tag, start/end, exact_path, exact_filename, scale)
    // ------------------------------------------------------------------
    console.log("[2/7] Testing export_animation, export_gif, and export_apng (tag, range, exact_path, scale)...");
    await sendCmd("create_canvas", { width: 16, height: 16, name: "ExportTagTest" });
    const addRes = await sendCmd("add_frame", { count: 5 });
    assert(addRes.success && addRes.data.total_frames === 6, `Expected 6 frames, got ${addRes.data?.total_frames}`);
    const frameColors = ["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff"];
    for (let f = 0; f < 6; f++) {
      await sendCmd("draw_rect", { x: 2, y: 2, width: 12, height: 12, color: frameColors[f], frame: f });
    }
    await sendCmd("add_animation_tag", { name: "idle", from_frame: 0, to_frame: 1, color: "#00ff00" });
    await sendCmd("add_animation_tag", { name: "walk", from_frame: 2, to_frame: 5, color: "#ff8800" });

    // Spritesheet by tag + exact_path + 2x scale (via MCP handler to exercise path_guard too)
    const exactWalkPath = path.join(tmpDir, "en_shambler_walk.png");
    const expWalkMcp = await mcpTools["export_animation"].handler({
      mode: "spritesheet",
      tag: "walk",
      exact_path: exactWalkPath,
      scale: 2,
    });
    assert(!expWalkMcp.content[0].text.startsWith("❌"), `export_animation exact_path failed: ${expWalkMcp.content[0].text}`);
    assert(fs.existsSync(exactWalkPath), "exact_path PNG must exist without _spritesheet suffix");
    const walkDim = readPngDimensions(exactWalkPath);
    assert.strictEqual(walkDim.width, 4 * 16 * 2, `Expected 128px width, got ${walkDim.width}`);
    assert.strictEqual(walkDim.height, 16 * 2, `Expected 32px height, got ${walkDim.height}`);

    // Spritesheet by start_frame/end_frame + exact_filename + columns=2
    const expSliceMcp = await mcpTools["export_animation"].handler({
      path: tmpDir,
      mode: "spritesheet",
      start_frame: 1,
      end_frame: 3,
      columns: 2,
      exact_filename: "custom_slice.png",
      scale: 1,
    });
    assert(!expSliceMcp.content[0].text.startsWith("❌"), `export_animation slice failed: ${expSliceMcp.content[0].text}`);
    const slicePath = path.join(tmpDir, "custom_slice.png");
    assert(fs.existsSync(slicePath), "exact_filename PNG must exist");
    const sliceDim = readPngDimensions(slicePath);
    assert.strictEqual(sliceDim.width, 32, `Expected 32px width (2 cols), got ${sliceDim.width}`);
    assert.strictEqual(sliceDim.height, 32, `Expected 32px height (2 rows), got ${sliceDim.height}`);

    // export_gif with tag="walk" & scale=4
    const gif4xPath = path.join(tmpDir, "walk_4x.gif");
    const gifRes = await sendCmd("export_gif", { path: gif4xPath, tag: "walk", scale: 4 });
    assert(gifRes.success, `export_gif failed: ${gifRes.error}`);
    assert.strictEqual(gifRes.data.frames, 4, "GIF should contain only the 4 frames of tag 'walk'");
    assert.strictEqual(gifRes.data.scale, 4);
    const gifHdr = readGifHeader(gif4xPath);
    assert.strictEqual(gifHdr.width, 64, `Expected 64px 4x GIF width, got ${gifHdr.width}`);
    assert.strictEqual(gifHdr.height, 64, `Expected 64px 4x GIF height, got ${gifHdr.height}`);

    // export_apng with tag="walk" & scale=2
    const apng2xPath = path.join(tmpDir, "walk_2x.apng");
    const apngRes = await sendCmd("export_apng", { path: apng2xPath, tag: "walk", scale: 2 });
    assert(apngRes.success, `export_apng failed: ${apngRes.error}`);
    assert.strictEqual(apngRes.data.frames, 4);
    const apngDim = readPngDimensions(apng2xPath);
    assert.strictEqual(apngDim.width, 32);
    assert.strictEqual(apngDim.height, 32);
    assert.strictEqual(readApngFrameCount(apngDim.buf), 4, "APNG acTL frame count must equal 4");
    console.log("  ✅ export_animation, export_gif (4x + tag), and export_apng (2x + tag) verified");

    // ------------------------------------------------------------------
    // 3. Batch / range timeline ops + batch_commands
    // ------------------------------------------------------------------
    console.log("[3/7] Testing add_frame(count), duplicate_frame(count), multi-frame cel ops & batch_commands...");
    await sendCmd("create_canvas", { width: 24, height: 24, name: "BatchTimelineTest" });
    await sendCmd("set_layer_name", { index: 0, name: "Hero" });
    const bulkAdd = await sendCmd("add_frame", { count: 10 });
    assert(bulkAdd.success && bulkAdd.data.total_frames === 11, "add_frame(count=10) should yield 11 frames");
    await sendCmd("undo", {});
    const afterUndo = await sendCmd("get_frames", {});
    assert.strictEqual(afterUndo.data.total_frames, 1, "Single undo must revert all 10 added frames atomically");

    await sendCmd("draw_rect", { x: 6, y: 6, width: 6, height: 6, color: "#e74c3c", layer: "Hero", frame: 0 });
    const dupRes = await sendCmd("duplicate_frame", { index: 0, count: 2 });
    assert(dupRes.success && dupRes.data.total_frames === 3, "duplicate_frame(count=2) should yield 3 frames");
    await sendCmd("add_frame", { after_frame: 2, count: 3 }); // total 6 frames (0..5)
    await sendCmd("add_animation_tag", { name: "run", from_frame: 3, to_frame: 5 });

    // copy_cel into tag "run" using string layer name
    const cpRes = await sendCmd("copy_cel", { src_frame: 0, src_layer: "Hero", dst_tag: "run" });
    assert(cpRes.success && cpRes.data.cels_copied === 3, `copy_cel dst_tag failed: ${JSON.stringify(cpRes)}`);

    // transform_cel across range 3..5
    const trRes = await sendCmd("transform_cel", { dx: 3, dy: 2, from_frame: 3, to_frame: 5, layer: "Hero" });
    assert(trRes.success && trRes.data.frames_processed === 3, "transform_cel should process 3 frames");
    const shiftedPx = await sendCmd("get_pixel", { x: 9, y: 8, frame: 5, layer: "Hero" });
    assert.strictEqual(shiftedPx.data.color, "#e74c3cff", "Frame 5 pixel should be shifted by (+3,+2)");

    // apply_outline across tag "run" using string layer name
    const olRes = await sendCmd("apply_outline", { color: "#111111", thickness: 1, tag: "run", layer: "Hero" });
    assert(olRes.success && olRes.data.frames_processed === 3, "apply_outline should process 3 frames");
    const olPx = await sendCmd("get_pixel", { x: 8, y: 8, frame: 4, layer: "Hero" });
    assert.strictEqual(olPx.data.color, "#111111ff", "Frame 4 should have outline pixel at (8,8)");

    // set_frame_duration across tag "run"
    const durRes = await sendCmd("set_frame_duration", { duration: 2.5, tag: "run" });
    assert(durRes.success && durRes.data.frames_updated === 3, "set_frame_duration should update 3 frames");
    const framesInfo = await sendCmd("get_frames", {});
    assert.strictEqual(framesInfo.data.frames[4].duration, 2.5);

    // clear_cel across frames [3, 4]
    const clrRes = await sendCmd("clear_cel", { frames: [3, 4], layer: "Hero" });
    assert(clrRes.success && clrRes.data.frames_cleared === 2);
    const clearedPx = await sendCmd("get_pixel", { x: 9, y: 8, frame: 4, layer: "Hero" });
    assert.strictEqual(clearedPx.data.color, "#00000000", "Frame 4 should be cleared");

    // batch_commands via MCP handler
    const batchExportPath = path.join(tmpDir, "batch_sheet.png");
    const batchMcp = await mcpTools["batch_commands"].handler({
      operations: [
        { tool: "create_canvas", params: { width: 16, height: 16, name: "BatchOneTrip" } },
        { tool: "set_layer_name", params: { index: 0, name: "Body" } },
        { tool: "add_frame", params: { count: 3 } },
        { tool: "draw_rect", params: { x: 4, y: 4, width: 8, height: 8, color: "#3498db", layer: "Body", frame: 0 } },
        { tool: "copy_cel", params: { src_frame: 0, src_layer: "Body", dst_from_frame: 1, dst_to_frame: 3 } },
        { tool: "export_animation", params: { mode: "spritesheet", exact_path: batchExportPath } },
      ],
      stop_on_error: true,
    });
    assert(batchMcp.content[0].text.includes("6/6 operations"), `batch_commands unexpected output: ${batchMcp.content[0].text}`);
    assert(fs.existsSync(batchExportPath), "batch_commands guarded export must succeed");
    assert.strictEqual(readPngDimensions(batchExportPath).width, 64, "Batch exported 4x16=64px spritesheet");

    // batch_commands security checks (reject eval_gdscript, nested batch, restricted path)
    const badEval = await mcpTools["batch_commands"].handler({
      operations: [{ tool: "eval_gdscript", params: { code: "return 1" } }],
      stop_on_error: true,
    });
    assert(badEval.content[0].text.startsWith("❌"), "batch_commands must reject eval_gdscript");
    const badNest = await mcpTools["batch_commands"].handler({
      operations: [{ tool: "batch_commands", params: { operations: [] } }],
      stop_on_error: true,
    });
    assert(badNest.content[0].text.startsWith("❌"), "batch_commands must reject recursive batch_commands");
    const badPath = await mcpTools["batch_commands"].handler({
      operations: [{ tool: "export_image", params: { path: "/etc/evil.png" } }],
      stop_on_error: true,
    });
    assert(badPath.content[0].text.startsWith("❌"), "batch_commands must enforce path_guard on restricted paths");
    console.log("  ✅ Multi-frame timeline ops and batch_commands (including security guards) verified");

    // ------------------------------------------------------------------
    // 4. Native selection/alpha/ellipse-aware apply_dithering & unified layer handles
    // ------------------------------------------------------------------
    console.log("[4/7] Testing selection/alpha/ellipse-aware apply_dithering & unified layer handles...");
    await sendCmd("create_canvas", { width: 32, height: 32, name: "DitherMaskTest" });
    await sendCmd("set_layer_name", { index: 0, name: "Body" });
    await sendCmd("draw_rect", { x: 4, y: 4, width: 10, height: 10, color: "#cc8844", layer: "Body" });

    // preserve_alpha=true + color1="keep" on full canvas must only dither inside (4..13, 4..13)
    const d1 = await mcpTools["apply_dithering"].handler({
      color1: "keep",
      color2: "#332211",
      pattern: "checker_50",
      preserve_alpha: true,
      within_selection: true,
      layer: "Body",
    });
    assert(!d1.content[0].text.startsWith("❌"), `apply_dithering preserve_alpha failed: ${d1.content[0].text}`);
    const outsideAlpha = await sendCmd("get_pixel", { x: 1, y: 1, layer: "Body" });
    assert.strictEqual(outsideAlpha.data.color, "#00000000", "preserve_alpha=true must leave transparent pixels untouched");
    const insideEven = await sendCmd("get_pixel", { x: 4, y: 4, layer: "Body" }); // (4+4)%2==0 -> color2
    const insideOdd = await sendCmd("get_pixel", { x: 5, y: 4, layer: "Body" });  // (5+4)%2==1 -> kept original
    assert.strictEqual(insideEven.data.color, "#332211ff", "Even pixel inside silhouette should receive color2");
    assert.strictEqual(insideOdd.data.color, "#cc8844ff", "Odd pixel inside silhouette should keep original color");

    // within_selection=true clipping
    await sendCmd("select_rect", { x: 20, y: 4, width: 6, height: 6, operation: 0 });
    const d2 = await sendCmd("apply_dithering", {
      x: 16,
      y: 0,
      width: 16,
      height: 16,
      color1: "#ff0000",
      color2: "#0000ff",
      pattern: "checker_50",
      within_selection: true,
      layer: "Body",
    });
    assert(d2.success && d2.data.within_selection === true && d2.data.pixels_drawn === 36, `Expected 36 selected pixels drawn, got ${d2.data?.pixels_drawn}`);
    assert.strictEqual((await sendCmd("get_pixel", { x: 19, y: 5, layer: "Body" })).data.color, "#00000000", "Pixel outside selection must remain untouched");
    assert.strictEqual((await sendCmd("get_pixel", { x: 20, y: 4, layer: "Body" })).data.color, "#0000ffff", "Pixel inside selection must be dithered");
    await sendCmd("deselect", {});

    // shape="ellipse" dithering
    await sendCmd("add_layer", { name: "GlowMask" });
    const d3 = await sendCmd("apply_dithering", {
      x: 5,
      y: 5,
      width: 21,
      height: 21,
      color1: "#11aa22",
      color2: "#224488",
      shape: "ellipse",
      pattern: "bayer_50",
      layer: "GlowMask",
    });
    assert(d3.success, `ellipse dithering failed: ${d3.error}`);
    assert.strictEqual((await sendCmd("get_pixel", { x: 5, y: 5, layer: "GlowMask" })).data.color, "#00000000", "Bounding corner of ellipse dither must stay transparent");
    assert.notStrictEqual((await sendCmd("get_pixel", { x: 15, y: 15, layer: "GlowMask" })).data.color, "#00000000", "Center of ellipse dither must be painted");

    // Unified string layer handles on mirror_layer, apply_drop_shadow, create_layer_group
    const mirMcp = await mcpTools["mirror_layer"].handler({ mode: "flip", axis: "horizontal", layer: "Body" });
    assert(!mirMcp.content[0].text.startsWith("❌"), `mirror_layer by name failed: ${mirMcp.content[0].text}`);
    const shdMcp = await mcpTools["apply_drop_shadow"].handler({ offset_x: 1, offset_y: 1, layer: "Body" });
    assert(!shdMcp.content[0].text.startsWith("❌"), `apply_drop_shadow by name failed: ${shdMcp.content[0].text}`);
    const grpMcp = await mcpTools["create_layer_group"].handler({ name: "RigGroup", above_layer: "Body" });
    assert(!grpMcp.content[0].text.startsWith("❌"), `create_layer_group by name failed: ${grpMcp.content[0].text}`);
    console.log("  ✅ Native apply_dithering (preserve_alpha, within_selection, ellipse, keep) & unified layer handles verified");

    // ------------------------------------------------------------------
    // 5. Nub-free draw_ellipse & rounded/chamfered draw_rect
    // ------------------------------------------------------------------
    console.log("[5/7] Testing nub-free draw_ellipse & rounded/chamfered draw_rect...");
    await sendCmd("create_canvas", { width: 48, height: 48, name: "ShapesTest" });
    const elFill = await sendCmd("draw_ellipse", { cx: 24, cy: 24, rx: 10, ry: 10, color: "#ff8800", filled: true });
    assert(elFill.success);
    const regCircle = await sendCmd("get_region", { x: 14, y: 14, width: 21, height: 21 });
    const g = regCircle.data.grid;
    const countRow = (r) => g[r].filter((c) => c !== "#00000000").length;
    const countCol = (col) => g.map((row) => row[col]).filter((c) => c !== "#00000000").length;
    assert(countRow(0) >= 3, `North pole cap must be >= 3px wide (no 1px nub), got ${countRow(0)}`);
    assert(countRow(20) >= 3, `South pole cap must be >= 3px wide (no 1px nub), got ${countRow(20)}`);
    assert(countCol(0) >= 3, `West pole cap must be >= 3px tall (no 1px nub), got ${countCol(0)}`);
    assert(countCol(20) >= 3, `East pole cap must be >= 3px tall (no 1px nub), got ${countCol(20)}`);

    // Translucent outline ellipse: no nubs AND uniform alpha (no double-blending)
    await sendCmd("clear_cel", {});
    await sendCmd("draw_ellipse", { cx: 24, cy: 24, rx: 10, ry: 10, color: "#ff0000", alpha: 0.5, filled: false, blend: true });
    const regOutline = await sendCmd("get_region", { x: 14, y: 14, width: 21, height: 21 });
    const outlineAlphas = new Set();
    for (const row of regOutline.data.grid) {
      for (const hex of row) {
        if (hex !== "#00000000") outlineAlphas.add(hex);
      }
    }
    assert.strictEqual(outlineAlphas.size, 1, `Translucent ellipse outline must have uniform alpha (no double-blend), got ${[...outlineAlphas]}`);

    // Rounded & chamfered draw_rect (filled + outline)
    await sendCmd("clear_cel", {});
    const rrFill = await sendCmd("draw_rect", { x: 4, y: 4, width: 16, height: 12, color: "#00ff88", filled: true, corner_radius: 3, corner_style: "round" });
    assert(rrFill.success && rrFill.data.corner_radius === 3);
    assert.strictEqual((await sendCmd("get_pixel", { x: 4, y: 4 })).data.color, "#00000000", "Rounded rect top-left corner must be trimmed");
    assert.strictEqual((await sendCmd("get_pixel", { x: 19, y: 15 })).data.color, "#00000000", "Rounded rect bottom-right corner must be trimmed");
    assert.strictEqual((await sendCmd("get_pixel", { x: 12, y: 4 })).data.color, "#00ff88ff", "Rounded rect top edge center must be filled");

    const chOut = await sendCmd("draw_rect", { x: 24, y: 4, width: 14, height: 12, color: "#ff00ff", filled: false, corner_radius: 3, corner_style: "chamfer" });
    assert(chOut.success && chOut.data.corner_style === "chamfer");
    assert.strictEqual((await sendCmd("get_pixel", { x: 24, y: 4 })).data.color, "#00000000", "Chamfered rect corner (24,4) must be empty");
    assert.strictEqual((await sendCmd("get_pixel", { x: 27, y: 4 })).data.color, "#ff00ffff", "Chamfered rect top edge starts at x+r");
    assert.strictEqual((await sendCmd("get_pixel", { x: 26, y: 5 })).data.color, "#ff00ffff", "Chamfered rect 45° diagonal step");
    assert.strictEqual((await sendCmd("get_pixel", { x: 30, y: 10 })).data.color, "#00000000", "Chamfered rect outline interior must be empty");
    console.log("  ✅ Nub-free draw_ellipse (filled & translucent outline) and rounded/chamfered draw_rect verified");

    // ------------------------------------------------------------------
    // 6. Full-strip & palette-validating validate_sprite + get_layer_markers (hidden layer)
    // ------------------------------------------------------------------
    console.log("[6/7] Testing multi-frame palette validate_sprite & get_layer_markers on hidden layer...");
    await sendCmd("create_canvas", { width: 16, height: 16, name: "QAAndMarkersTest" });
    await sendCmd("set_layer_name", { index: 0, name: "Art" });
    await sendCmd("add_frame", { count: 3 }); // 4 frames: 0..3

    const palName = "test_haven_master_v28";
    await sendCmd("create_palette", {
      name: palName,
      width: 4,
      height: 1,
      is_global: true,
      colors: ["#101018", "#40a060", "#f0e0c0"],
    });

    for (let f = 0; f < 4; f++) {
      await sendCmd("draw_rect", { x: 4, y: 4, width: 6, height: 6, color: "#40a060", frame: f, layer: "Art" });
    }
    // Frame 3 introduces 2 off-palette pixels
    await sendCmd("draw_pixel", { x: 5, y: 5, color: "#ff00aa", frame: 3, layer: "Art" });
    await sendCmd("draw_pixel", { x: 6, y: 5, color: "#ff00aa", frame: 3, layer: "Art" });

    const qaRes = await sendCmd("validate_sprite", { all_frames: true, layer: "Art", palette: palName });
    assert(qaRes.success, `validate_sprite multi-frame failed: ${qaRes.error}`);
    assert.strictEqual(qaRes.data.multi_frame, true);
    assert.strictEqual(qaRes.data.frames_checked, 4);
    assert.strictEqual(qaRes.data.palette_name, palName);
    assert.strictEqual(qaRes.data.palette_compliant, false);
    assert.strictEqual(qaRes.data.total_off_palette_pixels, 2);
    assert.strictEqual(qaRes.data.per_frame[0].palette_compliant, true);
    assert.strictEqual(qaRes.data.per_frame[3].palette_compliant, false);
    assert.strictEqual(qaRes.data.per_frame[3].off_palette_pixel_count, 2);

    // Cleanup test palette
    await sendCmd("delete_palette", { name: palName });

    // Hidden 'anchors' layer coordinate extraction
    await sendCmd("add_layer", { name: "anchors" });
    await sendCmd("draw_pixel", { x: 8, y: 12, color: "#ff00ff", frame: 0, layer: "anchors" });
    await sendCmd("draw_pixel", { x: 4, y: 6, color: "#00ffff", frame: 0, layer: "anchors" });
    await sendCmd("draw_pixel", { x: 11, y: 6, color: "#00ffff", frame: 0, layer: "anchors" });
    await sendCmd("draw_pixel", { x: 9, y: 11, color: "#ff00ff", frame: 2, layer: "anchors" });
    await sendCmd("set_layer_visibility", { layer: "anchors", visible: false });

    const mkRes = await sendCmd("get_layer_markers", { layer: "anchors" });
    assert(mkRes.success, `get_layer_markers failed: ${mkRes.error}`);
    assert.strictEqual(mkRes.data.visible, false, "anchors layer must still be hidden");
    assert.strictEqual(mkRes.data.total_markers, 4);
    assert.deepStrictEqual(mkRes.data.markers["0"]["#ff00ff"], [[8, 12]]);
    assert.deepStrictEqual(mkRes.data.markers["0"]["#00ffff"], [[4, 6], [11, 6]]);
    assert.deepStrictEqual(mkRes.data.markers["2"]["#ff00ff"], [[9, 11]]);
    assert.strictEqual(mkRes.data.markers["1"], undefined, "Empty frame 1 omitted by default");
    console.log("  ✅ Multi-frame palette-validating validate_sprite & hidden-layer get_layer_markers verified");

    // ------------------------------------------------------------------
    // 7. close_canvas on the last remaining tab
    // ------------------------------------------------------------------
    console.log("[7/7] Testing close_canvas on the last remaining tab...");
    let list = await sendCmd("list_canvases", {});
    while (list.data.total_canvases > 1) {
      const c = await sendCmd("close_canvas", { index: list.data.total_canvases - 1 });
      assert(c.success, `Failed to close extra canvas: ${c.error}`);
      list = await sendCmd("list_canvases", {});
    }
    assert.strictEqual(list.data.total_canvases, 1, "Should have exactly 1 open canvas");

    // Explicit replace_with_blank: false must still block
    const blockedClose = await sendCmd("close_canvas", { replace_with_blank: false });
    assert(!blockedClose.success, "close_canvas(replace_with_blank=false) must refuse closing the last tab");

    // Default close_canvas() must succeed by replacing with a fresh blank 'untitled' canvas
    const autoClose = await sendCmd("close_canvas", {});
    assert(autoClose.success, `Default close_canvas on last tab failed: ${autoClose.error}`);
    assert.strictEqual(autoClose.data.replaced_with_blank, true);
    assert.strictEqual(autoClose.data.remaining_canvases, 1);
    assert.strictEqual(autoClose.data.active_name, "untitled");

    const infoAfter = await sendCmd("get_canvas_info", {});
    assert(infoAfter.success && infoAfter.data.name === "untitled", "Pixelorama must stay healthy on fresh 'untitled' tab");
    console.log("  ✅ close_canvas last-tab auto-replacement (and opt-out guard) verified");

    console.log("\n🎉 ALL v2.8 IMPROVEMENTS PASSED 7/7 VERIFICATION SUITES!");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

run().catch((err) => {
  console.error("❌ v2.8 test failed:", err);
  process.exit(1);
});
