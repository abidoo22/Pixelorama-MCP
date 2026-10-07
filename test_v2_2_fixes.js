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
  console.log('\n=== Testing Pixelorama MCP v2.2 Gradient Direction & Dither Patches ===\n');

  // Setup canvas 500x500
  await postCommand('create_canvas', { width: 500, height: 500, name: 'PatchTestV2_2' });

  // ── TEST 1: Auto-direction on wide region (400x80) ──────────────────────────
  console.log('1. Testing linear gradient auto-direction on wide region (400x80)...');
  const resWide = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 80,
    type: 'linear',
    // direction omitted! Should auto-infer "horizontal" because 400 > 80
    color1: '#ffffff',
    color2: '#ffffff00',
    dither: false,
    blend: false,
  });
  assert(resWide.success === true, 'apply_gradient on wide region succeeded');
  assert(resWide.data?.direction === 'horizontal', `Inferred direction is horizontal (got: ${resWide.data?.direction})`);
  assert(resWide.data?.inferred_direction === 'horizontal', 'inferred_direction flag reports horizontal');

  // Verify horizontal ramp along y = 40
  const pW0 = await postCommand('get_pixel', { x: 0, y: 40 });
  const pW100 = await postCommand('get_pixel', { x: 100, y: 40 });
  const pW200 = await postCommand('get_pixel', { x: 200, y: 40 });
  const pW300 = await postCommand('get_pixel', { x: 300, y: 40 });
  const pW399 = await postCommand('get_pixel', { x: 399, y: 40 });

  console.log(`   Wide region row y=40: x=0: a=${pW0.data?.a}, x=100: a=${pW100.data?.a}, x=200: a=${pW200.data?.a}, x=300: a=${pW300.data?.a}, x=399: a=${pW399.data?.a}`);
  assert(pW0.data?.a === 255, 'Start x=0 is full alpha (255)');
  assert(pW100.data?.a > 175 && pW100.data?.a < 205, `x=100 ramps down (~191, got ${pW100.data?.a})`);
  assert(pW200.data?.a > 115 && pW200.data?.a < 140, `x=200 mid ramp (~127, got ${pW200.data?.a})`);
  assert(pW300.data?.a > 50 && pW300.data?.a < 75, `x=300 ramps down (~63, got ${pW300.data?.a})`);
  assert(pW399.data?.a <= 5, `End x=399 is ~0 (got ${pW399.data?.a})`);

  // ── TEST 2: Auto-direction on tall region (80x400) ──────────────────────────
  console.log('\n2. Testing linear gradient auto-direction on tall region (80x400)...');
  await postCommand('clear_cel', {});
  const resTall = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 80,
    y2: 400,
    type: 'linear',
    // direction omitted! Should auto-infer "vertical" because 80 < 400
    color1: '#ffffff',
    color2: '#ffffff00',
    dither: false,
    blend: false,
  });
  assert(resTall.success === true, 'apply_gradient on tall region succeeded');
  assert(resTall.data?.direction === 'vertical', `Inferred direction is vertical (got: ${resTall.data?.direction})`);

  // Verify vertical ramp along x = 40
  const pT0 = await postCommand('get_pixel', { x: 40, y: 0 });
  const pT100 = await postCommand('get_pixel', { x: 40, y: 100 });
  const pT200 = await postCommand('get_pixel', { x: 40, y: 200 });
  const pT300 = await postCommand('get_pixel', { x: 40, y: 300 });
  const pT399 = await postCommand('get_pixel', { x: 40, y: 399 });

  console.log(`   Tall region col x=40: y=0: a=${pT0.data?.a}, y=100: a=${pT100.data?.a}, y=200: a=${pT200.data?.a}, y=300: a=${pT300.data?.a}, y=399: a=${pT399.data?.a}`);
  assert(pT0.data?.a === 255, 'Start y=0 is full alpha (255)');
  assert(pT200.data?.a > 115 && pT200.data?.a < 140, `Mid y=200 is ~half alpha (got ${pT200.data?.a})`);
  assert(pT399.data?.a <= 5, `End y=399 is ~0 (got ${pT399.data?.a})`);

  // ── TEST 3: Explicit direction override ─────────────────────────────────────
  console.log('\n3. Testing explicit direction override on wide region...');
  await postCommand('clear_cel', {});
  const resOverride = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 80,
    type: 'linear',
    direction: 'vertical', // explicitly requested vertical on wide region
    color1: '#ffffff',
    color2: '#ffffff00',
    dither: false,
    blend: false,
  });
  assert(resOverride.success === true, 'apply_gradient with explicit vertical override succeeded');
  assert(resOverride.data?.direction === 'vertical', 'Explicit direction "vertical" respected');

  // Verify y=40 is ~127 across entire row
  const pO0 = await postCommand('get_pixel', { x: 0, y: 40 });
  const pO200 = await postCommand('get_pixel', { x: 200, y: 40 });
  const pO399 = await postCommand('get_pixel', { x: 399, y: 40 });
  assert(
    Math.abs(pO0.data?.a - pO200.data?.a) <= 2 && Math.abs(pO200.data?.a - pO399.data?.a) <= 2,
    `Vertical gradient is uniform across row y=40 (x=0: ${pO0.data?.a}, x=200: ${pO200.data?.a}, x=399: ${pO399.data?.a})`
  );

  // ── TEST 4: Alpha parameter scaling ─────────────────────────────────────────
  console.log('\n4. Testing alpha parameter scaling on gradient...');
  await postCommand('clear_cel', {});
  const resAlpha = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 100,
    y2: 100,
    direction: 'horizontal',
    color1: '#ffffff',
    color2: '#ffffff',
    alpha: 0.5,
    dither: false,
    blend: false,
  });
  assert(resAlpha.success === true, 'apply_gradient with alpha: 0.5 succeeded');
  assert(resAlpha.data?.alpha === 0.5, 'Reported alpha is 0.5');
  const pAlpha = await postCommand('get_pixel', { x: 50, y: 50 });
  assert(
    pAlpha.data?.a >= 126 && pAlpha.data?.a <= 129,
    `Pixel alpha scaled to ~128 (got a=${pAlpha.data?.a})`
  );

  // ── TEST 5: Bayer Ordered Dithering 4x4 spatial block verification ──────────
  console.log('\n5. Testing Bayer ordered dithering 4x4 spatial averages across 400px ramp...');
  await postCommand('clear_cel', {});
  const resDither = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 80,
    direction: 'horizontal',
    color1: '#ffffff',
    color2: '#ffffff00',
    dither: true,
    blend: true,
    feather: 0.0,
  });
  assert(resDither.success === true, 'apply_gradient with dither: true, blend: true succeeded');

  // Measure 4x4 block averages at x=0, 100, 200, 300, 396
  async function get4x4Average(bx, by) {
    let total = 0;
    for (let dy = 0; dy < 4; dy++) {
      for (let dx = 0; dx < 4; dx++) {
        const pix = await postCommand('get_pixel', { x: bx + dx, y: by + dy });
        total += (pix.data?.a || 0);
      }
    }
    return total / 16.0;
  }

  const avg0 = await get4x4Average(0, 20);
  const avg100 = await get4x4Average(100, 20);
  const avg200 = await get4x4Average(200, 20);
  const avg300 = await get4x4Average(300, 20);
  const avg396 = await get4x4Average(396, 20);

  console.log(`   4x4 block average alphas:
     x=0:   avg=${avg0.toFixed(1)} (expected 255.0)
     x=100: avg=${avg100.toFixed(1)} (expected ~191.2)
     x=200: avg=${avg200.toFixed(1)} (expected ~127.5)
     x=300: avg=${avg300.toFixed(1)} (expected ~63.8)
     x=396: avg=${avg396.toFixed(1)} (expected 0.0)`);

  assert(avg0 === 255.0, `x=0 4x4 block is 100% solid (got ${avg0})`);
  assert(avg100 >= 185 && avg100 <= 195, `x=100 4x4 block is ~75% coverage (got ${avg100})`);
  assert(avg200 >= 120 && avg200 <= 135, `x=200 4x4 block is ~50% coverage (got ${avg200})`);
  assert(avg300 >= 58 && avg300 <= 70, `x=300 4x4 block is ~25% coverage (got ${avg300})`);
  assert(avg396 === 0.0, `x=396 4x4 block is 0% coverage (got ${avg396})`);

  // ── TEST 6: Dither with feather + blend interaction check ───────────────────
  console.log('\n6. Testing dither: true + blend: true + feather: 0.3...');
  await postCommand('clear_cel', {});
  const resFeatherDither = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 80,
    direction: 'horizontal',
    color1: '#ffffff',
    color2: '#ffffff00',
    dither: true,
    blend: true,
    feather: 0.3,
  });
  assert(resFeatherDither.success === true, 'apply_gradient with feather: 0.3, dither: true, blend: true succeeded');
  const avgFeatherMid = await get4x4Average(200, 20);
  console.log(`   Center x=200 4x4 block average with feather: 0.3: ${avgFeatherMid.toFixed(1)}`);
  assert(
    avgFeatherMid >= 120 && avgFeatherMid <= 135,
    `Center x=200 4x4 block is ~50% coverage with feather: 0.3 (got ${avgFeatherMid})`
  );

  console.log(`\n========================================`);
  console.log(`v2.2 Patch Test Results: ${passed} PASSED, ${failed} FAILED`);
  console.log(`========================================\n`);

  if (failed > 0) process.exit(1);
}

run().catch((e) => {
  console.error('Fatal error running tests:', e);
  process.exit(1);
});
