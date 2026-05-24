# 📚 Agentic Drawing Playbook
### How to Draw Pixel Art with pix-MCP — For AI Agents & Developer Scripts

This guide is written for **AI agents and autonomous scripts** connecting to pix-MCP. Follow it and your first draw attempt will produce high-quality results.

---

## 1. The Core Drawing Pipeline

Always execute drawing tasks in this exact order:

```
1. Health check         → GET /health
2. Create canvas        → create_canvas
3. Compute geometry     → in memory (no API calls yet)
4. Compute shading      → in memory
5. Compute outlines     → in memory
6. Flush pixels         → draw_pixels (batched)
7. Fit viewport         → fit_viewport
```

> ⚠️ **Pixelorama must be visible on screen and not minimized.** Godot throttles its process loop when hidden. If the window is minimized, drawing commands will hang indefinitely.

> ⛔ **Never call `draw_pixel` one at a time in a loop.** Always use `draw_pixels` with a batch array. A single `draw_pixels` call with 15,000 pixels is approximately 15,000× faster than individual calls.

---

## 2. Canvas Setup

```javascript
const BRIDGE_URL = "http://127.0.0.1:7373";
const BATCH_SIZE = 15000; // safe maximum for any canvas size

async function cmd(tool, params = {}) {
  const res = await fetch(`${BRIDGE_URL}/command`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool, params }),
  });
  const data = await res.json();
  if (!data.success) console.error(`FAILED [${tool}]:`, data.error);
  return data;
}

// Health check first — always
const health = await fetch(`${BRIDGE_URL}/health`).then(r => r.json());
console.log("Bridge:", health.status, "| Pixelorama:", health.pixelorama_version);

// Create canvas — no background fill for transparent sprites
await cmd("create_canvas", { width: 96, height: 128, name: "My Sprite" });

// OR with a dark background for icon/item sprites
await cmd("create_canvas", { width: 64, height: 64, name: "Coin" });
await cmd("fill_area", { x: 0, y: 0, color: "#191a21" });
```

---

## 3. The In-Memory Grid Pattern

**All pixel color decisions happen in memory first.** Never call drawing tools while computing geometry. Build the full grid, then flush once.

```javascript
const W = 64, H = 64;
const grid = new Array(W * H).fill(null); // null = transparent

// Helper to write to grid safely
function px(x, y, color) {
  if (x >= 0 && x < W && y >= 0 && y < H)
    grid[y * W + x] = color;
}

// ... fill the grid with all your geometry ...

// Flush: collect non-null pixels and send in batches
async function flush(grid, W, H) {
  const pixels = [];
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++)
      if (grid[y * W + x] !== null)
        pixels.push({ x, y, color: grid[y * W + x] });

  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    await cmd("draw_pixels", { pixels: pixels.slice(i, i + BATCH_SIZE) });
    process.stdout.write(`  ${i + BATCH_SIZE > pixels.length ? pixels.length : i + BATCH_SIZE}/${pixels.length}\r`);
  }
  console.log();
}
```

---

## 4. Geometry & Shading Recipes

### A. Beveled Circular Rims (Coins, Shields, Medals)

Light source is always **top-left** for consistency across sprites.

```javascript
const CX = 32, CY = 32;
const R_OUTER = 22; // outer rim edge
const R_RIM   = 17; // inner rim edge (crease)
const R_INNER = 16; // inner face starts here

for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    const dx = x - CX, dy = y - CY;
    const r = Math.hypot(dx, dy);
    if (r > R_OUTER) continue;

    // Dot product with top-left light vector (-0.7, -0.7)
    const light = r > 0 ? (-0.7 * dx - 0.7 * dy) / r : 0;

    if (r >= R_RIM) {
      // Outer beveled rim — normal lighting
      if      (light > 0.4)  px(x, y, "#fff6b0"); // highlight
      else if (light > 0.0)  px(x, y, "#fcd116"); // light gold
      else if (light > -0.5) px(x, y, "#f39c12"); // mid gold
      else                   px(x, y, "#b87300"); // shadow gold
    } else if (r >= R_INNER) {
      // Crease — INVERTED lighting to show depth
      if      (light > 0.2)  px(x, y, "#7a4b00"); // shadow on highlight side
      else if (light > -0.3) px(x, y, "#b87300");
      else                   px(x, y, "#fcd116"); // highlight on shadow side
    } else {
      // Inner face — subtle radial gradient
      const radialLight = light - 0.3 * (r / R_INNER);
      if      (radialLight > 0.45) px(x, y, "#fff6b0");
      else if (radialLight > 0.1)  px(x, y, "#fcd116");
      else if (radialLight > -0.3) px(x, y, "#f39c12");
      else if (radialLight > -0.7) px(x, y, "#b87300");
      else                         px(x, y, "#7a4b00");
    }
  }
}
```

### B. Five-Pointed Star (RPG Icons, Medals, UI)

```javascript
function inStar(x, y, cx, cy, rOuter, rInner) {
  const dx = x - cx, dy = y - cy;
  const r = Math.hypot(dx, dy);
  if (r > rOuter) return false;
  if (r < rInner) return true;

  // Rotate so a point faces upward (12 o'clock)
  const angle = Math.atan2(dy, dx) + Math.PI / 2;
  const norm  = ((angle % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI);

  const seg  = (2 * Math.PI) / 5;
  const half = seg / 2;
  const loc  = norm % seg;

  const dist = loc < half
    ? rOuter * (1 - loc / half)      + rInner * (loc / half)
    : rInner * (1 - (loc - half) / half) + rOuter * ((loc - half) / half);

  return r <= dist;
}

// Usage with per-facet shading
const STAR_OUTER = 9, STAR_INNER = 4;
for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    if (!inStar(x, y, CX, CY, STAR_OUTER, STAR_INNER)) continue;
    const seg = (2 * Math.PI) / 5;
    const angle = ((Math.atan2(y - CY, x - CX) + Math.PI / 2) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI);
    const localAngle = angle % seg;
    // Left facet = highlight, right facet = shadow
    px(x, y, localAngle < seg / 2 ? "#fffbda" : "#d68a00");
    // Tiny center specular
    if (Math.hypot(x - CX, y - CY) < 2) px(x, y, "#fff6b0");
  }
}
```

### C. Automatic Outlines

Run this **after** all geometry is in the grid, **before** flushing. Any filled pixel adjacent to a transparent pixel becomes an outline pixel.

```javascript
function applyOutline(grid, W, H, outlineColor = "#0e0d12") {
  const outlined = [...grid]; // copy
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] === null) continue;
      let isBorder = false;
      outer: for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= W || ny < 0 || ny >= H || grid[ny * W + nx] === null) {
            isBorder = true; break outer;
          }
        }
      }
      if (isBorder) outlined[y * W + x] = outlineColor;
    }
  }
  return outlined;
}
```

### D. Drop Shadow

Compute shadow **before** drawing the main body so body pixels naturally overwrite shadow overlap.

```javascript
function buildDropShadow(grid, W, H, offsetX = 3, offsetY = 3, shadowColor = "#0c0c0e") {
  const shadow = [];
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (grid[y * W + x] === null) continue;
      const sx = x + offsetX, sy = y + offsetY;
      if (sx < W && sy < H && grid[sy * W + sx] === null)
        shadow.push({ x: sx, y: sy, color: shadowColor });
    }
  }
  return shadow;
}

// Draw shadow first, then main body
const shadowPixels = buildDropShadow(grid, W, H);
await flush(shadowPixels); // direct array, not grid
const outlinedGrid = applyOutline(grid, W, H);
await flush(outlinedGrid, W, H); // grid version
```

### E. Seeded Pseudo-Random Noise (Camo, Textures, Grain)

Use this for consistent, reproducible patterns — same seed = same pattern every run.

```javascript
function seededRand(x, y, seed = 37) {
  let n = x * 374761393 + y * 1103515245 + seed;
  n = (n ^ (n >> 13)) * 1664525;
  return ((n ^ (n >> 7)) & 0x7fffffff) / 0x7fffffff;
}

// Example: camo pattern on pants
for (let y = pantsTop; y < pantsBottom; y++) {
  for (let x = pantsLeft; x < pantsRight; x++) {
    if (grid[y * W + x] === null) continue;
    const n = seededRand(x, y, 13);
    if      (n < 0.18) px(x, y, "#2A3018"); // dark blob
    else if (n < 0.32) px(x, y, "#3A4528"); // mid blob
    else if (seededRand(x + 7, y + 3, 29) < 0.12) px(x, y, "#6A6040"); // tan highlight
  }
}
```

---

## 5. Batching & Performance

The bridge plugin's GDScript handler caches color hex parsing: each unique color string is parsed **once per batch**, regardless of how many times it appears. This gives up to 20,000× speedup over repeated parses.

| Canvas size | Pixels | Recommended BATCH_SIZE |
|---|---|---|
| 32×32 | 1,024 | Send all at once |
| 64×64 | 4,096 | Send all at once |
| 128×128 | 16,384 | 15,000 |
| 256×256 | 65,536 | 15,000 |
| 512×512 | 262,144 | 15,000 |

**Group same-color pixels together** in your batch array — the color cache is most effective when identical hex values appear in contiguous sequence.

Every `draw_pixels` call is a **single undo step** in Pixelorama — pressing `Ctrl+Z` undoes the entire batch cleanly.

---

## 6. Layer Strategy for Complex Sprites

Use multiple layers to keep parts independent (useful for game engine assembly):

```javascript
// Layer 0 (default) — background / shadow
await cmd("draw_pixels", { pixels: shadowPixels });

// Layer 1 — body
await cmd("add_layer", { name: "Body" });
// (new layer becomes active automatically)
await cmd("draw_pixels", { pixels: bodyPixels });

// Layer 2 — outline & details
await cmd("add_layer", { name: "Outline" });
await cmd("draw_pixels", { pixels: outlinePixels });
```

**Recommended layer order for characters:**
- Layer 0: Drop shadow
- Layer 1: Body fill
- Layer 2: Clothing / gear
- Layer 3: Outlines & details

Separating trunk from foliage (or legs from torso) lets you scale parts independently in the game engine without redrawing.

---

## 7. Handling `skipped` Pixels

The `draw_pixels` response includes a `skipped` count:
```json
{ "success": true, "data": { "drawn": 1498, "skipped": 2 } }
```
`skipped` means those coordinates were out-of-bounds for the current canvas. If `skipped > 0`, check that your geometry coordinates don't exceed `W-1` / `H-1`. For large characters, increase canvas size or clamp coordinates.

---

## 8. Finishing Up

Always end with a viewport fit so the user immediately sees the result:
```javascript
await cmd("fit_viewport", {});
```

Optional — export PNG automatically:
```javascript
await cmd("export_image", { path: "/home/user/output.png" });
```

---

## 9. Troubleshooting

**Connection refused on port 7373**
- PixMcpBridge extension must be enabled in Pixelorama → Edit → Preferences → Extensions
- Pixelorama must be open and not minimized
- Check if the extension was quarantined: see [plugin-setup.md](docs/plugin-setup.md)

**Drawing is very slow / commands hang**
- Pixelorama is minimized — bring it to the foreground
- You may be calling `draw_pixel` individually — switch to `draw_pixels` batching

**Extension disappeared from preferences after a crash**
- Pixelorama quarantined it — see [plugin-setup.md](docs/plugin-setup.md) for the fix
- Clean start command:
```bash
pkill -9 -f Pixelorama || true
rm -f ~/.local/share/pixelorama/.running
/path/to/Pixelorama.x86_64 --rendering-driver opengl3 --single-window &
```
