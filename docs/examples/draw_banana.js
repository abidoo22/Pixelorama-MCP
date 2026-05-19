/**
 * draw_banana_v2.js
 * Draws a pixel-art banana on a 64x64 Pixelorama canvas via the pix-MCP bridge.
 * Uses fill_area for background and batches pixel draws to avoid size limits.
 */

const BRIDGE_URL = "http://127.0.0.1:7373";
const BATCH_SIZE = 400; // max pixels per draw_pixels call

async function cmd(tool, params = {}) {
  const res = await fetch(`${BRIDGE_URL}/command`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool, params }),
  });
  const data = await res.json();
  if (!data.success) {
    console.error(`FAILED [${tool}]:`, data.error);
  }
  return data;
}

async function drawPixelsBatched(pixels) {
  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    const batch = pixels.slice(i, i + BATCH_SIZE);
    const r = await cmd("draw_pixels", { pixels: batch });
    if (!r.success) return r;
    process.stdout.write(`  pixels ${i + batch.length}/${pixels.length}\r`);
  }
  console.log();
  return { success: true };
}

async function main() {
  const W = 64, H = 64;

  // 1. Health check
  const health = await fetch(`${BRIDGE_URL}/health`).then(r => r.json());
  console.log("Bridge:", health.status, "| Pixelorama:", health.pixelorama_version);

  // 2. Create canvas
  console.log("Creating canvas 64x64...");
  await cmd("create_canvas", { width: W, height: H, name: "Pixel Banana" });

  // 3. Fill background with a single fill_area command (no size limit issue!)
  console.log("Filling background...");
  await cmd("fill_area", { x: 0, y: 0, color: "#1a1a2e" });

  // 4. Build banana pixel data
  const colors = {
    outline:     "#3d1f00",
    body:        "#ffd11a",
    highlight:   "#fff5a0",
    shadow:      "#c49a00",
    deep_shadow: "#7a5e00",
    green_light: "#8bbf2a",
    green_dark:  "#5a800a",
    stem:        "#4a2f0a",
    spot:        "#6b4200",
  };

  // Virtual pixel map: null = background
  const grid = new Array(W * H).fill(null);

  // Banana arc: center arc is a parabola curving upward left-to-right
  // Spans x=6..57, center y=41 - 0.038*(x-31)^2
  for (let x = 6; x <= 57; x++) {
    const cy = 41.0 - 0.038 * Math.pow(x - 31, 2);
    // Radius tapers at the ends
    const t = (x - 31) / 26;
    const r = 7.0 * Math.sqrt(Math.max(0, 1 - t * t));

    const yTop = Math.round(cy - r);
    const yBot = Math.round(cy + r);

    for (let y = yTop; y <= yBot; y++) {
      if (x < 0 || x >= W || y < 0 || y >= H) continue;
      const rel = r > 0 ? (y - cy) / r : 0;
      let col;
      if (rel < -0.55) col = colors.highlight;
      else if (rel < 0.3) col = colors.body;
      else col = colors.shadow;

      // Green ends
      if (x <= 10) {
        const f = (11 - x) / 5;
        col = Math.random() < f ? colors.green_light : col;
      } else if (x >= 53) {
        const f = (x - 52) / 5;
        col = Math.random() < f ? colors.green_light : col;
      }

      grid[y * W + x] = col;
    }
  }

  // Stem (left end, x=3..5)
  for (let x = 3; x <= 5; x++) {
    const cy = 41.0 - 0.038 * Math.pow(x - 31, 2);
    for (let y = Math.round(cy) - 2; y <= Math.round(cy) + 2; y++) {
      if (x >= 0 && x < W && y >= 0 && y < H)
        grid[y * W + x] = x === 3 ? colors.stem : colors.green_dark;
    }
  }

  // Tip (right end, x=58..60)
  for (let x = 58; x <= 60; x++) {
    const cy = 41.0 - 0.038 * Math.pow(x - 31, 2);
    for (let y = Math.round(cy) - 1; y <= Math.round(cy) + 1; y++) {
      if (x >= 0 && x < W && y >= 0 && y < H)
        grid[y * W + x] = colors.outline;
    }
  }

  // Deep shadow ridge (bottom of body)
  for (let x = 10; x <= 52; x++) {
    const cy = 41.0 - 0.038 * Math.pow(x - 31, 2);
    const t = (x - 31) / 26;
    const r = 7.0 * Math.sqrt(Math.max(0, 1 - t * t));
    const ry = Math.round(cy + r * 0.6);
    if (ry >= 0 && ry < H && grid[ry * W + x] !== null)
      grid[ry * W + x] = colors.deep_shadow;
  }

  // Extra highlight ridge
  for (let x = 10; x <= 52; x++) {
    const cy = 41.0 - 0.038 * Math.pow(x - 31, 2);
    const t = (x - 31) / 26;
    const r = 7.0 * Math.sqrt(Math.max(0, 1 - t * t));
    const ry = Math.round(cy - r * 0.5);
    if (ry >= 0 && ry < H && grid[ry * W + x] !== null)
      grid[ry * W + x] = colors.highlight;
  }

  // Organic spots
  const spots = [{ x: 20, y: 38 }, { x: 21, y: 39 }, { x: 33, y: 40 },
                 { x: 44, y: 36 }, { x: 45, y: 35 }, { x: 15, y: 34 }];
  for (const s of spots) {
    if (grid[s.y * W + s.x] !== null)
      grid[s.y * W + s.x] = colors.spot;
  }

  // Drop shadow (offset +3,+4)
  const shadowPixels = [];
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] !== null) {
        const sx = x + 3, sy = y + 4;
        if (sx < W && sy < H && grid[sy * W + sx] === null)
          shadowPixels.push({ x: sx, y: sy, color: "#0a0818" });
      }
    }
  }

  // Outline: any banana pixel adjacent to null → outline color
  const bananaPixels = [];
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
      bananaPixels.push({ x, y, color: isBorder ? colors.outline : grid[y * W + x] });
    }
  }

  // 5. Draw shadow
  console.log(`Drawing drop shadow (${shadowPixels.length} px)...`);
  await drawPixelsBatched(shadowPixels);

  // 6. Draw banana
  console.log(`Drawing banana body (${bananaPixels.length} px)...`);
  await drawPixelsBatched(bananaPixels);

  console.log("\n✅ Banana complete!");
}

main().catch(e => { console.error("Fatal:", e); process.exit(1); });
