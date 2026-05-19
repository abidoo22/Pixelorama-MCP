/**
 * draw_carrot.js
 * Draws a breathtaking, highly detailed 3D pixel-art carrot with rich leafy foliage
 * and horizontal texture ridges on a fully transparent 64x64 canvas via the pix-MCP bridge.
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

// Distance from point to line segment helper for drawing organic shapes
function getDistanceToSegment(x, y, x1, y1, x2, y2) {
  const A = x - x1;
  const B = y - y1;
  const C = x2 - x1;
  const D = y2 - y1;

  const dot = A * C + B * D;
  const lenSq = C * C + D * D;
  let param = -1;
  if (lenSq !== 0) param = dot / lenSq;

  let xx, yy;

  if (param < 0) {
    xx = x1;
    yy = y1;
  } else if (param > 1) {
    xx = x2;
    yy = y2;
  } else {
    xx = x1 + param * C;
    yy = y1 + param * D;
  }

  const dx = x - xx;
  const dy = y - yy;
  return {
    dist: Math.hypot(dx, dy),
    t: param // Parametric position along the line [0, 1]
  };
}

async function main() {
  const W = 64, H = 64;

  console.log("Connecting to Pixelorama REST Bridge...");
  try {
    const health = await fetch(`${BRIDGE_URL}/health`).then(r => r.json());
    console.log(`Connected to Pixelorama ${health.pixelorama_version} successfully!`);
  } catch (e) {
    console.error("ERROR: Cannot connect to Pixelorama. Make sure the server is open.");
    process.exit(1);
  }

  console.log("Creating new transparent 64x64 canvas...");
  const canvasRes = await cmd("create_canvas", {
    width: W,
    height: H,
    name: "Golden Carrot"
  });

  if (!canvasRes.success) {
    console.error("Failed to create canvas:", canvasRes.error);
    process.exit(1);
  }

  // 1. Color Palette Definitions
  const palette = {
    // Carrot Body (Orange)
    orange_high:    "#ffd685", // Sunlit warm gold-orange highlight
    orange_light:   "#ffaa2b", // Light carrot orange
    orange_mid:     "#ff6f00", // Rich core carrot orange
    orange_shadow:  "#cc4700", // Deep warm red-orange shadow
    orange_deep:    "#8c2400", // Ultra dark red shadow (creases)
    
    // Foliage Leaves (Green)
    green_high:     "#b3f03b", // Sunlit bright lime-green highlight
    green_mid:      "#4d9e18", // Lush vibrant leaf green
    green_shadow:   "#1b5c09", // Deep shaded leaf green
    green_deep:     "#0e3b04", // Dark shadowed base green

    // Outline
    outline:        "#260800"  // Dark blackish-brown organic outline
  };

  const pixels = [];
  const grid = new Array(W * H).fill(null);

  // 2. Carrot Body Geometry (Tapering tilted cone)
  // Top Center of the Carrot Body: (38, 24)
  // Bottom Tip of the Carrot Body: (24, 52)
  const BX1 = 38, BY1 = 24;
  const BX2 = 24, BY2 = 52;

  // 3. Foliage Leaves Geometry (3 primary leafy stalks branching out from the crown)
  // Crowns roots sprout at BX1, BY1
  const stalks = [
    { x1: BX1, y1: BY1 - 2, x2: 20, y2: 10, w: 2.2 }, // Spreading left
    { x1: BX1, y1: BY1 - 2, x2: 38, y2: 6,  w: 2.5 }, // Pointing straight up
    { x1: BX1, y1: BY1 - 2, x2: 50, y2: 13, w: 2.0 }  // Spreading right
  ];

  // Draw Leaf Foliage onto grid
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      // Check each leaf stalk
      for (const stalk of stalks) {
        const seg = getDistanceToSegment(x, y, stalk.x1, stalk.y1, stalk.x2, stalk.y2);
        
        // Define variable leaf width (tapers towards the tips)
        const stalkWidth = stalk.w * (1 - seg.t * 0.4);
        
        // Add natural organic leaf clusters (sinusoidal puffiness along the branch)
        const wave = Math.sin(seg.t * 12) * 2.0;
        const leafRadius = stalkWidth + Math.max(0, wave) * (seg.t > 0.1 ? 1 : 0.2);

        if (seg.dist <= leafRadius && seg.t >= 0 && seg.t <= 1) {
          // Shading leaf clusters: top-left highlights, bottom-right shadows
          const dx = x - (stalk.x1 + seg.t * (stalk.x2 - stalk.x1));
          const dy = y - (stalk.y1 + seg.t * (stalk.y2 - stalk.y1));
          const dot = -0.7 * dx - 0.7 * dy;

          let color = palette.green_mid;
          if (dot > 0.8) {
            color = palette.green_high;
          } else if (dot < -0.6) {
            color = palette.green_shadow;
          }
          
          // Outer outline for the foliage
          if (seg.dist > leafRadius - 0.8) {
            color = palette.green_deep;
          }

          // Write green leaves to grid
          grid[y * W + x] = color;
        }
      }
    }
  }

  // Draw Carrot Orange Body onto grid
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const seg = getDistanceToSegment(x, y, BX1, BY1, BX2, BY2);
      
      // Variable radius along the carrot body segment (linear taper from 11px to 1px)
      const radius = 10.5 * (1 - seg.t * 0.92);

      if (seg.dist <= radius && seg.t >= 0 && seg.t <= 1) {
        // Outline check (perimeter pixels)
        if (seg.dist > radius - 1.0) {
          grid[y * W + x] = palette.outline;
          continue;
        }

        // Calculate directional shading (3D cylindrical lighting)
        // Light source is at top-left, perpendicular to the tilted segment
        const segmentAngle = Math.atan2(BY2 - BY1, BX2 - BX1);
        const normalAngle = segmentAngle + Math.PI / 2;
        
        const px = x - (BX1 + seg.t * (BX2 - BX1));
        const py = y - (BY1 + seg.t * (BY2 - BY1));
        
        // Dot product with normal vector
        const dot = (px * Math.cos(normalAngle) + py * Math.sin(normalAngle)) / (seg.dist || 1);
        
        let color = palette.orange_mid;

        if (dot < -0.55) {
          color = palette.orange_high;   // Glowing Highlight
        } else if (dot < -0.1) {
          color = palette.orange_light;  // Light orange face
        } else if (dot > 0.6) {
          color = palette.orange_deep;   // Deep warm ambient shadow
        } else if (dot > 0.25) {
          color = palette.orange_shadow; // Mid shadow side
        }

        // Add detailed horizontal texture ridges (indents along the carrot length)
        // We create 4 organic horizontal rings at t = 0.2, 0.45, 0.68, 0.85
        const ridgeSpacing = Math.sin(seg.t * 18 + x * 0.15);
        if (Math.abs(ridgeSpacing) < 0.18 && seg.t > 0.08 && seg.t < 0.9) {
          // Inner groove shadow
          color = (dot > -0.1) ? palette.orange_deep : palette.orange_shadow;
        }

        grid[y * W + x] = color;
      }
    }
  }

  // Draw leafy stem joints (base connection crown)
  for (let y = BY1 - 2; y <= BY1 + 1; y++) {
    for (let x = BX1 - 3; x <= BX1 + 3; x++) {
      const dx = x - BX1;
      const dy = y - BY1;
      if (Math.hypot(dx, dy) < 3.2) {
        grid[y * W + x] = palette.green_shadow;
      }
    }
  }

  // Collect and stream final pixels
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const color = grid[y * W + x];
      if (color !== null) {
        pixels.push({ x, y, color });
      }
    }
  }

  console.log(`Streaming ${pixels.length} procedural carrot pixels...`);
  
  // Send in one fast optimized batch
  const res = await cmd("draw_pixels", { pixels });
  
  if (res.success) {
    console.log("Golden Carrot drawn successfully! Centering viewport...");
    await cmd("fit_viewport");
    console.log("Done!");
  } else {
    console.error("Error drawing pixels:", res.error);
  }
}

main();
