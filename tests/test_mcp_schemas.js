import { fastFlatArraySchema, MAX_FLAT_PIXEL_ELEMENTS, layerHandleSchema, framesArraySchema } from '../mcp-server/dist/utils/schema_helpers.js';
import { createServer } from '../mcp-server/dist/server.js';

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

console.log('\n=== Testing MCP Server Schema Protections ===\n');

// 1. Safe array under limit passes
const normalArray = [1, 2, '#ffffff', 3, 4, '#000000'];
const res1 = fastFlatArraySchema.safeParse(normalArray);
assert(res1.success === true, 'fastFlatArraySchema accepts valid array');

// 2. Giant array above 300k limit is rejected cleanly without crashing or allocating AST
console.log('Testing 300,001 elements rejection...');
const oversizedArray = new Array(MAX_FLAT_PIXEL_ELEMENTS + 1).fill(0);
const res2 = fastFlatArraySchema.safeParse(oversizedArray);
assert(res2.success === false, 'fastFlatArraySchema cleanly rejected oversized array');
assert(
  res2.error?.issues[0]?.message.includes('exceeds the maximum safe batch limit'),
  `Rejected with descriptive error message: "${res2.error?.issues[0]?.message}"`
);

// 3. layerHandleSchema accepts numbers, names, and UUIDs
assert(layerHandleSchema.safeParse(0).success === true, 'layerHandleSchema accepts 0');
assert(layerHandleSchema.safeParse('Sky').success === true, 'layerHandleSchema accepts "Sky"');
assert(layerHandleSchema.safeParse('layer_abc_123').success === true, 'layerHandleSchema accepts "layer_abc_123"');

// 4. framesArraySchema accepts arrays and JSON-stringified arrays
assert(framesArraySchema.safeParse([0, 1, 2]).success === true, 'framesArraySchema accepts [0, 1, 2]');
const parsedStrFrames = framesArraySchema.safeParse('[1, 3, 5]');
assert(
  parsedStrFrames.success === true && JSON.stringify(parsedStrFrames.data) === '[1,3,5]',
  'framesArraySchema parses JSON-stringified "[1, 3, 5]"'
);
assert(framesArraySchema.safeParse([]).success === false, 'framesArraySchema rejects empty array');

// 5. Verify unified layerHandleSchema across all tools that previously required integer indices
const server = createServer();
const toolsMap = server._registeredTools || {};
const unifiedLayerTools = [
  'apply_outline',
  'apply_dithering',
  'mirror_layer',
  'apply_drop_shadow',
  'validate_sprite',
  'import_spritesheet',
  'clean_isolated_pixels',
  'remap_to_palette',
  'get_layer_markers',
];
for (const toolName of unifiedLayerTools) {
  const t = toolsMap[toolName];
  assert(Boolean(t), `Tool '${toolName}' is registered`);
  if (t && t.inputSchema) {
    const layerField = t.inputSchema.shape?.layer;
    assert(
      layerField && layerField.safeParse('anchors').success === true && layerField.safeParse(0).success === true,
      `Tool '${toolName}' accepts both string layer name and integer index`
    );
  }
}
assert(Boolean(toolsMap['batch_commands']), `Tool 'batch_commands' is registered`);
const grpAbove = toolsMap['create_layer_group']?.inputSchema?.shape?.above_layer;
assert(
  grpAbove && grpAbove.safeParse('Foreground').success === true && grpAbove.safeParse(0).success === true,
  `Tool 'create_layer_group' accepts string above_layer name and integer index`
);

console.log(`\n========================================`);
console.log(`Schema Test Results: ${passed} PASSED, ${failed} FAILED`);
console.log(`========================================\n`);

if (failed > 0) process.exit(1);
