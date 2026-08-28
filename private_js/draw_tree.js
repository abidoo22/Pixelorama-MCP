/**
 * draw_modular_pine_tree.js
 * Generates a modular 3D pixel-art pine/Christmas tree asset package split vertically into 3 zones:
 * 1. Tiered Pine Canopy/Leaves (Top) - Styled like a Christmas tree with downward triangular tufts.
 * 2. Seamless Repeatable Trunk Segment (Middle)
 * 3. Root Base (Bottom)
 * Optimized for 2D game engine structural tiling on a transparent 128x128 canvas.
 * All comments are in English only.
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

async function main() {
  const W = 128; 
  const H = 128;
  const SCALE = W / 64; 

  console.log("Connecting to Pixelorama Bridge...");
  try {
    await fetch(`${BRIDGE_URL}/health`);
  } catch (e) {
    console.error("ERROR: Bridge offline. Please focus the Pixelorama window.");
    process.exit(1);
  }

  console.log(`Creating 128x128 modular Christmas tree canvas...`);
  await cmd("create_canvas", { width: W, height: H, name: "Modular Pine Tree" });

  const palette = {
    // Rich Pine/Christmas Tree Green tones
    foliage_high:   "#73c23a", // Sunlit bright pine needle tip
    foliage_mid:    "#388a25", // Vibrant classic pine green
    foliage_shadow: "#1b5212", // Shaded branch undersides
    foliage_deep:   "#092b05", // Deep inner branch shadows
    
    trunk_high:     "#a06b43", // Light highlighted bark
    trunk_mid:      "#704221", // Core wood brown
    trunk_shadow:   "#42220f", // Dark trunk shadow
    
    outline:        "#0e0d12"  // Clean black outline
  };

  const grid = new Array(W * H).fill(null);
  const pixels = [];

  const CX = Math.floor(W / 2);
  const TRUNK_RADIUS = 5 * SCALE;

  // --- VERTICAL ZONE METRICS ---
  const CANOPY_BOTTOM = Math.floor(H * 0.52); // Pine needles layer ends here
  const TRUNK_START   = Math.floor(H * 0.55); // Repeatable segment top
  const TRUNK_END     = Math.floor(H * 0.80); // Repeatable segment bottom
  const ROOT_START    = Math.floor(H * 0.85); // Roots base zone starts

  // --- PINE LEAVES GEOMETRY (3 Overlapping Triangular Tiers) ---
  // Each tier has a top apex, a bottom vertical span, and a maximum width
  const pineTiers = [
    { topY: Math.floor(H * 0.05), botY: Math.floor(H * 0.22), maxW: 14 * SCALE }, // Top Tier
    { topY: Math.floor(H * 0.16), botY: Math.floor(H * 0.38), maxW: 22 * SCALE }, // Middle Tier
    { topY: Math.floor(H * 0.30), botY: Math.floor(H * 0.52), maxW: 30 * SCALE }  // Bottom Tier
  ];

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const dx = Math.abs(x - CX);

      // ==========================================
      // ZONE 1: PINE CANOPY / CHRISTMAS LEAVES
      // ==========================================
      if (y <= CANOPY_BOTTOM) {
        let insidePine = false;
        let activeColor = null;
        let smallestTierDiff = Infinity;

        // Check each pine tier from bottom to top to handle overlapping layers cleanly
        for (let i = pineTiers.length - 1; i >= 0; i--) {
          const tier = pineTiers[i];
          
          if (y >= tier.topY && y <= tier.botY) {
            // Linear interpolation to make a triangle shape that expands downwards
            const tierProgress = (y - tier.topY) / (tier.botY - tier.topY);
            
            // Add organic jagged edges to simulate sharp pine needle tufts (combining sine waves)
            const jaggedEdge = Math.sin(y * 0.9) * (1.2 * SCALE) + Math.cos(x * 0.6) * (0.8 * SCALE);
            const currentWidth = (tier.maxW * tierProgress) + jaggedEdge;

            if (dx <= currentWidth) {
              insidePine = true;
              
              // 3D Isometric Lighting calculation for pine needles (Light source: Top-Left)
              const normX = (x - (CX - currentWidth)) / (currentWidth * 2 || 1);
              const verticalShade = tierProgress * 0.4; // Darker near the bottom of each branch tier
              
              const lightScore = (1.0 - normX) - verticalShade;

              if (lightScore > 0.60) activeColor = palette.foliage_high;
              else if (lightScore > 0.25) activeColor = palette.foliage_mid;
              else if (lightScore > -0.1) activeColor = palette.foliage_shadow;
              else activeColor = palette.foliage_deep;

              // Shaded baseline under-rim for each specific tier branch layer
              if (y > tier.botY - (2.5 * SCALE)) {
                activeColor = palette.foliage_deep;
              }
              
              break; // Stop evaluating higher tiers if captured by a lower foreground tier
            }
          }
        }
        if (insidePine) grid[y * W + x] = activeColor;
      }

      // ==========================================
      // ZONE 2: REPEATABLE SEAMLESS TRUNK
      // ==========================================
      else if (y >= TRUNK_START && y <= TRUNK_END) {
        if (dx <= TRUNK_RADIUS) {
          if (dx > TRUNK_RADIUS - 1.2) {
            grid[y * W + x] = palette.outline;
            continue;
          }

          const normX = (x - (CX - TRUNK_RADIUS)) / (TRUNK_RADIUS * 2);
          let color = palette.trunk_mid;

          if (normX < 0.25) color = palette.trunk_high;
          else if (normX > 0.65) color = palette.trunk_shadow;

          const barkPattern = Math.sin(x * 0.8) * Math.cos(y * 0.15);
          if (barkPattern > 0.5 && normX > 0.2) color = palette.trunk_shadow;

          grid[y * W + x] = color;
        }
      }

      // ==========================================
      // ZONE 3: ROOT BASE
      // ==========================================
      else if (y >= ROOT_START) {
        const rootT = (y - ROOT_START) / (H - ROOT_START);
        const rootFlare = Math.pow(rootT, 3) * (8 * SCALE); 
        const currentRadius = TRUNK_RADIUS + rootFlare;

        if (dx <= currentRadius) {
          if (dx > currentRadius - 1.2 || y === H - 1) {
            grid[y * W + x] = palette.outline;
            continue;
          }

          const normX = (x - (CX - currentRadius)) / (currentRadius * 2);
          let color = palette.trunk_mid;

          if (normX < 0.25) color = palette.trunk_high;
          else if (normX > 0.65) color = palette.trunk_shadow;

          grid[y * W + x] = color;
        }
      }
    }
  }

  // --- PASS 3: GLOBAL HIGH-CONTRAST OUTLINE CLEANUP ---
  const finalGrid = [...grid];
  for (let y = 1; y < H - 1; y++) {
    for (let x = 1; x < W - 1; x++) {
      const current = finalGrid[y * W + x];
      if (current && current !== palette.outline) {
        // Exclude connection joints to maintain seam integrity
        if (y === TRUNK_START || y === TRUNK_END || y === ROOT_START) continue;

        if (!finalGrid[(y - 1) * W + x] || !finalGrid[(y + 1) * W + x] || !finalGrid[y * W + (x - 1)] || !finalGrid[y * W + (x + 1)]) {
          if (current === palette.foliage_deep || current === palette.trunk_shadow || current === palette.trunk_mid) {
             grid[y * W + x] = palette.outline;
          }
        }
      }
    }
  }

  // --- PASS 4: EXTRACT AND STREAM PAYLOAD ---
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x]) {
        pixels.push({ x, y, color: grid[y * W + x] });
      }
    }
  }

  console.log(`Compiled ${pixels.length} modular pine pixels. Streaming...`);
  
  const BATCH_SIZE = 1500;
  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    const batch = pixels.slice(i, i + BATCH_SIZE);
    await cmd("draw_pixels", { pixels: batch });
    process.stdout.write(`\rProgress: ${Math.min(i + BATCH_SIZE, pixels.length)} / ${pixels.length} cells drawn...`);
  }
  
  console.log("\nModular Pine/Christmas tree package generated perfectly!");
  await cmd("fit_viewport");
}

main();
