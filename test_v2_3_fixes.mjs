import http from 'http';

function postCommand(tool, params = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ tool, params });
    const req = http.request('http://127.0.0.1:7373/command', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
      },
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          reject(new Error(`Failed to parse response: ${body}`));
        }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function runTests() {
  console.log("=== Running Patch v2.3 Verification Suite ===\n");
  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`✅ PASS: ${message}`);
      passed++;
    } else {
      console.error(`❌ FAIL: ${message}`);
      failed++;
    }
  }

  // 1. Test Compile Error Reporting with Exact Location
  console.log("--- 1. Testing Compile Error Location Extraction ---");
  const compRes = await postCommand("eval_gdscript", {
    code: "extends RefCounted\nfunc run():\n\tvar x =\n\treturn 42"
  });
  assert(compRes.success === false, "Compilation failure returns success: false");
  assert(compRes.error.includes("Parse Error") && compRes.error.includes("line 3"), `Error reported line number: ${compRes.error}`);

  // 2. Test := Variant Inference Auto-Fallback
  console.log("\n--- 2. Testing ':=' Variant Inference Auto-Fallback ---");
  const inferRes = await postCommand("eval_gdscript", {
    code: `func run(api, image: Image, project, params: Dictionary):
\tvar st := [[0.00, Color.WHITE], [1.00, Color.BLACK]]
\tvar c := st[0][1]
\tvar tier := floor(0.5 * 6.0)
\tvar tf := 0.5 * 6.0 - tier
\treturn [c.to_html(), tier, tf]`
  });
  assert(inferRes.success === true, `Chained ':=' script compiled and executed: ${JSON.stringify(inferRes.data?.result)}`);

  // 3. Test Runtime Error Interception (Zero Silent Failures)
  console.log("\n--- 3. Testing Runtime Error Interception ---");
  const rtRes = await postCommand("eval_gdscript", {
    code: `extends RefCounted
func run():
\tpush_error("Division by zero or out of bounds simulated")
\treturn "should not commit"`
  });
  assert(rtRes.success === false, "Runtime error returns success: false");
  assert(rtRes.error && rtRes.error.includes("runtime error") && rtRes.error.includes("Division by zero"), `Runtime error message captured: ${rtRes.error}`);

  // 4. Test Cross-Layer Access via ApiContext
  console.log("\n--- 4. Testing Cross-Layer Access via ApiContext ---");
  await postCommand("create_canvas", { width: 32, height: 32, name: "test_cross_layer" });
  await postCommand("draw_pixel", { x: 5, y: 5, color: "#ff1122" }); // Layer 0
  await postCommand("add_layer", { name: "ReflectionLayer" }); // Layer 1

  const crossRes = await postCommand("eval_gdscript", {
    code: `func run(api, image: Image, project, params: Dictionary):
\tvar sky_img = api.get_layer_image(0)
\tvar sky_px = sky_img.get_pixel(5, 5)
\tvar direct_px = api.get_pixel(5, 5, 0)
\tvar sz = api.get_canvas_size()
\tvar layers = api.get_layers()
\timage.set_pixel(5, 10, direct_px)
\treturn {
\t\t"sky_px": sky_px.to_html(),
\t\t"direct_px": direct_px.to_html(),
\t\t"width": sz.x,
\t\t"height": sz.y,
\t\t"total_layers": layers.size()
\t}`
  });
  assert(crossRes.success === true, `Cross-layer eval succeeded: ${JSON.stringify(crossRes.data?.result)}`);
  assert(crossRes.data?.result?.direct_px === "ff1122ff", `Direct pixel sampled: ${crossRes.data?.result?.direct_px}`);
  assert(crossRes.data?.result?.total_layers === 2, `Total layers queried: ${crossRes.data?.result?.total_layers}`);

  const lakePx = await postCommand("get_pixel", { x: 5, y: 10, layer: 1 });
  assert(lakePx.data?.color === "#ff1122ff", `Reflected pixel was painted on target layer: ${lakePx.data?.color}`);

  // 5. Test Bulk Image and PackedByteArray Return
  console.log("\n--- 5. Testing Bulk Image and PackedByteArray Return ---");
  // 5a. Return Image
  const imgRes = await postCommand("eval_gdscript", {
    code: `func run(api, image: Image, project, params: Dictionary):
\tvar new_img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
\tnew_img.fill(Color(1.0, 0.5, 0.0, 1.0)) # Orange
\treturn new_img`
  });
  assert(imgRes.success === true && imgRes.data?.result === "Image updated", "Bulk Image return accepted");
  const pxOrange = await postCommand("get_pixel", { x: 10, y: 10 });
  assert(pxOrange.data?.color === "#ff7f00ff", `Pixel from returned Image is orange: ${pxOrange.data?.color}`);

  // 5b. Return PackedByteArray
  const bufRes = await postCommand("eval_gdscript", {
    code: `func run(api, image: Image, project, params: Dictionary):
\tvar buf := PackedByteArray()
\tbuf.resize(32 * 32 * 4)
\tfor i in range(0, 32 * 32 * 4, 4):
\t\tbuf[i] = 0
\t\tbuf[i + 1] = 255 # Green
\t\tbuf[i + 2] = 128 # Cyan-green
\t\tbuf[i + 3] = 255
\treturn buf`
  });
  assert(bufRes.success === true && bufRes.data?.result === "Image buffer updated", "Bulk PackedByteArray return accepted");
  const pxBuf = await postCommand("get_pixel", { x: 10, y: 10 });
  assert(pxBuf.data?.g === 255 && pxBuf.data?.b === 128, `Pixel from PackedByteArray is green/cyan: ${pxBuf.data?.color}`);

  // 6. Test capture_canvas_image Scale > 1.0 (Upscaling)
  console.log("\n--- 6. Testing capture_canvas_image Upscaling (Scale > 1.0) ---");
  const scaleRes = await postCommand("get_canvas_image_base64", { scale: 4.0 });
  assert(scaleRes.success === true, "capture_canvas_image with scale: 4.0 succeeded");
  assert(scaleRes.data?.width === 128 && scaleRes.data?.height === 128, `Image upscaled 4x (32x32 -> ${scaleRes.data?.width}x${scaleRes.data?.height})`);

  // 7. Test Canvas Fill Color Guarantee & Statement Normalization
  console.log("\n--- 7. Testing Canvas Fill Color Guarantee & Statement Normalization ---");
  // 7a. Fill Color Guarantee
  const fillRes = await postCommand("create_canvas", { width: 32, height: 32, fill_color: "#05070f" });
  assert(fillRes.success === true, "Canvas created with fill_color");
  const fillPx = await postCommand("get_pixel", { x: 0, y: 0 });
  assert(fillPx.data?.color === "#05070fff", `Initial pixel matches fill_color: ${fillPx.data?.color}`);

  // 7b. Bare statement form with 2-space indentation
  const stmtRes = await postCommand("eval_gdscript", {
    code: `  var test_col = Color.CORAL
  image.set_pixel(2, 2, test_col)`
  });
  assert(stmtRes.success === true, "Bare statement form with 2-space indentation executed");
  const stmtPx = await postCommand("get_pixel", { x: 2, y: 2 });
  assert(stmtPx.data?.r > 200 && stmtPx.data?.g > 100, `Pixel modified via bare statement form: ${stmtPx.data?.color}`);

  console.log(`\n========================================`);
  console.log(`VERIFICATION SUMMARY: ${passed} passed, ${failed} failed`);
  console.log(`========================================`);
  if (failed > 0) process.exit(1);
}

runTests().catch(err => {
  console.error("Test execution error:", err);
  process.exit(1);
});
