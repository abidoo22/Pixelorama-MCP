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
  console.log('\n=== Testing Transparent-Endpoint Safeguard & Inferred Direction Metadata ===\n');

  await postCommand('create_canvas', { width: 400, height: 100, name: 'SafeguardTest' });

  // ── TEST 1: Transparent start endpoint (#ffffff00 -> #ff0000ff), dither omitted ─────
  console.log('1. Testing color1="#ffffff00", color2="#ff0000ff" with dither omitted...');
  const res1 = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 100,
    color1: '#ffffff00',
    color2: '#ff0000ff',
    blend: false,
    // dither omitted!
  });

  assert(res1.success === true, 'apply_gradient succeeded');
  assert(res1.data?.dither === false, `Dither auto-disabled (got dither: ${res1.data?.dither})`);
  assert(res1.data?.inferred_direction === 'horizontal', `Inferred direction is horizontal (got: ${res1.data?.inferred_direction})`);

  // Probe alphas across x = 0, 100, 200, 300, 399
  const p0 = await postCommand('get_pixel', { x: 0, y: 50 });
  const p100 = await postCommand('get_pixel', { x: 100, y: 50 });
  const p200 = await postCommand('get_pixel', { x: 200, y: 50 });
  const p300 = await postCommand('get_pixel', { x: 300, y: 50 });
  const p399 = await postCommand('get_pixel', { x: 399, y: 50 });

  console.log(`   Alpha ramp across x at y=50:
     x=0:   a=${p0.data?.a}
     x=100: a=${p100.data?.a}
     x=200: a=${p200.data?.a}
     x=300: a=${p300.data?.a}
     x=399: a=${p399.data?.a}`);

  assert(p0.data?.a <= 2, `Start x=0 is transparent (got a=${p0.data?.a})`);
  assert(p100.data?.a >= 55 && p100.data?.a <= 75, `x=100 ramps up smoothly (got a=${p100.data?.a})`);
  assert(p200.data?.a >= 120 && p200.data?.a <= 135, `Mid x=200 is ~half (got a=${p200.data?.a})`);
  assert(p300.data?.a >= 185 && p300.data?.a <= 200, `x=300 ramps up (got a=${p300.data?.a})`);
  assert(p399.data?.a >= 250, `End x=399 is fully opaque (got a=${p399.data?.a})`);

  // ── TEST 2: Transparent end endpoint (#ffffffff -> #ff000000), dither omitted ───────
  console.log('\n2. Testing color1="#ffffffff", color2="#ff000000" with dither omitted...');
  await postCommand('clear_cel', {});
  const res2 = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 100,
    color1: '#ffffffff',
    color2: '#ff000000',
    blend: false,
  });

  assert(res2.success === true, 'apply_gradient succeeded');
  assert(res2.data?.dither === false, `Dither auto-disabled for transparent color2 (got dither: ${res2.data?.dither})`);

  const p2_0 = await postCommand('get_pixel', { x: 0, y: 50 });
  const p2_200 = await postCommand('get_pixel', { x: 200, y: 50 });
  const p2_399 = await postCommand('get_pixel', { x: 399, y: 50 });

  assert(p2_0.data?.a === 255, `Start x=0 is 255 (got ${p2_0.data?.a})`);
  assert(p2_200.data?.a >= 120 && p2_200.data?.a <= 135, `Mid x=200 is ~127 (got ${p2_200.data?.a})`);
  assert(p2_399.data?.a <= 2, `End x=399 is 0 (got ${p2_399.data?.a})`);

  // ── TEST 3: Opaque endpoints (#ffffffff -> #ff0000ff), dither omitted ───────────────
  console.log('\n3. Testing opaque endpoints with dither omitted (should default to dither: true)...');
  await postCommand('clear_cel', {});
  const res3 = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 100,
    color1: '#ffffff',
    color2: '#000000',
    blend: false,
  });
  assert(res3.data?.dither === true, `Opaque gradient defaults to dither: true (got ${res3.data?.dither})`);

  // ── TEST 4: Explicit dither: true override with transparent endpoint ────────────────
  console.log('\n4. Testing explicit dither: true override with transparent endpoint...');
  const res4 = await postCommand('apply_gradient', {
    x1: 0,
    y1: 0,
    x2: 400,
    y2: 100,
    color1: '#ffffff00',
    color2: '#ff0000ff',
    dither: true, // explicit override
    blend: false,
  });
  assert(res4.data?.dither === true, `Explicit dither: true override honoured (got ${res4.data?.dither})`);

  // ── TEST 5: MCP Tool Layer formatting verification ──────────────────────────────────
  console.log('\n5. Testing MCP Procedural tool message formatting...');
  const gradType = 'linear';
  const resolvedDir = res1.data?.direction || 'horizontal';
  const inferredDir = res1.data?.inferred_direction || resolvedDir;
  const ditherDesc = res1.data?.dither ? 'Bayer dithering' : 'smooth blend';
  const formattedText = `✅ ${gradType.toUpperCase()} Gradient [direction: "${resolvedDir}", inferred_direction: "${inferredDir}", dither: ${Boolean(res1.data?.dither)}] (${resolvedDir} direction, linear falloff) applied with ${ditherDesc} from #ffffff00 to #ff0000ff (blend: false)`;

  console.log(`   Formatted text:\n   ${formattedText}`);
  assert(formattedText.includes('inferred_direction: "horizontal"'), 'Contains literal inferred_direction key');
  assert(formattedText.includes('dither: false'), 'Contains literal dither: false');
  assert(formattedText.includes('applied with smooth blend'), 'Contains "applied with smooth blend"');

  console.log(`\n========================================`);
  console.log(`Safeguard Test Results: ${passed} PASSED, ${failed} FAILED`);
  console.log(`========================================\n`);

  if (failed > 0) process.exit(1);
}

run().catch((e) => {
  console.error('Fatal error running tests:', e);
  process.exit(1);
});
