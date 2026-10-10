// test_v2_7_fixes.mjs - Automated verification suite for v2.7 crash prevention and bridge watchdog
import http from "node:http";

function sendCmd(tool, params = {}, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({ tool, params });
    const req = http.request(
      "http://127.0.0.1:7373/command",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(postData),
        },
        timeout: timeoutMs,
      },
      (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => {
          try {
            resolve({ statusCode: res.statusCode, ...JSON.parse(body) });
          } catch (e) {
            resolve({ statusCode: res.statusCode, success: false, raw: body, error: e.message });
          }
        });
      }
    );
    req.on("error", (err) => reject(err));
    req.write(postData);
    req.end();
  });
}

function getHealth() {
  return new Promise((resolve, reject) => {
    const req = http.get("http://127.0.0.1:7373/health", { timeout: 5000 }, (res) => {
      let body = "";
      res.on("data", (chunk) => (body += chunk));
      res.on("end", () => {
        try {
          resolve({ statusCode: res.statusCode, ...JSON.parse(body) });
        } catch (e) {
          resolve({ statusCode: res.statusCode, error: e.message });
        }
      });
    });
    req.on("error", (err) => reject(err));
  });
}

async function runTests() {
  console.log("=== Running v2.7 Fixes Test Suite ===");
  let passed = 0;
  let total = 0;

  function assert(cond, name) {
    total++;
    if (cond) {
      console.log(`  ✅ PASS: ${name}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${name}`);
    }
  }

  // 0. Verify bridge is responding
  const health0 = await getHealth();
  assert(health0.statusCode === 200 && health0.status === "ok", "Bridge /health endpoint responds OK");

  // 1. Setup canvas
  const createRes = await sendCmd("create_canvas", { width: 128, height: 128, name: "Test_v2_7" });
  assert(createRes.success, "create_canvas 128x128");

  // TEST 1: The exact crash trigger from PID 2705
  // Drawing agent ran: var base: Image = api.get_layer_image("base_traced")
  // followed by base.get_width() in a helper function.
  // In v2.6, if the layer wasn't found, get_layer_image returned null,
  // causing instant native SIGSEGV at offset 0x2cb4b50 (Image::get_width on nullptr).
  // In v2.7, get_layer_image returns a transparent canvas-sized Image fallback!
  console.log("\n--- Test 1: Missing layer query (PID 2705 trigger) ---");
  const missingLayerScript = `
func edge_scan(base: Image, x: int, y: int) -> Color:
\tvar bw := base.get_width()
\tvar bh := base.get_height()
\treturn base.get_pixel(x, y)

func run(api, image: Image, project, params: Dictionary) -> Dictionary:
\tvar base: Image = api.get_layer_image("non_existent_layer")
\tvar bw := base.get_width()
\tvar bh := base.get_height()
\tvar col := edge_scan(base, 10, 10)
\treturn { "bw": bw, "bh": bh, "alpha": col.a }
`;
  const t1Res = await sendCmd("eval_gdscript", { code: missingLayerScript });
  assert(
    t1Res.success &&
      t1Res.data?.value?.bw === 128 &&
      t1Res.data?.value?.bh === 128 &&
      t1Res.data?.value?.alpha === 0,
    `Missing layer fallback: returned 128x128 transparent Image without SIGSEGV (got ${JSON.stringify(t1Res.data?.value)})`
  );

  // TEST 2: Direct NULL Image dereference protection
  // Even if a script explicitly holds a null Image reference,
  // the bridge transparently rewrites .get_width(), .get_height(), .get_pixel()
  // to safe guards, preventing any hardware crash!
  console.log("\n--- Test 2: Direct null Image dereference protection ---");
  const nullDerefScript = `
func run(api, image: Image, project, params: Dictionary) -> Dictionary:
\tvar null_img: Image = null
\tvar w := null_img.get_width()
\tvar h := null_img.get_height()
\tvar px := null_img.get_pixel(5, 5)
\treturn { "w": w, "h": h, "alpha": px.a }
`;
  const t2Res = await sendCmd("eval_gdscript", { code: nullDerefScript });
  assert(
    t2Res.success &&
      t2Res.data?.value?.w === 0 &&
      t2Res.data?.value?.h === 0 &&
      t2Res.data?.value?.alpha === 0,
    `Direct null Image dereference safely guarded: w=0, h=0, a=0 without SIGSEGV (got ${JSON.stringify(t2Res.data?.value)})`
  );

  // TEST 3: New ApiContext helper functions (has_layer, is_valid_image)
  console.log("\n--- Test 3: ApiContext has_layer and is_valid_image ---");
  const helperScript = `
func run(api, image: Image, project, params: Dictionary) -> Dictionary:
\treturn {
\t\t"has_missing": api.has_layer("ghost_layer"),
\t\t"has_active": api.has_layer(0),
\t\t"valid_img": api.is_valid_image(image),
\t\t"invalid_img": api.is_valid_image(null)
\t}
`;
  const t3Res = await sendCmd("eval_gdscript", { code: helperScript });
  assert(
    t3Res.success &&
      t3Res.data?.value?.has_missing === false &&
      t3Res.data?.value?.has_active === true &&
      t3Res.data?.value?.valid_img === true &&
      t3Res.data?.value?.invalid_img === false,
    `ApiContext helpers verified (got ${JSON.stringify(t3Res.data?.value)})`
  );

  // TEST 4: Large canvas (1280x720) procedural pass with PackedByteArray blit
  console.log("\n--- Test 4: 1280x720 large canvas procedural generation pass ---");
  const c1280Res = await sendCmd("create_canvas", { width: 1280, height: 720, name: "Large_1280_Test" });
  assert(c1280Res.success, "create_canvas 1280x720 created");

  const largeProcScript = `
func run(api, image: Image, project, params: Dictionary) -> PackedByteArray:
\tvar w := 1280
\tvar h := 720
\tvar buf := PackedByteArray()
\tbuf.resize(w * h * 4)
\t# Fill top-left test rectangle
\tfor y in range(50):
\t\tfor x in range(50):
\t\t\tvar idx := (y * w + x) * 4
\t\t\tbuf[idx + 0] = 43
\t\t\tbuf[idx + 1] = 29
\t\t\tbuf[idx + 2] = 22
\t\t\tbuf[idx + 3] = 255
\treturn buf
`;
  const t4Res = await sendCmd("eval_gdscript", { code: largeProcScript, record_undo: false }, 30000);
  assert(t4Res.success, "1280x720 procedural blit completed with record_undo: false");

  const pxCheck = await sendCmd("get_pixel", { x: 25, y: 25 });
  assert(pxCheck.success && pxCheck.data?.color === "#2b1d16ff", `Pixel (25,25) matches #2b1d16ff (got ${pxCheck.data?.color})`);

  // TEST 5: Verify bridge and /health are alive and responsive after heavy pass
  console.log("\n--- Test 5: Post-load bridge responsiveness ---");
  const healthFinal = await getHealth();
  assert(healthFinal.statusCode === 200 && healthFinal.status === "ok", "Bridge /health endpoint remains fast and healthy");

  console.log(`\n=== RESULTS: ${passed}/${total} passed ===`);
  if (passed === total) {
    console.log("🎉 ALL V2.7 TESTS PASSED SUCCESSFULLY!");
    process.exit(0);
  } else {
    console.error("❌ SOME TESTS FAILED!");
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
