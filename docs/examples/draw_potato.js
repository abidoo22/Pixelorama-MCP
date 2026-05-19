/**
 * draw_potato.js
 * Draws a gorgeous, organic pixel-art potato on a 64x64 Pixelorama canvas via the pix-MCP bridge.
 * Uses batched pixel draws for maximum speed and compatibility.
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
  await cmd("create_canvas", { width: W, height: H, name: "Pixel Potato" });

  // 3. Fill background with a warm dark grey-blue
  console.log("Filling background...");
  await cmd("fill_area", { x: 0, y: 0, color: "#1f2421" });

  // 4. Build potato pixel data
  const colors = {
    outline:     "#2b1704",
    body:        "#c08a4e",
    highlight:   "#dfb27c",
    light_highlight: "#f5d5aa",
    shadow:      "#8f5c2b",
    deep_shadow: "#5e3814",
    eye:         "#40240a",
    eye_highlight: "#dfb27c"
  };

  // Virtual pixel map
  const grid = new Array(W * H).fill(null);

  // Math-organic potato generation
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const dx = x - 32;
      const dy = y - 32;
      
      // Calculate polar coordinates for perturbation
      const angle = Math.atan2(dy, dx);
      // Low frequency wave perturbations for natural potato bumps
      const perturbation = 1.0 + 0.08 * Math.sin(3 * angle) + 0.05 * Math.cos(5 * angle + 1.2);
      
      const rx = 22 * perturbation;
      const ry = 15 * perturbation;
      
      const val = Math.pow(dx / rx, 2) + Math.pow(dy / ry, 2);
      
      if (val <= 1.0) {
        // Base coloring based on vertical and horizontal gradients (lighting from top-left)
        const lightDir = (dx / rx) * -0.5 + (dy / ry) * 0.8; // top-left is highlight, bottom-right is shadow
        
        let col;
        if (lightDir < -0.6) {
          col = colors.light_highlight;
        } else if (lightDir < -0.2) {
          col = colors.highlight;
        } else if (lightDir < 0.3) {
          col = colors.body;
        } else if (lightDir < 0.7) {
          col = colors.shadow;
        } else {
          col = colors.deep_shadow;
        }
        
        grid[y * W + x] = col;
      }
    }
  }

  // Adding potato eyes (indentations/spots)
  const eyes = [
    { x: 22, y: 26 },
    { x: 44, y: 36 },
    { x: 32, y: 22 },
    { x: 25, y: 40 },
    { x: 38, y: 30 },
    { x: 46, y: 26 },
    { x: 30, y: 42 }
  ];

  for (const eye of eyes) {
    // Check if within potato bounds
    if (grid[eye.y * W + eye.x] !== null) {
      // Dark eye pit
      grid[eye.y * W + eye.x] = colors.eye;
      
      // Subtly shadow the left/top of the eye
      if (grid[(eye.y - 1) * W + eye.x] !== null) grid[(eye.y - 1) * W + eye.x] = colors.deep_shadow;
      if (grid[eye.y * W + eye.x - 1] !== null) grid[eye.y * W + eye.x - 1] = colors.deep_shadow;
      
      // Light highlight below/right of the eye to give depth
      if (grid[(eye.y + 1) * W + eye.x + 1] !== null) grid[(eye.y + 1) * W + eye.x + 1] = colors.eye_highlight;
    }
  }

  // Drop shadow (offset +3, +4)
  const shadowPixels = [];
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] !== null) {
        const sx = x + 3, sy = y + 4;
        if (sx < W && sy < H && grid[sy * W + sx] === null) {
          shadowPixels.push({ x: sx, y: sy, color: "#0f1110" });
        }
      }
    }
  }

  // Outline: any potato pixel adjacent to null → outline
  const potatoPixels = [];
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
      potatoPixels.push({ x, y, color: isBorder ? colors.outline : grid[y * W + x] });
    }
  }

  // 5. Draw shadow
  console.log(`Drawing drop shadow (${shadowPixels.length} px)...`);
  await drawPixelsBatched(shadowPixels);

  // 6. Draw potato
  console.log(`Drawing potato body (${potatoPixels.length} px)...`);
  await drawPixelsBatched(potatoPixels);

  console.log("\n✅ Potato complete!");
}

main().catch(e => { console.error("Fatal:", e); process.exit(1); });
