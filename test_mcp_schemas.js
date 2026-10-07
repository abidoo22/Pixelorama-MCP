import { fastFlatArraySchema, MAX_FLAT_PIXEL_ELEMENTS, layerHandleSchema } from './mcp-server/dist/utils/schema_helpers.js';

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

console.log(`\n========================================`);
console.log(`Schema Test Results: ${passed} PASSED, ${failed} FAILED`);
console.log(`========================================\n`);

if (failed > 0) process.exit(1);
