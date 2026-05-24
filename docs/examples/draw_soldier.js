/**
 * draw_soldier.js
 * Draws a detailed military soldier character on a 96x128 Pixelorama canvas.
 * Left-facing stance, dark skin, tactical vest, camo pants, military boots.
 * No background — transparent canvas.
 * 
 * Run: node draw_soldier.js
 * Requires: Pixelorama open with pix-MCP bridge plugin running on port 7373
 */

const BRIDGE_URL = "http://127.0.0.1:7373";
const BATCH_SIZE = 5000;

const W = 96;
const H = 128;

// ─── COLORS ───────────────────────────────────────────────────────────────────
const C = {
  // Skin
  skin:           "#8B5E3C",
  skin_light:     "#A0703F",
  skin_shadow:    "#6B4528",
  skin_dark:      "#4E3020",

  // Face
  eye_white:      "#E8D9C0",
  eye:            "#1A0E05",
  brow:           "#2A1A08",
  lip:            "#6B3A22",
  jaw_shadow:     "#4A2E18",

  // Hair & headband
  hair:           "#1A1208",
  headband:       "#2D3A1A",
  headband_hi:    "#3D4F26",
  headband_dark:  "#1A2210",
  bandana_tail:   "#2D3A1A",

  // T-shirt (dark olive/charcoal)
  shirt:          "#2E3028",
  shirt_light:    "#3A3D30",
  shirt_shadow:   "#1E2018",

  // Tactical vest
  vest:           "#3A4A28",
  vest_light:     "#4A5E35",
  vest_shadow:    "#28361A",
  vest_dark:      "#1C2612",
  pouch:          "#2A3418",
  pouch_light:    "#384520",
  pouch_strap:    "#1E2810",

  // Belt
  belt:           "#2A2218",
  belt_buckle:    "#8A7A50",
  belt_buckle_hi: "#C0A860",

  // Camo pants — base + camo blobs
  pants_base:     "#4A5230",
  pants_light:    "#5A6240",
  pants_shadow:   "#323A20",
  camo_dark:      "#2A3018",
  camo_mid:       "#3A4528",
  camo_tan:       "#6A6040",

  // Boots
  boot:           "#2A2218",
  boot_light:     "#3A3228",
  boot_shadow:    "#1A1510",
  boot_sole:      "#1A1208",

  // Outline
  outline:        "#0A0805",

  // Muscle definition
  muscle_hi:      "#9A6A40",
  muscle_shadow:  "#5A3820",
};

// ─── HELPERS ──────────────────────────────────────────────────────────────────
async function cmd(tool, params = {}) {
  const res = await fetch(`${BRIDGE_URL}/command`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool, params }),
  });
  const data = await res.json();
  if (!data.success) console.error(`FAILED [${tool}]:`, data.error);
  return data;
}

async function drawPixelsBatched(pixels) {
  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    const batch = pixels.slice(i, i + BATCH_SIZE);
    await cmd("draw_pixels", { pixels: batch });
    process.stdout.write(`  ${i + batch.length}/${pixels.length} pixels\r`);
  }
  console.log();
}

// Grid: null = transparent
const grid = new Array(W * H).fill(null);

function px(x, y, color) {
  if (x < 0 || x >= W || y < 0 || y >= H) return;
  grid[y * W + x] = color;
}

function rect(x, y, w, h, color) {
  for (let dy = 0; dy < h; dy++)
    for (let dx = 0; dx < w; dx++)
      px(x + dx, y + dy, color);
}

function ellipse(cx, cy, rx, ry, color) {
  for (let y = cy - ry; y <= cy + ry; y++)
    for (let x = cx - rx; x <= cx + rx; x++) {
      const dx = (x - cx) / rx;
      const dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1) px(x, y, color);
    }
}

// Shade a rect left-to-right with a gradient of 3 colors
function shadedRect(x, y, w, h, colLeft, colMid, colRight) {
  for (let dy = 0; dy < h; dy++) {
    for (let dx = 0; dx < w; dx++) {
      const t = dx / (w - 1);
      let col;
      if (t < 0.35) col = colLeft;
      else if (t < 0.65) col = colMid;
      else col = colRight;
      px(x + dx, y + dy, col);
    }
  }
}

// Shade top-to-bottom
function shadedRectV(x, y, w, h, colTop, colMid, colBot) {
  for (let dy = 0; dy < h; dy++) {
    for (let dx = 0; dx < w; dx++) {
      const t = dy / (h - 1);
      let col;
      if (t < 0.35) col = colTop;
      else if (t < 0.7) col = colMid;
      else col = colBot;
      px(x + dx, y + dy, col);
    }
  }
}

// Simple pseudo-random seeded noise for camo pattern
function seededRand(x, y, seed = 37) {
  let n = x * 374761393 + y * 1103515245 + seed;
  n = (n ^ (n >> 13)) * 1664525;
  return ((n ^ (n >> 7)) & 0x7fffffff) / 0x7fffffff;
}

// ─── DRAW CHARACTER ───────────────────────────────────────────────────────────

function drawCharacter() {

  // ── BOOTS (y: 106–126) ──────────────────────────────────────────────────────
  // Left boot (character's right, visually left side of sprite)
  shadedRect(28, 106, 16, 16, C.boot_light, C.boot, C.boot_shadow);
  rect(28, 120, 16, 4, C.boot_sole);
  // Toe cap highlight
  rect(28, 106, 4, 6, C.boot_light);
  // Right boot
  shadedRect(50, 106, 16, 16, C.boot_light, C.boot, C.boot_shadow);
  rect(50, 120, 16, 4, C.boot_sole);
  rect(50, 106, 4, 6, C.boot_light);
  // Boot ankle crease
  rect(30, 116, 12, 1, C.boot_shadow);
  rect(52, 116, 12, 1, C.boot_shadow);

  // ── CAMO PANTS (y: 72–108) ──────────────────────────────────────────────────
  // Left leg
  shadedRect(28, 72, 16, 36, C.pants_light, C.pants_base, C.pants_shadow);
  // Right leg
  shadedRect(50, 72, 16, 36, C.pants_light, C.pants_base, C.pants_shadow);
  // Crotch join
  rect(36, 72, 22, 8, C.pants_base);
  rect(40, 76, 14, 6, C.pants_shadow);

  // Camo blobs — pants left leg
  for (let y = 72; y < 108; y++) {
    for (let x = 28; x < 44; x++) {
      if (grid[y * W + x] === null) continue;
      const n = seededRand(x, y, 13);
      const n2 = seededRand(x + 7, y + 3, 29);
      if (n < 0.18) px(x, y, C.camo_dark);
      else if (n < 0.32) px(x, y, C.camo_mid);
      else if (n2 < 0.12) px(x, y, C.camo_tan);
    }
  }
  // Camo blobs — pants right leg
  for (let y = 72; y < 108; y++) {
    for (let x = 50; x < 66; x++) {
      if (grid[y * W + x] === null) continue;
      const n = seededRand(x, y, 41);
      const n2 = seededRand(x + 5, y + 7, 17);
      if (n < 0.18) px(x, y, C.camo_dark);
      else if (n < 0.32) px(x, y, C.camo_mid);
      else if (n2 < 0.12) px(x, y, C.camo_tan);
    }
  }

  // Knee pads
  rect(30, 90, 10, 7, C.camo_dark);
  rect(31, 91, 8, 5, C.camo_mid);
  rect(52, 90, 10, 7, C.camo_dark);
  rect(53, 91, 8, 5, C.camo_mid);

  // Pant leg folds
  rect(29, 100, 14, 1, C.pants_shadow);
  rect(51, 100, 14, 1, C.pants_shadow);
  rect(29, 104, 14, 1, C.pants_shadow);
  rect(51, 104, 14, 1, C.pants_shadow);

  // ── BELT (y: 70–74) ─────────────────────────────────────────────────────────
  rect(28, 70, 38, 4, C.belt);
  // Buckle center
  rect(44, 69, 8, 6, C.belt_buckle);
  rect(45, 70, 6, 4, C.belt_buckle_hi);
  rect(47, 70, 2, 4, C.belt_buckle); // buckle bar

  // ── TORSO / SHIRT (y: 42–72) ────────────────────────────────────────────────
  shadedRect(30, 42, 34, 30, C.shirt_light, C.shirt, C.shirt_shadow);
  // Shirt neck opening (V)
  rect(43, 42, 8, 4, C.shirt_shadow);
  rect(44, 44, 6, 3, C.skin_shadow);

  // ── TACTICAL VEST (y: 40–72) ────────────────────────────────────────────────
  // Main vest body
  shadedRect(30, 40, 34, 32, C.vest_light, C.vest, C.vest_shadow);

  // Vest shoulder straps
  rect(30, 40, 8, 6, C.vest);
  rect(56, 40, 8, 6, C.vest);

  // Center chest zipper line
  rect(46, 40, 2, 30, C.vest_dark);

  // Front pouches — left side of vest (character's right)
  rect(32, 50, 10, 8, C.pouch);
  rect(33, 51, 8, 6, C.pouch_light);
  rect(36, 49, 4, 2, C.pouch_strap); // top strap
  rect(36, 57, 4, 2, C.pouch_strap); // bottom strap

  rect(32, 60, 10, 7, C.pouch);
  rect(33, 61, 8, 5, C.pouch_light);
  rect(36, 59, 4, 2, C.pouch_strap);

  // Front pouches — right side of vest
  rect(52, 50, 10, 8, C.pouch);
  rect(53, 51, 8, 6, C.pouch_light);
  rect(56, 49, 4, 2, C.pouch_strap);
  rect(56, 57, 4, 2, C.pouch_strap);

  rect(52, 60, 10, 7, C.pouch);
  rect(53, 61, 8, 5, C.pouch_light);
  rect(56, 59, 4, 2, C.pouch_strap);

  // Vest bottom edge
  rect(30, 70, 34, 2, C.vest_dark);

  // ── ARMS ─────────────────────────────────────────────────────────────────────
  // LEFT ARM (character's right, hangs naturally, y: 44–80, x: 20–32)
  // Upper arm
  shadedRect(20, 44, 12, 20, C.skin_light, C.skin, C.skin_shadow);
  // Bicep highlight
  rect(21, 46, 5, 8, C.skin_light);
  rect(22, 47, 3, 5, C.muscle_hi);
  // Tricep shadow
  rect(27, 48, 4, 10, C.skin_shadow);

  // Elbow
  ellipse(26, 64, 5, 4, C.skin);
  rect(24, 62, 5, 4, C.skin_light);
  rect(27, 63, 3, 3, C.skin_shadow);

  // Forearm — slightly bent
  shadedRect(18, 65, 10, 16, C.skin_light, C.skin, C.skin_shadow);
  rect(19, 67, 4, 10, C.skin_light);

  // Hand (left)
  ellipse(22, 81, 5, 4, C.skin);
  rect(20, 79, 4, 6, C.skin_light);
  rect(24, 80, 3, 4, C.skin_shadow);
  // Finger lines
  rect(20, 83, 2, 1, C.skin_dark);
  rect(22, 83, 2, 1, C.skin_dark);
  rect(24, 83, 2, 1, C.skin_dark);

  // Tattoo on left forearm (tribal lines)
  rect(19, 70, 1, 6, C.skin_dark);
  rect(21, 68, 1, 4, C.skin_dark);
  rect(23, 71, 1, 3, C.skin_dark);
  rect(20, 74, 3, 1, C.skin_dark);
  rect(21, 72, 2, 1, C.skin_dark);

  // RIGHT ARM (character's left, slightly raised, y: 44–76, x: 62–74)
  // Upper arm — sleeve covered by vest shoulder, visible from mid
  shadedRect(62, 52, 12, 16, C.skin_light, C.skin, C.skin_shadow);
  rect(63, 54, 5, 7, C.skin_light);
  rect(67, 55, 4, 8, C.skin_shadow);

  // Elbow
  ellipse(68, 68, 4, 4, C.skin);
  rect(66, 66, 4, 4, C.skin_light);

  // Forearm
  shadedRect(63, 68, 10, 14, C.skin_light, C.skin, C.skin_shadow);

  // Hand (right, slightly clenched)
  ellipse(68, 82, 5, 4, C.skin);
  rect(65, 80, 7, 5, C.skin);
  rect(65, 80, 3, 4, C.skin_light);
  rect(69, 81, 3, 3, C.skin_shadow);
  rect(65, 84, 2, 1, C.skin_dark);
  rect(67, 84, 2, 1, C.skin_dark);
  rect(69, 84, 2, 1, C.skin_dark);

  // ── NECK (y: 36–44) ─────────────────────────────────────────────────────────
  shadedRect(43, 34, 10, 10, C.skin_light, C.skin, C.skin_shadow);
  rect(44, 34, 4, 10, C.skin_light);
  rect(47, 36, 3, 7, C.skin_shadow);

  // ── HEAD (y: 8–38) ──────────────────────────────────────────────────────────
  // Head shape — slightly wider at jaw
  ellipse(48, 24, 18, 16, C.skin);

  // Head shading — right side in shadow (light from left)
  for (let y = 8; y < 40; y++) {
    for (let x = 54; x < 70; x++) {
      if (grid[y * W + x] === C.skin) {
        const dx = x - 48;
        const t = dx / 20;
        if (t > 0.5) px(x, y, C.skin_shadow);
        else if (t > 0.2) px(x, y, C.skin);
      }
    }
  }
  // Left side highlight
  for (let y = 10; y < 30; y++) {
    for (let x = 30; x < 44; x++) {
      if (grid[y * W + x] === C.skin) px(x, y, C.skin_light);
    }
  }
  // Cheekbone highlight
  rect(34, 22, 6, 4, C.muscle_hi);

  // Jaw / chin definition
  rect(36, 32, 24, 3, C.skin_shadow);
  rect(42, 33, 12, 4, C.skin);
  rect(45, 35, 6, 3, C.jaw_shadow);

  // ── FACIAL FEATURES ─────────────────────────────────────────────────────────
  // Eyes (left-facing: right eye closer to camera is slightly larger)
  // Right eye (camera-near)
  rect(38, 20, 8, 5, C.eye_white);
  rect(40, 21, 5, 3, C.eye);
  rect(41, 21, 2, 2, C.skin); // specular
  rect(38, 20, 8, 1, C.brow);  // upper lid
  rect(38, 24, 8, 1, C.skin_shadow); // lower lid

  // Left eye (camera-far, slightly smaller)
  rect(50, 21, 6, 4, C.eye_white);
  rect(51, 22, 4, 2, C.eye);
  rect(52, 22, 1, 1, C.skin); // specular
  rect(50, 21, 6, 1, C.brow);

  // Eyebrows (strong, furrowed — serious expression)
  rect(36, 17, 10, 2, C.brow);
  rect(36, 17, 10, 1, C.hair); // top edge darker
  rect(48, 18, 8, 2, C.brow);
  rect(36, 19, 2, 1, C.brow); // inner brow furrow

  // Nose
  rect(44, 24, 4, 5, C.skin_shadow);
  rect(43, 28, 6, 2, C.skin_shadow);
  rect(44, 26, 2, 3, C.skin_light); // nose bridge highlight
  // Nostrils
  rect(43, 29, 2, 1, C.skin_dark);
  rect(47, 29, 2, 1, C.skin_dark);

  // Mouth — tight, determined expression
  rect(40, 32, 12, 2, C.lip);
  rect(41, 32, 10, 1, C.skin_shadow); // upper lip line
  rect(40, 33, 12, 1, C.skin_shadow); // lower lip shadow
  // Corner shadows
  rect(40, 32, 2, 2, C.skin_shadow);
  rect(50, 32, 2, 2, C.skin_shadow);

  // Ear (right ear visible, camera side)
  ellipse(30, 24, 4, 5, C.skin);
  rect(31, 22, 3, 6, C.skin_light);
  rect(30, 23, 2, 4, C.skin_shadow);
  rect(31, 24, 1, 2, C.skin_dark); // ear canal

  // ── HAIR ────────────────────────────────────────────────────────────────────
  // Top of head hair
  rect(34, 8, 28, 10, C.hair);
  // Hair line — slightly jagged
  rect(33, 10, 2, 4, C.hair);
  rect(35, 9, 4, 3, C.hair);
  rect(60, 10, 2, 4, C.hair);
  // Hair highlight
  rect(38, 8, 14, 3, C.hair);
  rect(40, 8, 10, 2, C.skin_dark); // subtle sheen on hair top
  rect(42, 8, 6, 1, C.brow);

  // ── HEADBAND ────────────────────────────────────────────────────────────────
  rect(32, 14, 34, 5, C.headband);
  // Headband highlight top edge
  rect(32, 14, 34, 1, C.headband_hi);
  // Headband shadow bottom edge
  rect(32, 18, 34, 1, C.headband_dark);
  // Headband texture lines
  for (let x = 34; x < 64; x += 4) {
    rect(x, 14, 2, 5, C.headband_dark);
  }
  // Knot/tie on the left side (camera near)
  rect(30, 13, 8, 7, C.headband);
  rect(31, 12, 6, 2, C.headband_hi);
  // Bandana tails hanging down left
  rect(28, 18, 4, 12, C.bandana_tail);
  rect(30, 18, 4, 16, C.bandana_tail);
  rect(29, 20, 2, 14, C.headband_dark);
  // Tail tips — diagonal taper
  for (let i = 0; i < 4; i++) {
    rect(28 + i, 30 + i * 2, 4 - i, 2, C.bandana_tail);
  }

  console.log("  Character geometry complete.");
}

// ─── OUTLINE PASS ─────────────────────────────────────────────────────────────
function buildOutlineAndPixels() {
  const pixels = [];

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] === null) continue;

      let isBorder = false;
      for (let dy = -1; dy <= 1 && !isBorder; dy++) {
        for (let dx = -1; dx <= 1 && !isBorder; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= W || ny < 0 || ny >= H || grid[ny * W + nx] === null)
            isBorder = true;
        }
      }

      pixels.push({ x, y, color: isBorder ? C.outline : grid[y * W + x] });
    }
  }

  return pixels;
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
async function main() {
  // 1. Health check
  const health = await fetch(`${BRIDGE_URL}/health`).then(r => r.json());
  console.log(`Bridge: ${health.status} | Pixelorama: ${health.pixelorama_version}`);

  // 2. Create canvas — transparent background (no fill)
  console.log(`Creating canvas ${W}x${H}...`);
  await cmd("create_canvas", { width: W, height: H, name: "Soldier Character" });

  // 3. Draw all geometry into the in-memory grid
  console.log("Computing character geometry...");
  drawCharacter();

  // 4. Build final pixel list with outline pass
  console.log("Running outline pass...");
  const pixels = buildOutlineAndPixels();
  console.log(`  Total pixels: ${pixels.length}`);

  // 5. Flush to Pixelorama
  console.log("Drawing to Pixelorama...");
  await drawPixelsBatched(pixels);

  // 6. Fit viewport
  await cmd("fit_to_frame", {});

  console.log("\n✅ Soldier character complete!");
  console.log(`   Canvas: ${W}x${H} | Pixels drawn: ${pixels.length}`);
}

main().catch(e => {
  console.error("Fatal:", e);
  process.exit(1);
});
