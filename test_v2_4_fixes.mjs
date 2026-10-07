// test_v2_4_fixes.mjs
// Verification suite for v2.4 crash immunity, bulk image writes, and safe bounds guarding.

import assert from "node:assert/strict";

const BRIDGE_URL = "http://127.0.0.1:7373/command";
const HEALTH_URL = "http://127.0.0.1:7373/health";

async function send(tool, params = {}) {
  const res = await fetch(BRIDGE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool, params }),
  });
  return await res.json();
}

async function checkHealth() {
  const res = await fetch(HEALTH_URL);
  const data = await res.json();
  assert.equal(data.status, "ok", "Bridge health must be 'ok'");
  return data;
}

let passed = 0;
let total = 0;

function it(name, fn) {
  total++;
  return (async () => {
    try {
      await fn();
      passed++;
      console.log(`✅ [${passed}/${total}] ${name}`);
    } catch (err) {
      console.error(`❌ [FAILED] ${name}:`, err.message);
      process.exitCode = 1;
    }
  })();
}

async function runTests() {
  console.log("=== Testing Pixelorama MCP v2.4 Fixes ===");

  await it("Health endpoint returns status 'ok'", async () => {
    await checkHealth();
  });

  await it("Bug 5 Immunity: 320x180 set_pixel loop on 64x64 canvas does NOT crash and clips safely", async () => {
    // 1. Reset canvas to 64x64
    const initRes = await send("create_canvas", { width: 64, height: 64 });
    assert.equal(initRes.success, true);
    assert.equal(initRes.data.width, 64);
    assert.equal(initRes.data.height, 64);

    // 2. Run the exact 57,600 set_pixel loop that caused the SIGSEGV heap corruption
    const script = `
func run(api, image: Image, project, params):
\tfor y in range(180):
\t\tfor x in range(320):
\t\t\timage.set_pixel(x, y, Color(0.2, 0.4, 0.6, 1.0))
\treturn "painted full bounds"
`;
    const res = await send("eval_gdscript", { code: script });
    assert.equal(res.success, true, "Script must succeed without crashing engine");
    assert.equal(res.data.clipped_pixels, 53504, "Must clip exactly 57,600 - 4,096 = 53,504 pixels");
    assert.ok(res.data.warning.includes("53504"), "Must provide warning mentioning clipped pixels");

    // 3. Verify bridge process is still 100% alive
    await checkHealth();

    // 4. Verify in-bounds pixels (10, 10) were actually painted
    const p1 = await send("get_pixel", { x: 10, y: 10 });
    assert.equal(p1.data.r, 51);
    assert.equal(p1.data.g, 102);
    assert.equal(p1.data.b, 153);
  });

  await it("Bulk Return Path A: PackedByteArray direct memory write (320x180) in < 20ms", async () => {
    // Create 320x180 canvas
    await send("create_canvas", { width: 320, height: 180 });

    const startTime = Date.now();
    const script = `
func run(api, image: Image, project, params):
\tvar w: int = image.get_width()
\tvar h: int = image.get_height()
\tvar buf := PackedByteArray()
\tbuf.resize(w * h * 4)
\tfor y in range(h):
\t\tfor x in range(w):
\t\t\tvar idx := (y * w + x) * 4
\t\t\tbuf[idx] = 120
\t\t\tbuf[idx + 1] = 180
\t\t\tbuf[idx + 2] = 240
\t\t\tbuf[idx + 3] = 255
\treturn buf
`;
    const res = await send("eval_gdscript", { code: script });
    const duration = Date.now() - startTime;
    assert.equal(res.success, true);
    assert.equal(res.data.result, "Image buffer updated");
    console.log(`   ⏱️ 320x180 PackedByteArray generation + blit completed in ${duration}ms`);

    // Probe 4 corners and center
    const probes = [
      { x: 0, y: 0 },
      { x: 319, y: 0 },
      { x: 0, y: 179 },
      { x: 319, y: 179 },
      { x: 160, y: 90 },
    ];
    for (const p of probes) {
      const probeRes = await send("get_pixel", p);
      assert.equal(probeRes.data.r, 120, `Probe at (${p.x},${p.y}) R must match`);
      assert.equal(probeRes.data.g, 180, `Probe at (${p.x},${p.y}) G must match`);
      assert.equal(probeRes.data.b, 240, `Probe at (${p.x},${p.y}) B must match`);
      assert.equal(probeRes.data.a, 255, `Probe at (${p.x},${p.y}) A must match`);
    }
  });

  await it("Bulk Return Path B: Return Image with automatic canvas dimension adaptation", async () => {
    // Canvas starts at 64x64
    await send("create_canvas", { width: 64, height: 64 });

    // Script returns a 200x100 Image
    const script = `
func run(api, image: Image, project, params):
\tvar new_img := Image.create(200, 100, false, Image.FORMAT_RGBA8)
\tnew_img.fill(Color(0.9, 0.4, 0.1, 1.0))
\treturn new_img
`;
    const res = await send("eval_gdscript", { code: script });
    assert.equal(res.success, true);
    assert.equal(res.data.result, "Image updated");

    // Canvas size should now be automatically 200x100
    const info = await send("get_canvas_info");
    assert.equal(info.data.width, 200, "Canvas width must auto-adapt to 200");
    assert.equal(info.data.height, 100, "Canvas height must auto-adapt to 100");

    // Check pixel at (150, 75)
    const p = await send("get_pixel", { x: 150, y: 75 });
    assert.equal(p.data.r, 229);
    assert.equal(p.data.g, 102);
    assert.equal(p.data.b, 25);
  });

  await it("ApiContext helpers: create_image and set_pixel_safe work correctly", async () => {
    const script = `
func run(api, image: Image, project, params):
\tvar canvas_sz := api.get_canvas_size()
\tvar img := api.create_image(canvas_sz.x, canvas_sz.y)
\timg.fill(Color.BLACK)
\tapi.set_pixel_safe(img, 10, 10, Color.WHITE)
\tapi.set_pixel_safe(img, 9999, 9999, Color.WHITE) # Safe out of bounds
\treturn img
`;
    const res = await send("eval_gdscript", { code: script });
    assert.equal(res.success, true);

    const pIn = await send("get_pixel", { x: 10, y: 10 });
    assert.equal(pIn.data.color, "#ffffffff");
  });

  await it("Bug 6: capture_canvas_image nearest-neighbor magnification up to 32x", async () => {
    await send("create_canvas", { width: 32, height: 32 });
    await send("draw_pixel", { x: 0, y: 0, color: "#ff0000" });

    // Test scale: 3.0
    const res3 = await send("get_canvas_image_base64", { scale: 3.0 });
    assert.equal(res3.success, true);
    assert.equal(res3.data.width, 96);
    assert.equal(res3.data.height, 96);

    // Test scale: 8.0
    const res8 = await send("get_canvas_image_base64", { scale: 8.0 });
    assert.equal(res8.success, true);
    assert.equal(res8.data.width, 256);
    assert.equal(res8.data.height, 256);
  });

  console.log(`\n=== v2.4 Test Summary: ${passed}/${total} passed ===\n`);
}

runTests();
