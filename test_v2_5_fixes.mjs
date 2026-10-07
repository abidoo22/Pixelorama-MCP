import assert from 'node:assert';

const BRIDGE_URL = "http://127.0.0.1:7373";

async function sendCommand(tool, params = {}) {
  const res = await fetch(`${BRIDGE_URL}/command`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool, params })
  });
  return await res.json();
}

async function runTests() {
  console.log("=== Testing v2.5 Fixes ===");

  // 1. Create a clean test canvas (64x64)
  console.log("\n[Test 1] Create Test Canvas");
  const createRes = await sendCommand("create_canvas", { width: 64, height: 64, name: "CanvasOne" });
  assert(createRes.success, `Failed to create canvas: ${createRes.error}`);
  console.log("✅ Created CanvasOne (64x64)");

  // 2. draw_text scaling and bounding box
  console.log("\n[Test 2] draw_text integer scaling and bounding box");
  // Test scale: 1
  const dt1 = await sendCommand("draw_text", { text: "A", x: 10, y: 10, scale: 1, color: "#ffffff" });
  assert(dt1.success, `draw_text scale 1 failed: ${dt1.error}`);
  assert.strictEqual(dt1.data.scale, 1);
  assert.strictEqual(dt1.data.glyph_height, 5);
  assert.strictEqual(dt1.data.char_advance, 5);
  assert(dt1.data.bounding_box, "Bounding box missing in draw_text response");
  console.log("  scale 1 bbox:", JSON.stringify(dt1.data.bounding_box));
  // 'A' bitmap is 4x5, at (10, 10), so left=10, top=10, width=4, height=5
  assert.strictEqual(dt1.data.bounding_box.width, 4);
  assert.strictEqual(dt1.data.bounding_box.height, 5);
  assert.strictEqual(dt1.data.bounding_box.left, 10);
  assert.strictEqual(dt1.data.bounding_box.top, 10);
  assert.strictEqual(dt1.data.bounding_box.advance, 5); // 5 * 1

  // Test scale: 2
  const dt2 = await sendCommand("draw_text", { text: "A", x: 20, y: 20, scale: 2, color: "#ff0000" });
  assert(dt2.success, `draw_text scale 2 failed: ${dt2.error}`);
  assert.strictEqual(dt2.data.scale, 2);
  assert.strictEqual(dt2.data.glyph_height, 10);
  assert.strictEqual(dt2.data.char_advance, 10);
  console.log("  scale 2 bbox:", JSON.stringify(dt2.data.bounding_box));
  // 'A' scaled 2x is 8x10
  assert.strictEqual(dt2.data.bounding_box.width, 8);
  assert.strictEqual(dt2.data.bounding_box.height, 10);
  assert.strictEqual(dt2.data.bounding_box.advance, 10); // 5 * 2

  // Test auto-mapping from font_size: 16 (maps to 2x)
  const dt3 = await sendCommand("draw_text", { text: "B", x: 0, y: 0, font_size: 16, color: "#00ff00" });
  assert(dt3.success, `draw_text font_size 16 failed: ${dt3.error}`);
  assert.strictEqual(dt3.data.scale, 2, `Expected scale 2 for font_size 16, got ${dt3.data.scale}`);
  assert.strictEqual(dt3.data.glyph_height, 10);
  console.log("  font_size 16 auto-scale bbox:", JSON.stringify(dt3.data.bounding_box));
  assert.strictEqual(dt3.data.bounding_box.width, 8);
  assert.strictEqual(dt3.data.bounding_box.height, 10);

  console.log("✅ draw_text scaling and bounding box verified");

  // 3. switch_canvas by name and index
  console.log("\n[Test 3] switch_canvas by name and index");
  const createRes2 = await sendCommand("create_canvas", { width: 32, height: 32, name: "SecondCanvas" });
  assert(createRes2.success, `Failed to create SecondCanvas: ${createRes2.error}`);

  // Switch by canvas param
  const sw1 = await sendCommand("switch_canvas", { canvas: "CanvasOne" });
  assert(sw1.success, `switch_canvas by canvas 'CanvasOne' failed: ${sw1.error}`);
  assert.strictEqual(sw1.data.name, "CanvasOne");
  console.log("  Switched to canvas:", sw1.data.name);

  // Switch by explicit name param
  const swName = await sendCommand("switch_canvas", { name: "SecondCanvas" });
  assert(swName.success, `switch_canvas by name 'SecondCanvas' failed: ${swName.error}`);
  assert.strictEqual(swName.data.name, "SecondCanvas");
  console.log("  Switched to explicit name:", swName.data.name);

  // Switch by index
  const listRes = await sendCommand("list_canvases", {});
  const secondIdx = listRes.data.canvases.findIndex(c => c.name === "SecondCanvas");
  const sw2 = await sendCommand("switch_canvas", { index: secondIdx });
  assert(sw2.success, `switch_canvas by index ${secondIdx} failed: ${sw2.error}`);
  assert.strictEqual(sw2.data.name, "SecondCanvas");
  console.log(`  Switched to index ${secondIdx}:`, sw2.data.name);

  console.log("✅ switch_canvas by name and index verified");

  // 4. eval_gdscript return values (String, Array, Dictionary)
  console.log("\n[Test 4] eval_gdscript custom return values");
  // Test String return
  const evalStr = await sendCommand("eval_gdscript", {
    code: `func run(api, image: Image, project, params: Dictionary):\n\treturn "hello pixelorama"`
  });
  assert(evalStr.success, `eval_gdscript string return failed: ${evalStr.error}`);
  assert.strictEqual(evalStr.data.value, "hello pixelorama");
  console.log("  String return value:", evalStr.data.value);

  // Test Array return
  const evalArr = await sendCommand("eval_gdscript", {
    code: `func run(api, image: Image, project, params: Dictionary):\n\treturn [10, 20, 30, "dither"]`
  });
  assert(evalArr.success, `eval_gdscript array return failed: ${evalArr.error}`);
  assert.deepStrictEqual(evalArr.data.value, [10, 20, 30, "dither"]);
  console.log("  Array return value:", evalArr.data.value);

  // Test Dictionary return
  const evalDict = await sendCommand("eval_gdscript", {
    code: `func run(api, image: Image, project, params: Dictionary):\n\treturn {"lit_pixels": 128, "coverage": 0.5}`
  });
  assert(evalDict.success, `eval_gdscript dict return failed: ${evalDict.error}`);
  assert.strictEqual(evalDict.data.value.lit_pixels, 128);
  console.log("  Dict return value:", evalDict.data.value);

  console.log("✅ eval_gdscript custom return values verified");

  // 5. eval_gdscript compile error line and column info
  console.log("\n[Test 5] eval_gdscript compile error details extraction");
  const evalBad = await sendCommand("eval_gdscript", {
    code: `func run(api, image: Image, project, params: Dictionary):\n\tvar x: int = "not an int"\n\treturn x`
  });
  assert(!evalBad.success, "eval_gdscript should have failed on invalid type assignment");
  console.log("  Reported error:", evalBad.error);
  assert(evalBad.error.includes("Parse Error") || evalBad.error.includes("Cannot assign a value of type"), `Expected parse error description, got: ${evalBad.error}`);
  assert(/line \d+/.test(evalBad.error), `Expected line number in error, got: ${evalBad.error}`);
  console.log("✅ eval_gdscript compile error details verified");

  // 6. get_canvas_image_base64 metadata (scale, region, downscaled)
  console.log("\n[Test 6] get_canvas_image_base64 metadata");
  const imgMeta = await sendCommand("get_canvas_image_base64", { x: 5, y: 5, width: 20, height: 20, scale: 2.0 });
  assert(imgMeta.success, `get_canvas_image_base64 failed: ${imgMeta.error}`);
  assert.strictEqual(imgMeta.data.width, 40); // 20 * 2
  assert.strictEqual(imgMeta.data.height, 40);
  assert.strictEqual(imgMeta.data.scale, 2.0);
  assert(imgMeta.data.region, "Region should be populated");
  assert.strictEqual(imgMeta.data.region.width, 20);
  console.log("  Image metadata:", { width: imgMeta.data.width, height: imgMeta.data.height, scale: imgMeta.data.scale, region: imgMeta.data.region });
  console.log("✅ get_canvas_image_base64 metadata verified");

  // 7. eval_gdscript auto-resize warning
  console.log("\n[Test 7] eval_gdscript auto-resize warning on Image return");
  await sendCommand("create_canvas", { width: 64, height: 64, name: "ResizeTestCanvas" });
  const resizeRes = await sendCommand("eval_gdscript", {
    code: `func run(api, image: Image, project, params: Dictionary) -> Image:\n\treturn Image.create(16, 16, false, Image.FORMAT_RGBA8)`
  });
  assert(resizeRes.success, `eval_gdscript resize failed: ${resizeRes.error}`);
  assert(resizeRes.data.canvas_resized === true, "canvas_resized flag should be true");
  assert(resizeRes.data.warning && resizeRes.data.warning.includes("Canvas automatically resized"), `Expected resize warning, got: ${resizeRes.data.warning}`);
  console.log("  Resize warning captured:", resizeRes.data.warning);
  console.log("✅ eval_gdscript auto-resize warning verified");

  console.log("\n🎉 ALL v2.5 FIXES PASSING SUCCESSFULLY!");
}

runTests().catch(err => {
  console.error("❌ Test failed:", err);
  process.exit(1);
});
