// test_v2_6_fixes.mjs - Automated test suite for v2.6 fixes
import http from "node:http";

function sendCmd(tool, params = {}) {
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
        timeout: 10000,
      },
      (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(body));
          } catch (e) {
            resolve({ success: false, raw: body, error: e.message });
          }
        });
      }
    );
    req.on("error", (err) => reject(err));
    req.write(postData);
    req.end();
  });
}

async function runTests() {
  console.log("=== Running v2.6 Test Suite ===");
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

  // Ensure fresh canvas
  const createRes = await sendCmd("create_canvas", { width: 64, height: 64, name: "Test_v2_6" });
  assert(createRes.success, "create_canvas 64x64");

  // TEST 1: The exact crash trigger script: (a0[0] as PackedFloat32Array)[x]
  // In v2.5 this killed Pixelorama with SIGSEGV at offset +0x2bc5670.
  // In v2.6 the bridge sanitizes unsafe inline casts, allowing dynamic Variant indexing,
  // which safely evaluates (null) and finishes without crashing the editor!
  console.log("\n--- Test 1: Unsafe inline cast guarding ---");
  const badCastScript = `
func run(api, image: Image, project, params: Dictionary) -> Variant:
\tvar tops: Array = [PackedFloat32Array([10.0, 20.0])]
\tvar a0: Array = tops[0]
\tvar x: int = 0
\t# The unsafe pattern that crashed v2.5:
\treturn (a0[0] as PackedFloat32Array)[x]
`;
  const badCastRes = await sendCmd("eval_gdscript", { code: badCastScript });
  assert(badCastRes.success && badCastRes.data?.value === null,
    `bad cast safely evaluated without SIGSEGV crash (returned value: ${badCastRes.data?.value})`);

  // Verify Pixelorama is still alive
  const health1 = await sendCmd("get_canvas_info");
  assert(health1.success, "Pixelorama process is ALIVE and fully responsive after bad cast script");

  // TEST 2: Valid script without cast or with proper PackedFloat32Array indexing
  console.log("\n--- Test 2: Correct array indexing ---");
  const goodScript = `
func run(api, image: Image, project, params: Dictionary) -> Variant:
\tvar tops: Array = [PackedFloat32Array([10.0, 20.0])]
\tvar sm: PackedFloat32Array = tops[0]
\tvar x: int = 1
\treturn sm[x]
`;
  const goodRes = await sendCmd("eval_gdscript", { code: goodScript });
  assert(goodRes.success && goodRes.data?.value === 20.0, `good script returns 20.0 (got ${goodRes.data?.value})`);

  // TEST 3: Bulk PackedByteArray return with record_undo: false
  console.log("\n--- Test 3: PackedByteArray return with record_undo: false ---");
  const bulkScript = `
func run(api, image: Image, project, params: Dictionary) -> PackedByteArray:
\tvar w: int = 64
\tvar h: int = 64
\tvar buf := PackedByteArray()
\tbuf.resize(w * h * 4)
\tfor i in range(w * h):
\t\tbuf[i * 4 + 0] = 120
\t\tbuf[i * 4 + 1] = 180
\t\tbuf[i * 4 + 2] = 240
\t\tbuf[i * 4 + 3] = 255
\treturn buf
`;
  const bulkRes = await sendCmd("eval_gdscript", { code: bulkScript, record_undo: false });
  assert(bulkRes.success, "PackedByteArray bulk blit succeeded with record_undo: false");

  // Verify pixels were written
  const pxRes = await sendCmd("get_pixel", { x: 32, y: 32 });
  assert(pxRes.success && pxRes.data?.color === "#78b4f0ff", `Pixel (32,32) color matches painted buffer (got ${pxRes.data?.color})`);

  // TEST 4: Yield and OS breathing test
  console.log("\n--- Test 4: OS breathing & multi-pass stress ---");
  let allPass = true;
  for (let pass = 0; pass < 3; pass++) {
    const res = await sendCmd("eval_gdscript", {
      code: `
func run(api, image: Image, project, params: Dictionary) -> String:
\treturn "pass_${pass}"
`,
      record_undo: false,
    });
    if (!res.success || res.data?.value !== `pass_${pass}`) {
      allPass = false;
      break;
    }
  }
  assert(allPass, "Multi-pass eval_gdscript with record_undo: false completed reliably");

  console.log(`\n=== RESULTS: ${passed}/${total} passed ===`);
  if (passed === total) {
    console.log("🎉 ALL V2.6 TESTS PASSED!");
    process.exit(0);
  } else {
    console.error("❌ SOME TESTS FAILED!");
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error("Test error:", err);
  process.exit(1);
});
