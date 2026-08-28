/**
 * draw_bullet.js
 * Draws a high-fidelity, 3D shaded silver bullet facing right
 * on a transparent 128x128 canvas via the pix-MCP bridge.
 * Uses resolution-independent scalar math and optimized batching.
 */

const BRIDGE_URL = "http://127.0.0.1:7373";

async function cmd(tool, params = {}) {
  const res = await fetch(`${BRIDGE_URL}/command`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool, params }),
  });
  return await res.json();
}

function getDistanceToSegment(x, y, x1, y1, x2, y2) {
  const A = x - x1, B = y - y1, C = x2 - x1, D = y2 - y1;
  const dot = A * C + B * D;
  const lenSq = C * C + D * D;
  let param = -1;
  if (lenSq !== 0) param = dot / lenSq;

  let xx, yy;
  if (param < 0) { xx = x1; yy = y1; } 
  else if (param > 1) { xx = x2; yy = y2; } 
  else { xx = x1 + param * C; yy = y1 + param * D; }

  return { dist: Math.hypot(x - xx, y - yy), t: param };
}

async function main() {
  // Resolution Independent Constants
  const W = 128; 
  const H = 128;
  const SCALE = W / 64; 

  console.log("Connecting to Pixelorama REST Bridge...");
  try {
    await fetch(`${BRIDGE_URL}/health`);
  } catch (e) {
    console.error("ERROR: Cannot connect to Pixelorama. Ensure the app has focus.");
    process.exit(1);
  }

  console.log(`Creating transparent ${W}x${H} canvas...`);
  await cmd("create_canvas", { width: W, height: H, name: "Silver Bullet" });

  // Metallic Chrome & Brass Palette
  const palette = {
    metal_specular: "#ffffff", // Pure white glint
    metal_high:     "#e6e6fa", // Ultra light silver-blue
    metal_mid:      "#b0b0b8", // Base polished steel
    metal_shadow:   "#686870", // Deep metallic shadow
    metal_deep:     "#383840", // Dark ambient occlusion
    
    brass_high:     "#ffeea1", // Polished brass rim highlight
    brass_mid:      "#cca025", // Base bullet casing brass
    brass_shadow:   "#806008", // Dark copper-brass shadow
    
    outline:        "#111113"  // Crisp technical outline
  };

  const pixels = [];
  const grid = new Array(W * H).fill(null);

  // Geometry Bounds (Centered relative to W and H)
  const CX = W * 0.5;
  const CY = H * 0.5;
  const BULLET_LENGTH = W * 0.55;
  const RADIUS = 11 * SCALE;

  // X-coordinates for structural breakdown (Projecting horizontally to the right)
  const START_X = CX - (BULLET_LENGTH * 0.5);
  const CRIMP_X = START_X + (BULLET_LENGTH * 0.45); // Where casing meets the projectile
  const TIP_X   = START_X + BULLET_LENGTH;          // The absolute tip of the bullet

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const dy = Math.abs(y - CY);

      // --- PASS 1: THE BRASS CASING (Left side cylinder) ---
      if (x >= START_X && x <= CRIMP_X) {
        if (dy <= RADIUS) {
          // Outline boundary
          if (dy > RADIUS - 1.2 || x === START_X) {
            grid[y * W + x] = palette.outline;
            continue;
          }

          // Cylindrical 3D Shading for the Casing (Top-lit)
          const normY = (y - (CY - RADIUS)) / (RADIUS * 2);
          let color = palette.brass_mid;
          
          if (normY < 0.15) color = palette.brass_shadow; // Subtle rim ambient reflection
          else if (normY < 0.35) color = palette.brass_high;   // Bright golden ridge
          else if (normY > 0.75) color = palette.brass_shadow; // Dark bottom shadow

          // Primer rim dynamic indent at the very back
          if (x < START_X + (2 * SCALE) && (dy > RADIUS * 0.75 || dy < RADIUS * 0.2)) {
             color = palette.brass_shadow;
          }

          grid[y * W + x] = color;
        }
      }

      // --- PASS 2: THE LEAD/SILVER PROJECTILE (Right side aerodynamic tip) ---
      if (x > CRIMP_X && x <= TIP_X) {
        const segPct = (x - CRIMP_X) / (TIP_X - CRIMP_X);
        
        // Aerodynamic ogive curve function (Tapering to a sharp point non-linearly)
        const localRadius = RADIUS * Math.cos(segPct * Math.PI * 0.48);

        if (dy <= localRadius) {
          // Outline boundary
          if (dy > localRadius - 1.2 || x === Math.floor(TIP_X)) {
            grid[y * W + x] = palette.outline;
            continue;
          }

          // Polished Chrome Cylindrical Shading
          const normY = (y - (CY - localRadius)) / (localRadius * 2);
          let color = palette.metal_mid;

          if (normY < 0.12) color = palette.metal_deep;     // Top horizon reflection line
          else if (normY < 0.22) color = palette.metal_specular; // Blinding flash glint
          else if (normY < 0.45) color = palette.metal_high;     // Radiant silver surface
          else if (normY > 0.75) color = palette.metal_deep;     // Core core shadow
          else if (normY > 0.55) color = palette.metal_shadow;   // Standard core shadow

          // Joint ambient occlusion crease where projectile enters the casing
          if (x < CRIMP_X + (2 * SCALE)) {
             color = palette.metal_deep;
          }

          grid[y * W + x] = color;
        }
      }
    }
  }

  // --- PASS 3: EXTRACT AND SAFELY STREAM BATCHES ---
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x]) {
        pixels.push({ x, y, color: grid[y * W + x] });
      }
    }
  }

  console.log(`Generated ${pixels.length} metallic pixels. Streaming...`);
  
  // Safe batch execution via our playbook rule
  const BATCH_SIZE = 1000;
  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    const batch = pixels.slice(i, i + BATCH_SIZE);
    await cmd("draw_pixels", { pixels: batch });
  }
  
  console.log("\nBullet rendered completely! Focusing canvas...");
  await cmd("fit_viewport");
}

main();
