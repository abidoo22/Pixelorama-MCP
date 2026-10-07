import http from 'http';

function postCommand(tool, params = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ tool, params });
    const req = http.request(
      'http://127.0.0.1:7373/command',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
        },
        timeout: 10000,
      },
      (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => {
          try {
            resolve(JSON.parse(body));
          } catch (e) {
            resolve({ success: false, raw: body, error: e.message });
          }
        });
      }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  ✅ PASS: ${message}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${message}`);
    failed++;
  }
}

async function run() {
  console.log('\n=== Testing Pixelorama MCP v2.0.2 Patches ===\n');

  // Setup canvas
  await postCommand('create_canvas', { width: 400, height: 100, name: 'PatchTest' });

  // ── TEST 1: params forwarding in eval_gdscript ──────────────────────────────
  console.log('1. Testing params forwarding in eval_gdscript...');
  const resParams = await postCommand('eval_gdscript', {
    code: `image.set_pixel(0, 0, Color8(int(params.get("r", 1)), int(params.get("g", 2)), int(params.get("b", 3)), 255))
return {"received_keys": params.keys(), "r": params.get("r")}`,
    params: { r: 11, g: 22, b: 33 },
  });
  assert(resParams.success === true, 'eval_gdscript with params executed successfully');
  assert(resParams.data?.result?.r === 11, `Script read params.r === 11 (got: ${resParams.data?.result?.r})`);

  const px0 = await postCommand('get_pixel', { x: 0, y: 0 });
  assert(
    px0.data?.r === 11 && px0.data?.g === 22 && px0.data?.b === 33,
    `Pixel (0,0) set to exact Color8(11, 22, 33): got R=${px0.data?.r}, G=${px0.data?.g}, B=${px0.data?.b}`
  );

  // ── TEST 2: 1-arg run(image: Image) dispatch ────────────────────────────────
  console.log('\n2. Testing 1-argument run(image: Image) and run(image) dispatch...');
  const res1ArgTyped = await postCommand('eval_gdscript', {
    code: `func run(image: Image) -> void:
	image.set_pixel(1, 1, Color.RED)`,
  });
  assert(res1ArgTyped.success === true, 'run(image: Image) executed successfully');
  const px1 = await postCommand('get_pixel', { x: 1, y: 1 });
  assert(px1.data?.color === '#ff0000ff', `Pixel (1,1) drawn by run(image: Image): got ${px1.data?.color}`);

  const res1ArgUntyped = await postCommand('eval_gdscript', {
    code: `func run(image) -> void:
	image.set_pixel(2, 2, Color.GREEN)`,
  });
  assert(res1ArgUntyped.success === true, 'run(image) executed successfully');
  const px2 = await postCommand('get_pixel', { x: 2, y: 2 });
  assert(px2.data?.color === '#00ff00ff', `Pixel (2,2) drawn by run(image): got ${px2.data?.color}`);

  // ── TEST 3: draw_pixels_fast object array rejection ─────────────────────────
  console.log('\n3. Testing draw_pixels_fast object array rejection...');
  const resFastObj = await postCommand('draw_pixels_fast', {
    pixels: [{ x: 5, y: 5, color: '#ffffff' }],
  });
  assert(resFastObj.success === false, 'draw_pixels_fast correctly rejected object array');
  assert(
    resFastObj.error?.includes('requires a flat array') || resFastObj.error?.includes('Use \'draw_pixels\''),
    `Error clearly instructs caller: "${resFastObj.error}"`
  );

  // Verify flat array works
  const resFastFlat = await postCommand('draw_pixels_fast', {
    data: [5, 5, '#ffffff'],
  });
  assert(resFastFlat.success === true, 'draw_pixels_fast accepted flat array [5, 5, "#ffffff"]');
  const px5 = await postCommand('get_pixel', { x: 5, y: 5 });
  assert(px5.data?.color === '#ffffffff', `Pixel (5,5) drawn: ${px5.data?.color}`);

  // ── TEST 4: Horizontal Linear Gradient Vector Projection & Feather ──────────
  console.log('\n4. Testing 2D vector projection & feather on horizontal gradient...');
  // Draw horizontal gradient across full canvas [0, 0, 400, 100]
  const resGrad = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 100,
    type: 'linear',
    direction: 'horizontal',
    color1: '#ffffff',
    color2: '#ffffff00',
    dither: false,
    blend: false,
    feather: 0.0,
  });
  assert(resGrad.success === true, 'apply_gradient horizontal ramp executed');

  // Probe row y = 50 across x = 0, 100, 200, 300, 399
  const pX0 = await postCommand('get_pixel', { x: 0, y: 50 });
  const pX100 = await postCommand('get_pixel', { x: 100, y: 50 });
  const pX200 = await postCommand('get_pixel', { x: 200, y: 50 });
  const pX300 = await postCommand('get_pixel', { x: 300, y: 50 });
  const pX399 = await postCommand('get_pixel', { x: 399, y: 50 });

  console.log(`    Horizontal Alpha profile at y=50:
    x=0: a=${pX0.data?.a}
    x=100: a=${pX100.data?.a}
    x=200: a=${pX200.data?.a}
    x=300: a=${pX300.data?.a}
    x=399: a=${pX399.data?.a}`);

  assert(pX0.data?.a === 255, `Start x=0 is opaque (a=255)`);
  assert(pX100.data?.a > 170 && pX100.data?.a < 210, `Quarter x=100 ramps down (got a=${pX100.data?.a})`);
  assert(pX200.data?.a > 110 && pX200.data?.a < 145, `Mid x=200 is ~half (got a=${pX200.data?.a})`);
  assert(pX300.data?.a > 50 && pX300.data?.a < 80, `Three-quarter x=300 ramps down (got a=${pX300.data?.a})`);
  assert(pX399.data?.a <= 5, `End x=399 is transparent (got a=${pX399.data?.a})`);

  // ── TEST 5: Feather non-destructive edge easing ─────────────────────────────
  console.log('\n5. Testing apply_gradient with feather: 0.2...');
  const resFeather = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 100,
    type: 'linear',
    direction: 'horizontal',
    color1: '#ffffff',
    color2: '#ffffff00',
    dither: false,
    blend: false,
    feather: 0.2,
  });
  assert(resFeather.success === true, 'apply_gradient with feather: 0.2 executed');

  const pFeatherMid = await postCommand('get_pixel', { x: 200, y: 50 });
  console.log(`    Feather mid x=200 alpha: ${pFeatherMid.data?.a}`);
  assert(
    pFeatherMid.data?.a > 115 && pFeatherMid.data?.a < 140,
    `Center x=200 is preserved and NOT flattened (a=${pFeatherMid.data?.a})`
  );

  // ── TEST 6: Visual Canvas Capture ───────────────────────────────────────────
  console.log('\n6. Capturing visual canvas image for verification...');
  const visualSnap = await postCommand('get_canvas_image_base64', {
    max_size: 128,
  });
  assert(visualSnap.success === true, 'get_canvas_image_base64 succeeded');
  assert(visualSnap.data?.base64?.length > 100, `Captured base64 PNG image (${visualSnap.data?.base64?.length} bytes)`);

  console.log(`\n========================================`);
  console.log(`Patch Test Results: ${passed} PASSED, ${failed} FAILED`);
  console.log(`========================================\n`);

  if (failed > 0) process.exit(1);
}

run().catch((e) => {
  console.error('Fatal error running tests:', e);
  process.exit(1);
});
