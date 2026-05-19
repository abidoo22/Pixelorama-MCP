/**
 * draw_apple.js
 * Draws a beautiful shiny red apple with a green leaf and a drop shadow
 * on a 64x64 canvas, utilizing procedural shading and pixel batching.
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
  const W = 64, H = 64;

  console.log("Creating 64x64 canvas named 'Apple'...");
  await cmd("create_canvas", { width: W, height: H, name: "Apple" });

  const palette = {
    red_specular: "#ffffff", // Pure white highlight
    red_high: "#ff4d4d",     // Bright shiny red
    red_mid: "#e60000",      // Core apple red
    red_shadow: "#990000",   // Dark ambient red
    red_deep: "#4d0000",     // Deepest crease shadow
    leaf_high: "#88cc00",    // Sunlit leaf
    leaf_mid: "#4d9900",     // Base green
    leaf_shadow: "#264d00",  // Leaf shadow
    stem: "#4a2e00",         // Brown stem
    shadow: "#0c0c0e",       // Playbook drop shadow
    outline: "#1a0000"       // Dark outline
  };

  const grid = new Array(W * H).fill(null);

  // 1. Draw Apple Body (Procedural Overlapping Spheres with Bottom Taper)
  const L_CX = 26, L_CY = 34, R_CX = 38, R_CY = 34, RAD = 17;

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const dl = Math.hypot(x - L_CX, y - L_CY);
      const dr = Math.hypot(x - R_CX, y - R_CY);
      
      // Pull the bottom inwards to create the classic apple shape
      const bottomTaper = (y > 34) ? (y - 34) * 0.25 : 0;

      if (dl < RAD - bottomTaper || dr < RAD - bottomTaper) {
        // Top-left light source for specular lighting
        const lightDist = Math.hypot(x - 24, y - 20);

        let color = palette.red_mid;
        if (lightDist < 4) color = palette.red_specular;
        else if (lightDist < 12) color = palette.red_high;
        else if (lightDist > 28) color = palette.red_deep;
        else if (lightDist > 20) color = palette.red_shadow;

        grid[y * W + x] = color;
      }
    }
  }

  // 2. Draw Stem (Curved bezier-like segment)
  for (let y = 16; y <= 22; y++) {
    const x = 32 + Math.floor((22 - y) * 0.35); 
    grid[y * W + x] = palette.stem;
    grid[y * W + x + 1] = palette.stem;
  }

  // 3. Draw Leaf (Rotated Ellipse)
  const LEAF_CX = 40, LEAF_CY = 18;
  for (let y = 8; y < 26; y++) {
    for (let x = 32; x < 52; x++) {
      const dx = x - LEAF_CX;
      const dy = y - LEAF_CY;
      
      // Rotate coordinates for the leaf angle
      const angle = Math.PI / -5; 
      const rx = dx * Math.cos(angle) - dy * Math.sin(angle);
      const ry = dx * Math.sin(angle) + dy * Math.cos(angle);

      if ((rx * rx) / 64 + (ry * ry) / 12 <= 1) {
        let color = palette.leaf_mid;
        if (rx < 0 && ry < 0) color = palette.leaf_high;
        else if (rx > 0 && ry > 0) color = palette.leaf_shadow;
        grid[y * W + x] = color;
      }
    }
  }

  // 4. Playbook Drop Shadow (Offset +3, +3)
  const shadowGrid = new Array(W * H).fill(null);
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] !== null) {
        const sx = x + 3;
        const sy = y + 3;
        if (sx < W && sy < H && grid[sy * W + sx] === null) {
          shadowGrid[sy * W + sx] = palette.shadow;
        }
      }
    }
  }

  // Merge drop shadows into the main grid
  for (let i = 0; i < W * H; i++) {
    if (shadowGrid[i] !== null && grid[i] === null) {
      grid[i] = shadowGrid[i];
    }
  }

  // 5. Automatic Outlining (Playbook perimeter check)
  const finalGrid = [...grid];
  for (let y = 1; y < H - 1; y++) {
    for (let x = 1; x < W - 1; x++) {
      const current = finalGrid[y * W + x];
      // Do not outline the drop shadow itself
      if (current !== null && current !== palette.shadow && current !== palette.outline) {
        if (!finalGrid[(y-1)*W + x] || !finalGrid[(y+1)*W + x] || !finalGrid[y*W + (x-1)] || !finalGrid[y*W + (x+1)]) {
          grid[y * W + x] = palette.outline;
        }
      }
    }
  }

  // 6. Extract and Batch Stream to Pixelorama
  const pixels = [];
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] !== null) {
        pixels.push({ x, y, color: grid[y * W + x] });
      }
    }
  }

  console.log(`Streaming ${pixels.length} pixels in batches...`);
  
  const BATCH_SIZE = 400; // Optimal batch size from the Playbook
  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    const batch = pixels.slice(i, i + BATCH_SIZE);
    await cmd("draw_pixels", { pixels: batch });
  }
  
  console.log("Apple drawn successfully! Centering viewport...");
  await cmd("fit_viewport");
}

main();
