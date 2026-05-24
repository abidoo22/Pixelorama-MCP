/**
 * draw_shadow_node.js
 * A bespoke, procedural rendering of a cybernetic "Shadow Node".
 * Engineered with luxury gold aesthetics and isometric geometric faceting
 * on a transparent 128x128 HD canvas.
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
  const W = 128, H = 128;

  console.log("Initiating bridge link...");
  try {
    await fetch(`${BRIDGE_URL}/health`);
  } catch (e) {
    console.error("ERROR: Pixelorama bridge offline. Focus the window and try again.");
    process.exit(1);
  }

  console.log(`Allocating transparent ${W}x${W} canvas...`);
  await cmd("create_canvas", { width: W, height: H, name: "Shadow Node Core" });

  // 1. The Luxury Gold Palette
  const palette = {
    gold_specular: "#fff3cc", // Piercing white-gold highlight
    gold_high:     "#e6c27a", // Bright sunlit gold
    gold_mid:      "#cda434", // The core luxury gold base
    gold_shadow:   "#8b6508", // Warm, dark ambient gold
    gold_deep:     "#3e2700", // Almost black, rich brown-gold for deepest creases
    obsidian:      "#141414", // Deep carbon
    obsidian_edge: "#2a2a2a", // Chipped carbon edge
    outline:       "#050505"  // Absolute black
  };

  const pixels = [];
  const grid = new Array(W * H).fill(null);

  // 2. Procedural Geometry: The Faceted Octahedron
  const CX = Math.floor(W / 2);
  const CY = Math.floor(H / 2) - 15; // Shifted slightly up
  const SIZE = 40;

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      
      // Node Core Math (Isometric Diamond / Octahedron profile)
      // We scale the Y axis to give it that tilted, 3D RPG perspective
      const dx = Math.abs(x - CX);
      const dy = Math.abs(y - CY);
      
      if (dx / 0.85 + dy / 1.3 <= SIZE) {
        let color = palette.gold_mid;

        // 3D Lighting & Faceting Logic
        // We split the shape into 4 distinct quadrants to simulate a sharp, chiseled crystal
        const isLeft = x < CX;
        const isTop = y < CY;

        // Light source originating from top-right
        if (isTop && !isLeft) color = palette.gold_specular; // Direct hit
        if (isTop && isLeft) color = palette.gold_high;      // Ambient catch
        if (!isTop && !isLeft) color = palette.gold_shadow;  // Core shadow
        if (!isTop && isLeft) color = palette.gold_deep;     // Deepest ambient occlusion

        // Add a dark, pulsating cyber-core inside the gold shell
        if (dx / 0.85 + dy / 1.3 < SIZE * 0.45) {
           color = palette.obsidian;
           // Algorithmic circuitry pattern inside the core
           if (Math.sin(x * 0.6) * Math.cos(y * 0.6) > 0.4) {
               color = palette.gold_specular;
           }
        }

        // Inner structural wireframes
        if (Math.abs(x - CX) < 1 || Math.abs(y - CY) < 1) {
            color = palette.gold_deep;
        }

        // Strict Perimeter Outline
        if (dx / 0.85 + dy / 1.3 > SIZE - 1.5) {
          color = palette.outline;
        }

        grid[y * W + x] = color;
      }
      
      // 3. The Obsidian Data Pedestal (Floating below the node)
      const p_dx = Math.abs(x - CX);
      const p_dy = y - (H - 25);
      
      // Draw an angled, high-tech platform
      if (p_dy > 0 && p_dy < 12) {
          // Taper the platform inwards as it goes down
          const widthAtDepth = 35 - (p_dy * 2.5);
          if (p_dx < widthAtDepth) {
              // Top edge highlight
              if (p_dy < 2) grid[y * W + x] = palette.gold_shadow;
              // Left side light catch
              else if (x < CX - widthAtDepth + 2) grid[y * W + x] = palette.obsidian_edge;
              // Core block
              else grid[y * W + x] = palette.obsidian;
              
              // Pedestal outline
              if (p_dx >= widthAtDepth - 1 || p_dy === 11) {
                  grid[y * W + x] = palette.outline;
              }
          }
      }
    }
  }

  // 4. Algorithmic Data Particles (Vibe coding atmosphere)
  // Random, scattered gold bits orbiting the core
  for(let i = 0; i < 45; i++) {
     const px = CX + Math.floor((Math.random() - 0.5) * 110);
     const py = CY + Math.floor((Math.random() - 0.5) * 110);
     
     // Only place particles in empty space
     if(px >= 0 && px < W && py >= 0 && py < H && grid[py * W + px] === null) {
         grid[py * W + px] = Math.random() > 0.7 ? palette.gold_specular : palette.gold_shadow;
     }
  }

  // 5. Extract and Stream
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] !== null) {
        pixels.push({ x, y, color: grid[y * W + x] });
      }
    }
  }

  console.log(`Compiled ${pixels.length} HD pixels. Deploying to canvas...`);
  
  // Safe batching protocol
  const BATCH_SIZE = 1500;
  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    const batch = pixels.slice(i, i + BATCH_SIZE);
    await cmd("draw_pixels", { pixels: batch });
    process.stdout.write(`\rProgress: ${Math.min(i + BATCH_SIZE, pixels.length)} / ${pixels.length} transmitted...`);
  }
  
  console.log("\nNode rendering complete. Centering viewport.");
  await cmd("fit_viewport");
}

main();
