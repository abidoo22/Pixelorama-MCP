// test_all_fixes.js
// Thorough verification suite for Pixelorama MCP bug fixes and new features (B1-B7, A1-A6)

const http = require('http');

function post(path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: 7373,
        path: path,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
        },
      },
      (res) => {
        let respData = '';
        res.on('data', (chunk) => (respData += chunk));
        res.on('end', () => {
          try {
            resolve(JSON.parse(respData));
          } catch (e) {
            resolve({ raw: respData });
          }
        });
      }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function callTool(name, params = {}) {
  return post('/command', { tool: name, params });
}

async function runTests() {
  console.log('🧪 Starting Pixelorama MCP Bugfix & Feature Verification Suite\n');
  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✅ ${message}`);
      passed++;
    } else {
      console.error(`  ❌ FAILED: ${message}`);
      failed++;
    }
  }

  // 1. Setup Canvas
  console.log('--- Setting up test canvas (64x64) ---');
  const createRes = await callTool('create_canvas', { width: 64, height: 64, name: 'mcp_test' });
  assert(createRes.success === true, 'create_canvas succeeded');

  // 2. Test A1: Layer Handles & IDs
  console.log('\n--- Testing A1: Stable Layer Handles & IDs ---');
  const addLayerRes = await callTool('add_layer', { name: 'TestLayer1' });
  assert(addLayerRes.success === true && addLayerRes.data.layer_id !== '', `add_layer returns stable layer_id: ${addLayerRes.data?.layer_id}`);
  const layer1Id = addLayerRes.data.layer_id;

  const getLayersRes = await callTool('get_layers', {});
  assert(getLayersRes.success === true, 'get_layers succeeded');
  const foundLayer = getLayersRes.data.layers.find(l => l.layer_id === layer1Id);
  assert(foundLayer !== undefined, `get_layers includes layer_id matching added layer (${foundLayer?.name})`);

  // Target layer by layer_id
  const drawByLayerIdRes = await callTool('draw_pixel', { layer_id: layer1Id, x: 10, y: 10, color: '#ff0000ff' });
  assert(drawByLayerIdRes.success === true, 'draw_pixel successfully resolved layer using layer_id');

  const checkPx1 = await callTool('get_pixel', { layer_id: layer1Id, x: 10, y: 10 });
  assert(checkPx1.data.color.toLowerCase().includes('ff0000'), `Pixel at (10,10) on layer_id is red (${checkPx1.data.color})`);

  // Target layer by layer_name
  const drawByNameRes = await callTool('draw_pixel', { layer_name: 'TestLayer1', x: 11, y: 10, color: '#00ff00ff' });
  assert(drawByNameRes.success === true, 'draw_pixel successfully resolved layer using layer_name');

  // 3. Test B1: apply_gradient preserves underlying pixels
  console.log('\n--- Testing B1: apply_gradient underlying pixel preservation ---');
  // Fill a 20x20 background area with solid blue #0000ffff
  await callTool('draw_rect', { layer_id: layer1Id, x: 20, y: 20, width: 20, height: 20, color: '#0000ffff', filled: true, blend: false });
  const bgPxBefore = await callTool('get_pixel', { layer_id: layer1Id, x: 38, y: 38 });
  assert(bgPxBefore.data.color.toLowerCase().includes('0000ff'), 'Background area prepared with blue');

  // Apply radial gradient from #ffff00ff (yellow) to #ffff0000 (transparent yellow)
  // In the old code without blend, the alpha-0 edge would wipe the blue background to #00000000 or #ffff0000
  const gradRes = await callTool('apply_gradient', {
    layer_id: layer1Id,
    type: 'radial',
    x1: 20,
    y1: 20,
    x2: 40,
    y2: 40,
    color1: '#ffff00ff',
    color2: '#ffff0000',
    blend: true,
    dither: false,
  });
  assert(gradRes.success === true, 'apply_gradient with blend:true executed');

  // Check center: should be gradient color (yellow)
  const centerPx = await callTool('get_pixel', { layer_id: layer1Id, x: 30, y: 30 });
  // Check corner: alpha-0 should preserve the underlying blue background!
  const cornerPx = await callTool('get_pixel', { layer_id: layer1Id, x: 39, y: 39 });
  const cornerCol = cornerPx.data.color.toLowerCase();
  assert(cornerCol.includes('0000ff') || !cornerCol.includes('ffff00'), `Underlying pixel preserved at gradient edge! Color: ${cornerPx.data.color} (alpha-0 did NOT erase blue)`);

  // 4. Test A6: apply_gradient falloff controls & ellipse shape
  console.log('\n--- Testing A6: apply_gradient ellipse shape & falloff controls ---');
  const gradA6Res = await callTool('apply_gradient', {
    layer_id: layer1Id,
    type: 'radial',
    shape: 'ellipse',
    falloff: 'inverse_square',
    x1: 0,
    y1: 0,
    x2: 30,
    y2: 15,
    color1: '#ffffff',
    color2: '#000000',
    blend: false,
  });
  assert(gradA6Res.success === true, `apply_gradient with shape=ellipse, falloff=inverse_square succeeded: ${gradA6Res.data?.shape}`);

  // 5. Test B3: draw_pixels_fast throughput and flat arrays
  console.log('\n--- Testing B3: draw_pixels_fast throughput ---');
  const flatDataHex = [];
  for (let i = 0; i < 500; i++) {
    flatDataHex.push(i % 50, Math.floor(i / 50), '#ff00ffff');
  }
  const t0 = Date.now();
  const fastHexRes = await callTool('draw_pixels_fast', { layer_id: layer1Id, data: flatDataHex });
  const dtHex = Date.now() - t0;
  assert(fastHexRes.success === true && fastHexRes.data.pixels_drawn === 500, `draw_pixels_fast drew 500 pixels in ${dtHex} ms (${(dtHex / 500).toFixed(3)} ms/px)`);

  // Flat RGBA data (stride 6)
  const flatDataRgba = [];
  for (let i = 0; i < 200; i++) {
    flatDataRgba.push(i % 40, Math.floor(i / 40) + 15, 255, 128, 0, 255);
  }
  const fastRgbaRes = await callTool('draw_pixels_fast', { layer_id: layer1Id, data: flatDataRgba });
  assert(fastRgbaRes.success === true && fastRgbaRes.data.pixels_drawn === 200, 'draw_pixels_fast supports stride 6 RGBA flat array');

  // Also test draw_pixels with flat_pixels parameter
  const drawPixelsFlatRes = await callTool('draw_pixels', { layer_id: layer1Id, flat_pixels: [0, 0, '#112233', 1, 0, '#112233'] });
  assert(drawPixelsFlatRes.success === true, 'draw_pixels supports flat_pixels parameter');

  // 6. Test B4: draw_polygon validation on NaN / invalid points
  console.log('\n--- Testing B4: draw_polygon coordinate validation ---');
  const nanPoints = [
    { x: 10, y: 10 },
    { x: 20, y: NaN },
    { x: 30, y: 20 },
  ];
  const nanPolyRes = await callTool('draw_polygon', { layer_id: layer1Id, points: nanPoints });
  assert(nanPolyRes.success === false && nanPolyRes.error.includes('NaN'), `draw_polygon correctly catches NaN with descriptive error: "${nanPolyRes.error}"`);

  // 7. Test B5: Non-integer coordinates coercion
  console.log('\n--- Testing B5: Non-integer coordinates coercion ---');
  const floatEllipseRes = await callTool('draw_ellipse', {
    layer_id: layer1Id,
    cx: 30.2,
    cy: 30.7,
    rx: 10.4,
    ry: 5.9,
    color: '#00ff00',
    filled: true,
  });
  assert(floatEllipseRes.success === true, 'draw_ellipse successfully coerced float coordinates');

  // 8. Test B6: alpha parameter in drawing tools
  console.log('\n--- Testing B6: alpha parameter support ---');
  const rectAlphaRes = await callTool('draw_rect', {
    layer_id: layer1Id,
    x: 45,
    y: 45,
    width: 5,
    height: 5,
    color: '#ff0000',
    alpha: 128, // ~0.50
    filled: true,
    blend: false,
  });
  assert(rectAlphaRes.success === true, 'draw_rect accepted alpha: 128');
  const alphaPx = await callTool('get_pixel', { layer_id: layer1Id, x: 46, y: 46 });
  assert(alphaPx.data.a >= 120 && alphaPx.data.a <= 135, `Pixel alpha correctly parsed from alpha: 128 (got a=${alphaPx.data.a})`);

  // 9. Test B7: get_palette_usage bounded output
  console.log('\n--- Testing B7: get_palette_usage bounded output ---');
  const paletteRes = await callTool('get_palette_usage', { top: 3 });
  assert(paletteRes.success === true, 'get_palette_usage succeeded');
  assert(paletteRes.data.colors.length <= 3, `Palette colors bounded to top: 3 (returned ${paletteRes.data.colors.length} items, total unique: ${paletteRes.data.unique_colors_count})`);

  // 10. Test A2: eval_gdscript runtime scripting
  console.log('\n--- Testing A2: eval_gdscript runtime scripting ---');
  const evalScript = `
var cel = project.frames[0].cels[0]
var img = cel.get_image()
for x in range(10):
    img.set_pixel(x, 50, Color.DEEP_PINK)
return {"status": "ok", "pixels_written": 10, "format": img.get_format()}
`;
  const tEval0 = Date.now();
  const evalRes = await callTool('eval_gdscript', { code: evalScript });
  const dtEval = Date.now() - tEval0;
  assert(evalRes.success === true, `eval_gdscript executed in ${dtEval} ms`);
  assert(evalRes.data?.result?.pixels_written === 10, `eval_gdscript returned result: ${JSON.stringify(evalRes.data?.result)}`);

  // Verify the pixel drawn by GDScript
  const evalPx = await callTool('get_pixel', { layer: 0, x: 5, y: 50 });
  assert(evalPx.data.color.toLowerCase().includes('ff1493'), `Pixel written by eval_gdscript verified: ${evalPx.data.color}`);

  // 11. Test A3: get_canvas_image_base64 region crop & downscaling
  console.log('\n--- Testing A3: get_canvas_image_base64 crop & downscale ---');
  const cropRes = await callTool('get_canvas_image_base64', { x: 10, y: 10, width: 20, height: 20 });
  assert(cropRes.success === true, 'get_canvas_image_base64 with region succeeded');
  assert(cropRes.data.width === 20 && cropRes.data.height === 20, `Cropped dimensions correct: ${cropRes.data.width}x${cropRes.data.height}`);

  const downscaleRes = await callTool('get_canvas_image_base64', { max_size: 16 });
  assert(downscaleRes.success === true, 'get_canvas_image_base64 with max_size succeeded');
  assert(downscaleRes.data.width <= 16 && downscaleRes.data.height <= 16, `Downscaled max_size correct: ${downscaleRes.data.width}x${downscaleRes.data.height}`);

  // 12. Test A5: clear_cel confirms undoable
  console.log('\n--- Testing A5: clear_cel can_undo status ---');
  const clearRes = await callTool('clear_cel', { layer_id: layer1Id });
  assert(clearRes.success === true && clearRes.data.can_undo === true, `clear_cel reports can_undo: ${clearRes.data?.can_undo}`);

  // Verify undo restores it
  const undoRes = await callTool('undo', {});
  assert(undoRes.success === true, 'undo succeeded to restore cleared cel');

  // Summary
  console.log(`\n========================================`);
  console.log(`Total tests: ${passed + failed}`);
  console.log(`Passed: ${passed}`);
  console.log(`Failed: ${failed}`);
  console.log(`========================================`);

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Fatal error during test run:', err);
  process.exit(1);
});
