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
  console.log('\n=== Testing Pixelorama MCP v2.0.1 Fixes ===\n');

  // Setup canvas
  await postCommand('create_canvas', { width: 128, height: 128, name: 'TestV2' });

  // ── TEST 1: eval_gdscript Bare Statements ──────────────────────────────────
  console.log('1. Testing eval_gdscript with bare statements...');
  const res1 = await postCommand('eval_gdscript', {
    code: 'image.set_pixel(10, 10, Color.BLUE)\nimage.set_pixel(11, 11, Color.YELLOW)\nreturn "bare_ok"',
  });
  assert(res1.success === true, 'eval_gdscript bare statements succeeded');
  assert(res1.data?.frame !== undefined, `eval_gdscript returned frame: ${res1.data?.frame}`);
  assert(res1.data?.layer !== undefined, `eval_gdscript returned layer: ${res1.data?.layer}`);
  assert(res1.data?.result === 'bare_ok', `eval_gdscript returned custom result: ${res1.data?.result}`);

  // Verify pixels actually written
  const px10 = await postCommand('get_pixel', { x: 10, y: 10 });
  assert(px10.data?.color === '#0000ffff', `Pixel (10,10) verified as Blue (#0000ffff), got: ${px10.data?.color}`);
  const px11 = await postCommand('get_pixel', { x: 11, y: 11 });
  assert(px11.data?.color === '#ffff00ff', `Pixel (11,11) verified as Yellow (#ffff00ff), got: ${px11.data?.color}`);

  // ── TEST 2: eval_gdscript func run(api, image, project, params) ─────────────
  console.log('\n2. Testing eval_gdscript with full func run(...) form...');
  const res2 = await postCommand('eval_gdscript', {
    code: `func run(api, image: Image, project, params: Dictionary) -> String:
	image.fill_rect(Rect2i(20, 20, 5, 5), Color.MAGENTA)
	return "fill_done"`,
  });
  assert(res2.success === true, 'eval_gdscript func run(...) succeeded');
  assert(res2.data?.result === 'fill_done', `Result returned 'fill_done': ${res2.data?.result}`);
  const px22 = await postCommand('get_pixel', { x: 22, y: 22 });
  assert(px22.data?.color === '#ff00ffff', `Pixel (22,22) verified as Magenta (#ff00ffff), got: ${px22.data?.color}`);

  // ── TEST 3: eval_gdscript Undoability ───────────────────────────────────────
  console.log('\n3. Testing eval_gdscript Undo...');
  const undoRes = await postCommand('undo', {});
  assert(undoRes.success === true, `Undo succeeded: ${undoRes.data?.action}`);
  const px22_undone = await postCommand('get_pixel', { x: 22, y: 22 });
  assert(px22_undone.data?.color !== '#ff00ffff', `Pixel (22,22) reverted after undo, got: ${px22_undone.data?.color}`);

  // ── TEST 4: Gradient shape: "elliptical" ────────────────────────────────────
  console.log('\n4. Testing apply_gradient shape: "elliptical"...');
  await postCommand('create_canvas', { width: 100, height: 50, name: 'GradientTest' });
  const gradEllipse = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 100,
    y2: 50,
    shape: 'elliptical',
    color1: '#ffffff',
    color2: '#000000',
    dither: false,
    blend: false,
  });
  assert(gradEllipse.success === true, 'apply_gradient with shape: "elliptical" succeeded');
  // Center is (50, 25)
  const centerPx = await postCommand('get_pixel', { x: 50, y: 25 });
  // Right edge is (99, 25)
  const rightPx = await postCommand('get_pixel', { x: 99, y: 25 });
  // Top edge is (50, 0)
  const topPx = await postCommand('get_pixel', { x: 50, y: 0 });
  // Off-axis corner is (99, 0)
  const cornerPx = await postCommand('get_pixel', { x: 99, y: 0 });

  console.log(`    Center: ${centerPx.data?.color}, Right edge: ${rightPx.data?.color}, Top edge: ${topPx.data?.color}, Corner: ${cornerPx.data?.color}`);
  assert(centerPx.data?.color === '#ffffffff', 'Center is White (#ffffffff)');
  assert(rightPx.data?.r < 20, `Right edge has faded towards Black, r=${rightPx.data?.r}`);
  assert(topPx.data?.r < 20, `Top edge has faded towards Black, r=${topPx.data?.r}`);
  assert(cornerPx.data?.r === 0, `Corner is Black (#000000ff), r=${cornerPx.data?.r}`);

  // ── TEST 5: Gradient Falloffs: smoothstep & exponential ──────────────────────
  console.log('\n5. Testing apply_gradient falloffs (smoothstep, exponential, feather)...');
  const gradSmooth = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 100,
    y2: 50,
    type: 'linear',
    falloff: 'smoothstep',
    color1: '#ffffff',
    color2: '#000000',
    dither: false,
    blend: false,
  });
  assert(gradSmooth.success === true, 'apply_gradient with falloff: "smoothstep" succeeded');

  const gradExp = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 100,
    y2: 50,
    type: 'linear',
    falloff: 'exponential',
    color1: '#ffffff',
    color2: '#000000',
    dither: false,
    blend: false,
  });
  assert(gradExp.success === true, 'apply_gradient with falloff: "exponential" succeeded');

  const gradFeather = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 100,
    y2: 50,
    type: 'radial',
    falloff: 'feather',
    feather: 0.8,
    color1: '#ffffff',
    color2: '#000000',
    dither: false,
    blend: false,
  });
  assert(gradFeather.success === true, 'apply_gradient with falloff: "feather" succeeded');

  // ── TEST 6: Parameter Unification: data vs flat_pixels ──────────────────────
  console.log('\n6. Testing parameter aliases in draw_pixels and draw_pixels_fast...');
  // draw_pixels with "data"
  const drawPixData = await postCommand('draw_pixels', {
    data: [5, 5, '#ff0000', 6, 6, '#00ff00'],
  });
  assert(drawPixData.success === true, `draw_pixels accepted 'data' parameter: drawn ${drawPixData.data?.drawn}`);

  // draw_pixels_fast with "flat_pixels"
  const drawFastFlat = await postCommand('draw_pixels_fast', {
    flat_pixels: [7, 7, '#0000ff', 8, 8, '#ffffff'],
  });
  assert(drawFastFlat.success === true, `draw_pixels_fast accepted 'flat_pixels' parameter: drawn ${drawFastFlat.data?.drawn}`);

  // ── TEST 7: draw_pixels_fast 10,000 pixels throughput ───────────────────────
  console.log('\n7. Testing draw_pixels_fast with 10,000 pixels batch...');
  const largeBatch = [];
  for (let i = 0; i < 100; i++) {
    for (let j = 0; j < 100; j++) {
      largeBatch.push(i, j, '#abcdef');
    }
  }
  const tStart = Date.now();
  const fastBatchRes = await postCommand('draw_pixels_fast', { data: largeBatch });
  const duration = Date.now() - tStart;
  assert(fastBatchRes.success === true, `draw_pixels_fast 10,000 pixels completed in ${duration}ms (drawn: ${fastBatchRes.data?.drawn})`);

  // ── TEST 8: apply_glow Layer Name / Handle resolution ───────────────────────
  console.log('\n8. Testing apply_glow with layer handles...');
  const glowLayerRes = await postCommand('add_layer', { name: 'LanternLayer' });
  const layerId = glowLayerRes.data?.layer_id;
  assert(layerId !== undefined, `Created layer with stable layer_id: ${layerId}`);

  // Draw an emitter pixel on that layer
  await postCommand('draw_pixel', { x: 50, y: 50, color: '#ffb703', layer: 'LanternLayer' });

  // Apply glow targeting by layer name
  const glowNameRes = await postCommand('apply_glow', {
    layer: 'LanternLayer',
    radius: 3,
    color: '#ffb703',
  });
  assert(glowNameRes.success === true, 'apply_glow succeeded using layer name');

  // Apply glow targeting by layer_id
  const glowIdRes = await postCommand('apply_glow', {
    layer: layerId,
    radius: 3,
    color: '#ffb703',
  });
  assert(glowIdRes.success === true, 'apply_glow succeeded using stable layer_id');

  console.log(`\n========================================`);
  console.log(`Results: ${passed} PASSED, ${failed} FAILED`);
  console.log(`========================================\n`);

  if (failed > 0) process.exit(1);
}

run().catch((e) => {
  console.error('Fatal error running tests:', e);
  process.exit(1);
});
