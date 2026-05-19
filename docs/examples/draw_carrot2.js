/**
 * draw_hd_carrot.js
 * Draws a breathtaking, high-definition 3D pixel-art carrot at 256x256.
 * Uses fully relative scalar math and payload batching for stability.
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
  // 🌟 THE RESOLUTION SCALER
  const W = 256; 
  const H = 256;
  const SCALE = W / 64; // Base multiplier for stroke widths and radii

  console.log(`Connecting to Pixelorama Bridge...`);
  try {
    await fetch(`${BRIDGE_URL}/health`);
  } catch (e) {
    console.error("ERROR: Cannot connect. Make sure Pixelorama is running.");
    process.exit(1);
  }

  console.log(`Creating HD transparent ${W}x${W} canvas...`);
  await cmd("create_canvas", { width: W, height: H, name: "HD Golden Carrot" });

  const palette = {
    orange_specular:"#ffebb3", orange_high: "#ffd685", orange_light: "#ffb84d",
    orange_mid: "#ff7b00", orange_shadow: "#cc4700", orange_deep: "#8c2400",
    green_high: "#b3f03b", green_mid: "#4d9e18", green_shadow: "#1b5c09",
    green_deep: "#0e3b04", green_stem: "#3a7a12", outline: "#260800"
  };

  const pixels = [];
  const grid = new Array(W * H).fill(null);

  // 2. Relative Geometry (Scales automatically to W and H)
  const BX1 = W * 0.56, BY1 = H * 0.40;
  const BX2 = W * 0.34, BY2 = H * 0.84;

  const stalks = [
    { x1: BX1, y1: BY1, x2: W * 0.25, y2: H * 0.18, w: 2.0 * SCALE },
    { x1: BX1, y1: BY1, x2: W * 0.37, y2: H * 0.09, w: 2.8 * SCALE },
    { x1: BX1, y1: BY1, x2: W * 0.59, y2: H * 0.06, w: 3.0 * SCALE },
    { x1: BX1, y1: BY1, x2: W * 0.75, y2: H * 0.12, w: 2.6 * SCALE },
    { x1: BX1, y1: BY1, x2: W * 0.87, y2: H * 0.28, w: 1.8 * SCALE }
  ];

  // --- Pass 1: Draw Leaf Foliage ---
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      let isLeaf = false, leafDist = Infinity, leafT = 0, stalkIndex = -1;

      for (let i = 0; i < stalks.length; i++) {
        const s = stalks[i];
        const seg = getDistanceToSegment(x, y, s.x1, s.y1, s.x2, s.y2);
        
        // Scaled organic waves
        const wave1 = Math.sin(seg.t * 15) * (1.5 * SCALE);
        const wave2 = Math.cos(seg.t * 8) * (1.0 * SCALE);
        const stalkWidth = s.w * (1 - seg.t * 0.6); 
        const leafRadius = stalkWidth + Math.max(0, wave1 + wave2) * (seg.t > 0.1 ? 1 : 0.4);

        if (seg.dist <= leafRadius && seg.t >= 0 && seg.t <= 1) {
            isLeaf = true;
            if (seg.dist < leafDist) { leafDist = seg.dist; leafT = seg.t; stalkIndex = i; }
        }
      }

      if (isLeaf) {
          const s = stalks[stalkIndex];
          const dx = x - (s.x1 + leafT * (s.x2 - s.x1));
          const dy = y - (s.y1 + leafT * (s.y2 - s.y1));
          const dot = -0.6 * dx - 0.8 * dy; 

          let color = palette.green_mid;
          if (leafDist < (0.8 * SCALE) && leafT > 0.1) color = palette.green_stem;
          else if (dot > 0.7) color = palette.green_high;
          else if (dot < -0.5) color = palette.green_shadow;
          
          const currentRadius = (s.w * (1 - leafT * 0.6)) + Math.max(0, Math.sin(leafT * 15) * (1.5*SCALE) + Math.cos(leafT * 8) * (1.0*SCALE)) * (leafT > 0.1 ? 1 : 0.4);
          if (leafDist > currentRadius - (0.9 * SCALE) && leafT > 0.15) color = palette.green_deep;

          if (!grid[y * W + x] || stalkIndex < 2) grid[y * W + x] = color;
      }
    }
  }

  // --- Pass 2: Draw Carrot Body ---
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const seg = getDistanceToSegment(x, y, BX1, BY1, BX2, BY2);
      const taper = Math.pow(seg.t, 1.2); 
      const radius = (12.0 * SCALE) * (1 - taper * 0.95);

      if (seg.dist <= radius && seg.t >= 0 && seg.t <= 1) {
        if (seg.dist > radius - (1.2 * SCALE)) {
          if (!(seg.t < 0.15 && grid[y * W + x] && grid[y * W + x] !== palette.outline)) {
             grid[y * W + x] = palette.outline;
          }
          continue;
        }

        const segmentAngle = Math.atan2(BY2 - BY1, BX2 - BX1);
        const normalAngle = segmentAngle + Math.PI / 2;
        const px = x - (BX1 + seg.t * (BX2 - BX1));
        const py = y - (BY1 + seg.t * (BY2 - BY1));
        const dot = (px * Math.cos(normalAngle) + py * Math.sin(normalAngle)) / (seg.dist || 1);
        
        let color = palette.orange_mid;
        if (dot < -0.8 && seg.dist < radius * 0.6) color = palette.orange_specular; 
        else if (dot < -0.4) color = palette.orange_high;   
        else if (dot < 0.1) color = palette.orange_light;  
        else if (dot > 0.7) color = palette.orange_deep;   
        else if (dot > 0.3) color = palette.orange_shadow; 

        // Normalized texture ridges
        const ridgeFreq = 22;
        const ridgePhase = (x / W) * 20 + (y / H) * 10; 
        const ridgeSpacing = Math.sin(seg.t * ridgeFreq + ridgePhase);
        
        if (Math.abs(ridgeSpacing) < 0.25 && seg.t > 0.1 && seg.t < 0.85) {
            if (dot < 0.3) {
                 color = palette.orange_shadow;
                 if (Math.abs(ridgeSpacing) < 0.1) color = palette.orange_deep;
            } else {
                color = palette.orange_deep;
            }
        }
        grid[y * W + x] = color;
      }
    }
  }

  // --- Pass 3: Extract and Batch Stream ---
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x]) pixels.push({ x, y, color: grid[y * W + x] });
    }
  }

  console.log(`Computed ${pixels.length} HD pixels! Streaming to Pixelorama...`);
  
  // Send in safe batches of 1000 pixels to respect the playbook optimizations!
  const BATCH_SIZE = 1000;
  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    const batch = pixels.slice(i, i + BATCH_SIZE);
    await cmd("draw_pixels", { pixels: batch });
    process.stdout.write(`\rProgress: ${Math.min(i + BATCH_SIZE, pixels.length)} / ${pixels.length} pixels drawn...`);
  }
  
  console.log("\nHD Golden Carrot drawn successfully! Centering viewport...");
  await cmd("fit_viewport");
}

main();
