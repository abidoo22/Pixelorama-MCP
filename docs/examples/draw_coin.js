/**
 * draw_coin.js
 * Draws a breathtaking, highly detailed 3D golden coin on a 64x64 Pixelorama canvas via the pix-MCP bridge.
 * Implements a beveled outer rim, a perfectly shaded inner surface, a beveled 3D star in the center, and a smooth drop shadow.
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

// Check if a point (x, y) is inside a star with center (cx, cy), outer radius, inner radius, and 5 points
function inStar(x, y, cx, cy, rOuter, rInner) {
  const dx = x - cx;
  const dy = y - cy;
  const r = Math.hypot(dx, dy);
  if (r > rOuter) return false;
  if (r < rInner) return true;

  const angle = Math.atan2(dy, dx);
  // Normalize angle to [0, 2*PI]
  const normAngle = angle < 0 ? angle + 2 * Math.PI : angle;
  
  // Star has 5 points, each point is 2*PI/5 = 72 degrees wide.
  const segment = (2 * Math.PI) / 5;
  const halfSegment = segment / 2;
  
  // Find which segment we are in
  const localAngle = normAngle % segment;
  
  // Calculate threshold radius at this local angle
  let dist;
  if (localAngle < halfSegment) {
    // Interpolating from outer peak to inner valley
    const t = localAngle / halfSegment;
    dist = rOuter * (1 - t) + rInner * t;
  } else {
    // Interpolating from inner valley to outer peak
    const t = (localAngle - halfSegment) / halfSegment;
    dist = rInner * (1 - t) + rOuter * t;
  }
  
  return r <= dist;
}

async function main() {
  const W = 64, H = 64;

  // 1. Health check
  const health = await fetch(`${BRIDGE_URL}/health`).then(r => r.json());
  console.log("Bridge:", health.status, "| Pixelorama:", health.pixelorama_version);

  // 2. Create canvas
  console.log("Creating canvas 64x64...");
  await cmd("create_canvas", { width: W, height: H, name: "Golden Coin" });

  // 3. Fill background with a premium dark carbon grey-blue
  console.log("Filling background...");
  await cmd("fill_area", { x: 0, y: 0, color: "#191a21" });

  // 4. Color Palette
  const colors = {
    outline:        "#281605",
    highlight:      "#fff6b0", // Sunny bright yellow gold highlight
    gold_light:     "#fcd116", // Bright solid yellow gold
    gold_mid:       "#f39c12", // Core orange-gold
    gold_shadow:    "#b87300", // Deep warm golden shadow
    gold_deep:      "#7a4b00", // Dark bronze-gold shadow
    star_light:     "#fffbda", // Extra light gold for star reflections
    star_mid:       "#ffe052", // Solid star body
    star_shadow:    "#d68a00", // Star shaded side
    shadow:         "#0c0c0e"  // Premium dark drop-shadow
  };

  const grid = new Array(W * H).fill(null);

  // Center and Radii
  const CX = 32, CY = 32;
  const R_OUTER = 22;
  const R_RIM = 17;
  const R_INNER = 16;

  // Render the coin geometry
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const dx = x - CX;
      const dy = y - CY;
      const r = Math.hypot(dx, dy);

      if (r <= R_OUTER) {
        // Shading direction (lighting from top-left, i.e., dx < 0 and dy < 0 is highlight)
        const cosAngle = dx / (r || 1);
        const sinAngle = dy / (r || 1);
        
        // Light dot product (vector pointing towards top-left)
        const light = -0.7 * cosAngle - 0.7 * sinAngle; 

        if (r >= R_RIM) {
          // ─── OUTER BEVELED RIM ───
          // Top-left is bright highlight, bottom-right is dark shadow
          if (light > 0.4) {
            grid[y * W + x] = colors.highlight;
          } else if (light > 0.0) {
            grid[y * W + x] = colors.gold_light;
          } else if (light > -0.5) {
            grid[y * W + x] = colors.gold_mid;
          } else {
            grid[y * W + x] = colors.gold_shadow;
          }
        } 
        else if (r >= R_INNER) {
          // ─── RIM INNER EDGE / CREASE ───
          // Inverted lighting to show depth (crease has shadow on top-left, highlight on bottom-right)
          if (light > 0.2) {
            grid[y * W + x] = colors.gold_deep;
          } else if (light > -0.3) {
            grid[y * W + x] = colors.gold_shadow;
          } else {
            grid[y * W + x] = colors.gold_light;
          }
        }
        else {
          // ─── COIN INNER FACE ───
          // Subtle radial gradient to make it look slightly concave
          const normDist = r / R_INNER; // 0 to 1
          const radialLight = light - 0.3 * normDist;

          let col = colors.gold_mid;
          if (radialLight > 0.45) {
            col = colors.highlight;
          } else if (radialLight > 0.1) {
            col = colors.gold_light;
          } else if (radialLight > -0.3) {
            col = colors.gold_mid;
          } else if (radialLight > -0.7) {
            col = colors.gold_shadow;
          } else {
            col = colors.gold_deep;
          }
          grid[y * W + x] = col;
        }
      }
    }
  }

  // ─── CENTRAL STAR EMBLEM (3D pop effect) ───
  const STAR_R_OUTER = 9;
  const STAR_R_INNER = 4;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const dx = x - CX;
      const dy = y - CY;
      
      if (inStar(x, y, CX, CY, STAR_R_OUTER, STAR_R_INNER)) {
        // Lighting for 3D star: highlight on left-facing facets, shadow on right-facing facets
        const angle = Math.atan2(dy, dx);
        const normAngle = angle < 0 ? angle + 2 * Math.PI : angle;
        
        // Check which side of the star points we are on
        const segment = (2 * Math.PI) / 5;
        const localAngle = normAngle % segment;
        
        // Left side of the point gets highlight, right gets shadow
        let col = colors.star_mid;
        if (localAngle < segment / 2) {
          col = colors.star_light;
        } else {
          col = colors.star_shadow;
        }
        
        // Add a micro-highlight at the star tip
        if (Math.hypot(dx, dy) < 2) {
          col = colors.highlight;
        }

        grid[y * W + x] = col;
      }
    }
  }

  // ─── DROP SHADOW GENERATION ───
  const shadowPixels = [];
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] !== null) {
        const sx = x + 3;
        const sy = y + 3;
        if (sx < W && sy < H && grid[sy * W + sx] === null) {
          shadowPixels.push({ x: sx, y: sy, color: colors.shadow });
        }
      }
    }
  }

  // ─── OUTLINE & ASSEMBLY ───
  const coinPixels = [];
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] === null) continue;

      // Determine border pixels for outline
      let isBorder = false;
      for (let dy = -1; dy <= 1 && !isBorder; dy++) {
        for (let dx = -1; dx <= 1 && !isBorder; dx++) {
          const nx = x + dx;
          const ny = y + dy;
          if (nx < 0 || nx >= W || ny < 0 || ny >= H || grid[ny * W + nx] === null) {
            isBorder = true;
          }
        }
      }

      coinPixels.push({
        x,
        y,
        color: isBorder ? colors.outline : grid[y * W + x]
      });
    }
  }

  // 5. Draw Drop Shadow
  console.log(`Drawing drop shadow (${shadowPixels.length} px)...`);
  await drawPixelsBatched(shadowPixels);

  // 6. Draw Coin body
  console.log(`Drawing golden coin body (${coinPixels.length} px)...`);
  await drawPixelsBatched(coinPixels);

  console.log("\n✅ Golden Coin complete!");
}

main().catch(e => {
  console.error("Fatal error:", e);
  process.exit(1);
});
