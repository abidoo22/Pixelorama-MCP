/**
 * draw_fnf.js
 * Procedurally draws a stylized "Boyfriend" from Friday Night Funkin'
 * performing on a Luxury Gold Cyber-Stage using the pix-MCP bridge.
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

  console.log("Dropping the beat... Connecting to bridge...");
  try {
    await fetch(`${BRIDGE_URL}/health`);
  } catch (e) {
    console.error("ERROR: Pixelorama bridge offline. Focus the window!");
    process.exit(1);
  }

  await cmd("create_canvas", { width: W, height: H, name: "FNF Cyber Stage" });

  const palette = {
    // Stage (Luxury Gold & Obsidian)
    obsidian: "#0a0a0a",
    obsidian_light: "#1a1a1a",
    gold_high: "#f3e5ab",
    gold_mid: "#d4af37",
    gold_dark: "#8b6508",
    
    // Boyfriend Base
    skin: "#ffccb6",
    skin_shadow: "#d99c82",
    hair: "#31b0d1",
    hair_shadow: "#1a7c96",
    hat: "#dd2138",
    hat_brim: "#1e2e4f",
    shirt: "#f9f9f9",
    shirt_shadow: "#c2c2c2",
    pants: "#43588e",
    shoes: "#dd2138",
    mic_head: "#a3a3a3",
    mic_body: "#2a2a2a",
    outline: "#000000"
  };

  const grid = new Array(W * H).fill(null);
  const pixels = [];

  // Helper function to draw circles
  function drawCircle(cx, cy, r, color, outlineColor = null) {
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < W; x++) {
        const dist = Math.hypot(x - cx, y - cy);
        if (dist <= r) {
          if (outlineColor && dist > r - 1.2) grid[y * W + x] = outlineColor;
          else grid[y * W + x] = color;
        }
      }
    }
  }

  // Helper function to draw rects
  function drawRect(x1, y1, x2, y2, color, outlineColor = null) {
    for (let y = y1; y <= y2; y++) {
      for (let x = x1; x <= x2; x++) {
        if (x >= 0 && x < W && y >= 0 && y < H) {
          if (outlineColor && (x === x1 || x === x2 || y === y1 || y === y2)) {
             grid[y * W + x] = outlineColor;
          } else {
             grid[y * W + x] = color;
          }
        }
      }
    }
  }

  // 1. GENERATE BACKGROUND: Luxury Gold Cyber-Stage
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (y > 90) {
        // Stage Floor: Reflective grid
        const perspectiveX = Math.abs(x - W/2) / (y - 85);
        if (y % 8 === 0 || perspectiveX % 1.5 < 0.2) {
          grid[y * W + x] = palette.gold_dark;
        } else {
          grid[y * W + x] = palette.obsidian_light;
        }
      } else {
        // Backwall: Obsidian
        grid[y * W + x] = palette.obsidian;
      }
    }
  }

  // 2. GENERATE EQUALIZERS (Audio Bars)
  const eqWidth = 6;
  const eqSpacing = 4;
  for (let x = 10; x < W - 10; x += eqWidth + eqSpacing) {
    // Symmetric random height for the bars
    const distFromCenter = Math.abs(x - W/2);
    const height = Math.floor(Math.sin(x * 0.5) * 20 + 30 - (distFromCenter * 0.3));
    
    if (height > 0) {
      for (let y = 90 - height; y <= 90; y++) {
        // Gold gradient based on height
        let color = palette.gold_dark;
        if (y < 90 - height + 5) color = palette.gold_high;
        else if (y < 90 - height + 15) color = palette.gold_mid;
        
        // Bar gaps
        if (y % 3 !== 0) {
          for (let w = 0; w < eqWidth; w++) {
            grid[y * W + (x + w)] = color;
          }
        }
      }
    }
  }

  // 3. GENERATE BOYFRIEND (Stylized Procedural Shapes)
  const CX = 64;
  const CY = 60;

  // Pants (Baggy rectangles)
  drawRect(CX - 12, CY + 20, CX - 2, CY + 35, palette.pants, palette.outline); // Left Leg
  drawRect(CX + 2, CY + 20, CX + 14, CY + 35, palette.pants, palette.outline);  // Right Leg

  // Shoes (Red blobs)
  drawCircle(CX - 8, CY + 37, 5, palette.shoes, palette.outline);
  drawCircle(CX + 10, CY + 37, 5, palette.shoes, palette.outline);

  // Shirt (White torso)
  drawRect(CX - 10, CY + 2, CX + 10, CY + 22, palette.shirt, palette.outline);
  // Red prohibition sign on shirt (simplified)
  drawCircle(CX, CY + 12, 4, palette.hat);
  drawCircle(CX, CY + 12, 2, palette.shirt);
  drawRect(CX - 3, CY + 11, CX + 3, CY + 13, palette.hat);

  // Head (Skin base)
  drawCircle(CX, CY - 15, 12, palette.skin, palette.outline);

  // Hair (Cyan spikes - Procedural triangles)
  for (let y = CY - 30; y < CY - 5; y++) {
    for (let x = CX - 22; x < CX + 20; x++) {
      const dx = x - CX;
      const dy = y - (CY - 15);
      // Math to create spiky hair pattern
      if (Math.hypot(dx, dy) < 18 && Math.sin(x * 1.5) > 0.2) {
        grid[y * W + x] = palette.hair;
      }
    }
  }

  // Hat (Red cap worn backward)
  drawCircle(CX + 5, CY - 22, 9, palette.hat, palette.outline);
  // Brim (Blue sticking out the back)
  drawRect(CX + 12, CY - 20, CX + 18, CY - 18, palette.hat_brim, palette.outline);

  // Arm & Hand holding Mic
  drawRect(CX + 8, CY + 5, CX + 18, CY + 9, palette.skin, palette.outline); // Arm
  drawCircle(CX + 20, CY + 7, 4, palette.skin, palette.outline); // Hand

  // Microphone
  drawCircle(CX + 24, CY + 3, 4, palette.mic_head, palette.outline); // Mic Head
  drawRect(CX + 22, CY + 6, CX + 26, CY + 14, palette.mic_body, palette.outline); // Handle

  // 4. BATCH & STREAM TO PIXELORAMA
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] !== null) {
        pixels.push({ x, y, color: grid[y * W + x] });
      }
    }
  }

  console.log(`Compiled ${pixels.length} pixels! Executing payload...`);
  
  const BATCH_SIZE = 1500;
  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    const batch = pixels.slice(i, i + BATCH_SIZE);
    await cmd("draw_pixels", { pixels: batch });
    process.stdout.write(`\rProgress: ${Math.min(i + BATCH_SIZE, pixels.length)} / ${pixels.length} pixels drawn...`);
  }
  
  console.log("\nFriday Night Funkin' draw complete! Centering viewport...");
  await cmd("fit_viewport");
}

main();
