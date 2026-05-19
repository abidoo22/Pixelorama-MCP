/**
 * draw_man.js
 * Draws a gorgeous, highly detailed pixel-art muscular man with white skin and yellow hair on a 128x128 canvas.
 * Implements procedural high-fidelity muscle shading, detailed heroic facial features, and spiky hair.
 */

const BRIDGE_URL = "http://127.0.0.1:7373";
const BATCH_SIZE = 500; // max pixels per draw_pixels call

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

// Helper to check if a point (x, y) is inside a polygon
function inPoly(px, py, vertices) {
  let collision = false;
  for (let i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
    const vc = vertices[i], vn = vertices[j];
    if (((vc.y > py) !== (vn.y > py)) && (px < (vn.x - vc.x) * (py - vc.y) / (vn.y - vc.y) + vc.x)) {
      collision = !collision;
    }
  }
  return collision;
}

async function main() {
  const W = 128, H = 128;

  // 1. Health check
  const health = await fetch(`${BRIDGE_URL}/health`).then(r => r.json());
  console.log("Bridge:", health.status, "| Pixelorama:", health.pixelorama_version);

  // 2. Create canvas
  console.log("Creating canvas 128x128...");
  await cmd("create_canvas", { width: W, height: H, name: "Muscular Hero" });

  // 3. Fill background with a premium dark synthwave purple/indigo
  console.log("Filling background...");
  await cmd("fill_area", { x: 0, y: 0, color: "#141226" });

  // Palette definition
  const colors = {
    outline:      "#180d05",
    skin_light:   "#ffe5d0",
    skin_mid:     "#f5c2a3",
    skin_shadow:  "#d48c6a",
    skin_deep:    "#9e543b",
    hair_light:   "#fff5c0",
    hair_mid:     "#fcd116",
    hair_shadow:  "#c79600",
    hair_deep:    "#855a00",
    eye_blue:     "#3fa2f7",
    eye_white:    "#ffffff",
    mouth_red:    "#8c3327",
    shadow:       "#07060d"
  };

  const grid = new Array(W * H).fill(null);

  // Light source position for muscle shading (top-left)
  const LX = 20, LY = 20;

  // Geometry definition of muscle groups
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      // 1. HEAD & JAW
      const dx_head = x - 64;
      const dy_head = y - 56;
      const insideHeadEllipse = Math.pow(dx_head / 18, 2) + Math.pow(dy_head / 20, 2) <= 1.0;
      
      const jawVertices = [
        { x: 46, y: 56 },
        { x: 64, y: 82 }, // Chin tip
        { x: 82, y: 56 }
      ];
      const insideJaw = inPoly(x, y, jawVertices);
      const isSkinFace = insideHeadEllipse || insideJaw;

      // 2. NECK
      const insideNeck = (x >= 51 && x <= 77 && y >= 70 && y <= 98);

      // 3. TRAPEZIUS (Traps)
      const leftTrap = [
        { x: 51, y: 76 },
        { x: 54, y: 95 },
        { x: 26, y: 102 }
      ];
      const rightTrap = [
        { x: 77, y: 76 },
        { x: 74, y: 95 },
        { x: 102, y: 102 }
      ];
      const isTrap = inPoly(x, y, leftTrap) || inPoly(x, y, rightTrap);

      // 4. DELTOIDS (Shoulders)
      const insideLeftDeltoid = Math.pow((x - 22) / 16, 2) + Math.pow((y - 116) / 22, 2) <= 1.0;
      const insideRightDeltoid = Math.pow((x - 106) / 16, 2) + Math.pow((y - 116) / 22, 2) <= 1.0;
      const isDeltoid = insideLeftDeltoid || insideRightDeltoid;

      // 5. CHEST (Pectorals)
      const insideLeftPec = Math.pow((x - 46) / 20, 2) + Math.pow((y - 110) / 16, 2) <= 1.0;
      const insideRightPec = Math.pow((x - 82) / 20, 2) + Math.pow((y - 110) / 16, 2) <= 1.0;
      const isChest = insideLeftPec || insideRightPec;

      // Skin aggregate
      if (isSkinFace || insideNeck || isTrap || isDeltoid || isChest) {
        // Base skin color calculations with dynamic muscle shading
        let val = 0.5; // neutral

        if (isSkinFace) {
          // Face lighting (spherical + linear)
          const distToLight = Math.hypot(x - LX, y - LY);
          val = 1.0 - (distToLight / 110);
        } 
        else if (insideNeck) {
          // Neck shading (has a shadow cast from chin at y=76 to y=86)
          if (y < 86) {
            val = 0.15; // Chin shadow
          } else {
            val = 0.6 - ((x - LX) / 140);
          }
        } 
        else if (isTrap) {
          // Trap shading
          val = 0.55 - ((x - LX) / 130) + ((y - 80) * 0.002);
        }
        else if (isDeltoid) {
          // Deltoid curve shading (spherical)
          const cx = (x < 64) ? 22 : 106;
          const dist = Math.hypot(x - cx, y - 116);
          val = 0.7 - (dist / 32) - ((x - LX) * 0.001);
        }
        else if (isChest) {
          // Pec highlights and bottom shadow creases
          const cx = (x < 64) ? 46 : 82;
          const dist = Math.hypot(x - cx, y - 110);
          val = 0.75 - (dist / 24) - ((x - LX) * 0.001);
          // Strong shadow crease at the bottom of pecs (y > 115)
          if (y > 114) {
            val -= 0.25;
          }
        }

        // Apply skin color palette based on shading value
        let col = colors.skin_mid;
        if (val > 0.70) {
          col = colors.skin_light;
        } else if (val > 0.48) {
          col = colors.skin_mid;
        } else if (val > 0.30) {
          col = colors.skin_shadow;
        } else {
          col = colors.skin_deep;
        }

        grid[y * W + x] = col;
      }
    }
  }

  // 6. HAIR GEOMETRY (Yellow Hair)
  // Hair base circles and spiky polygons
  const hairSpikes = [
    // Top central spike
    [{ x: 56, y: 38 }, { x: 64, y: 16 }, { x: 72, y: 38 }],
    // Top left spike
    [{ x: 46, y: 42 }, { x: 48, y: 22 }, { x: 58, y: 36 }],
    // Top right spike
    [{ x: 70, y: 36 }, { x: 80, y: 24 }, { x: 82, y: 42 }],
    // Far left spike
    [{ x: 38, y: 50 }, { x: 34, y: 34 }, { x: 48, y: 44 }],
    // Far right spike
    [{ x: 80, y: 44 }, { x: 94, y: 34 }, { x: 90, y: 50 }],
    // Extra dramatic spikes
    [{ x: 50, y: 30 }, { x: 56, y: 12 }, { x: 62, y: 30 }],
    [{ x: 66, y: 30 }, { x: 72, y: 14 }, { x: 78, y: 30 }]
  ];

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      // Main hair mass
      const dx_hair = x - 64;
      const dy_hair = y - 44;
      const inMainHair = Math.pow(dx_hair / 24, 2) + Math.pow(dy_hair / 16, 2) <= 1.0;
      
      let inSpike = false;
      for (const spike of hairSpikes) {
        if (inPoly(x, y, spike)) {
          inSpike = true;
          break;
        }
      }

      if (inMainHair || inSpike) {
        // Shading based on light source direction (top-left)
        const dx = x - 48;
        const dy = y - 30;
        const dist = Math.hypot(dx, dy);
        const val = 1.0 - (dist / 65);

        let col = colors.hair_mid;
        if (val > 0.72) {
          col = colors.hair_light;
        } else if (val > 0.45) {
          col = colors.hair_mid;
        } else if (val > 0.25) {
          col = colors.hair_shadow;
        } else {
          col = colors.hair_deep;
        }

        grid[y * W + x] = col;
      }
    }
  }

  // 7. HEROIC FACIAL FEATURES (Eyes, brows, nose, mouth)
  // Determined eyebrows (y = 50, x=51 to 59, x=69 to 77)
  const drawLine = (x0, y0, x1, y1, col) => {
    const dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    const dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    let err = dx + dy;
    while (true) {
      if (x0 >= 0 && x0 < W && y0 >= 0 && y0 < H) {
        grid[y0 * W + x0] = col;
      }
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  };

  // Determined heroic eyebrows (V-shape)
  drawLine(50, 52, 59, 55, colors.hair_deep); // Left brow
  drawLine(78, 52, 69, 55, colors.hair_deep); // Right brow
  
  // Left eye
  grid[54 * W + 53] = colors.eye_white;
  grid[54 * W + 54] = colors.eye_blue;
  grid[54 * W + 55] = colors.eye_white;
  grid[55 * W + 54] = colors.outline; // Pupil/eyeline

  // Right eye
  grid[54 * W + 73] = colors.eye_white;
  grid[54 * W + 74] = colors.eye_blue;
  grid[54 * W + 75] = colors.eye_white;
  grid[55 * W + 74] = colors.outline; // Pupil/eyeline

  // Nose shadow & bridge (y = 54 to 65)
  drawLine(63, 56, 63, 65, colors.skin_deep); // Nose bridge left
  grid[65 * W + 62] = colors.skin_deep; // Nose tip
  grid[65 * W + 63] = colors.skin_deep;
  grid[65 * W + 64] = colors.skin_shadow;

  // Heroic, serious mouth (y = 71)
  drawLine(59, 72, 69, 72, colors.outline);
  grid[73 * W + 64] = colors.mouth_red; // Subtle lip tone below

  // Stern jaw line & chin shadow definition
  drawLine(46, 56, 64, 82, colors.skin_deep);
  drawLine(82, 56, 64, 82, colors.skin_deep);

  // Muscle definition creases
  // Collarbones
  drawLine(52, 98, 38, 102, colors.skin_deep);
  drawLine(76, 98, 90, 102, colors.skin_deep);
  // Pectoral split (sternum)
  drawLine(64, 98, 64, 116, colors.skin_deep);
  // Deltoid-pec crease
  drawLine(34, 104, 38, 118, colors.skin_deep);
  drawLine(94, 104, 90, 118, colors.skin_deep);

  // 8. DROP SHADOW GENERATION
  const shadowPixels = [];
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] !== null) {
        const sx = x + 4, sy = y + 4;
        if (sx < W && sy < H && grid[sy * W + sx] === null) {
          shadowPixels.push({ x: sx, y: sy, color: colors.shadow });
        }
      }
    }
  }

  // 9. OUTLINE & FINAL ASSEMBLY
  const heroPixels = [];
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] === null) continue;
      
      // Determine if this pixel is a border of the figure
      let isBorder = false;
      for (let dy = -1; dy <= 1 && !isBorder; dy++) {
        for (let dx = -1; dx <= 1 && !isBorder; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= W || ny < 0 || ny >= H || grid[ny * W + nx] === null) {
            isBorder = true;
          }
        }
      }

      heroPixels.push({
        x,
        y,
        color: isBorder ? colors.outline : grid[y * W + x]
      });
    }
  }

  // 10. Execute drawing commands
  console.log(`Drawing drop shadow (${shadowPixels.length} px)...`);
  await drawPixelsBatched(shadowPixels);

  console.log(`Drawing muscular hero body (${heroPixels.length} px)...`);
  await drawPixelsBatched(heroPixels);

  console.log("\n✅ Muscular Man complete!");
}

main().catch(e => { console.error("Fatal:", e); process.exit(1); });
