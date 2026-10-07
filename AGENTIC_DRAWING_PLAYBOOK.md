# 📚 Agentic Drawing Playbook
### How to Draw Pixel Art with Pixelorama-MCP — For AI Agents & Developer Scripts

This guide is written for **AI agents and autonomous scripts** connecting to Pixelorama-MCP. Follow it and your first draw attempt will produce high-quality results.

---

## 1. The Core Drawing Pipeline

Always execute drawing tasks in this exact order:

```
1. Health check         → GET /health
2. Create canvas        → create_canvas
3. Compute geometry     → in memory (no API calls yet)
4. Compute shading      → in memory
5. Compute outlines     → in memory (or call apply_outline)
6. Flush pixels         → draw_pixels_fast (flat array, 0.02ms/px) or draw_pixels (object array)
7. Procedural textures  → eval_gdscript (cellular automata, noise, fractal foliage)
8. Visual inspection    → capture_canvas_image (multimodal vision feedback)
9. Fit viewport         → fit_viewport
10. Export to Godot     → export_godot_spriteframes / export_godot_tileset
```

> 💡 **Background Execution:** With Pixelorama-MCP's dedicated background thread, Pixelorama processes drawing and export commands even when minimized or running in the background.

> ⚡ **Performance Recommendation:** Always prefer `draw_pixels_fast` with a flat array (`[x,y,col, ...]`) for dense drawing. It executes in engine memory at ~0.02 ms/pixel—over 100× faster than individual calls. For object arrays (`[{x,y,color}, ...]`), use `draw_pixels`.

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

### Option A: Ultra-Fast Flat Array (`draw_pixels_fast` — Recommended)
```javascript
const W = 64, H = 64;
const grid = new Array(W * H).fill(null); // null = transparent

function px(x, y, color) {
  if (x >= 0 && x < W && y >= 0 && y < H)
    grid[y * W + x] = color;
}

// ... fill the grid with all your geometry ...

// Flush flat array at ~0.02ms/pixel
async function flushFast(grid, W, H) {
  const flatData = [];
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const col = grid[y * W + x];
      if (col !== null) flatData.push(x, y, col);
    }
  }

  const STRIDE = 3;
  const CHUNK_SIZE = 15000 * STRIDE;
  for (let i = 0; i < flatData.length; i += CHUNK_SIZE) {
    await cmd("draw_pixels_fast", { data: flatData.slice(i, i + CHUNK_SIZE) });
  }
}
```

### Option B: Object Array (`draw_pixels`)
```javascript
async function flushObjects(grid, W, H) {
  const pixels = [];
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++)
      if (grid[y * W + x] !== null)
        pixels.push({ x, y, color: grid[y * W + x] });

  for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
    await cmd("draw_pixels", { pixels: pixels.slice(i, i + BATCH_SIZE) });
  }
}
```

---

## 3B. In-Engine Procedural Scripting (`eval_gdscript`)

For high-density mathematical textures, cellular automata caves, noise fields, and procedural foliage, run GDScript dynamically in-engine:

```javascript
await cmd("eval_gdscript", {
  code: `
    var noise = FastNoiseLite.new()
    noise.seed = 1337
    noise.frequency = 0.05
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var val = noise.get_noise_2d(x, y)
            if val > 0.1:
                image.set_pixel(x, y, Color("#2b5329"))
            else:
                image.set_pixel(x, y, Color("#1a2b18"))
    return {"status": "noise_field_complete"}
  `,
  params: { seed: 1337 }
});
```

### Multi-Layer Sampling & Reflections (Water / Mirrors)
Use `api.get_layer_image(layer_name)` to sample underlying layers directly without reimplementing shaders:

```javascript
await cmd("eval_gdscript", {
  layer: "Lake",
  code: `
    func run(api, image: Image, project, params: Dictionary):
        var sky_img = api.get_layer_image("Sky")
        for y in range(image.get_height()):
            var sample_y = clamp(image.get_height() - y - 1, 0, sky_img.get_height() - 1)
            for x in range(image.get_width()):
                var sky_col = sky_img.get_pixel(x, sample_y)
                image.set_pixel(x, y, sky_col.darkened(0.25))
        return "reflection_rendered"
  `
});
```

### Bulk Image Assignment (Ultra-Fast Full-Canvas Generation — 0.001ms/px)
Instead of executing 57,600+ `image.set_pixel()` calls in nested loops (which has high overhead), construct and return a `PackedByteArray` or `Image` directly. Pixelorama blits the entire buffer into engine memory in $< 0.1$ ms:

#### Option 1: Raw Bytes with `PackedByteArray` (Recommended for Complex Math/Dithering)
```javascript
await cmd("eval_gdscript", {
  code: `
    func run(api, image: Image, project, params: Dictionary) -> PackedByteArray:
        var w: int = image.get_width()
        var h: int = image.get_height()
        var buf := PackedByteArray()
        buf.resize(w * h * 4) # 4 bytes per pixel: R, G, B, A

        # Example: Dithered sky / lake gradient
        var bay: Array = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for y in range(h):
            for x in range(w):
                var idx: int = (y * w + x) * 4
                var dth: int = (bay[y % 4][x % 4] - 8) * 2
                buf[idx]     = clampi(15 + dth, 0, 255)  # R
                buf[idx + 1] = clampi(35 + dth, 0, 255)  # G
                buf[idx + 2] = clampi(75 + dth, 0, 255)  # B
                buf[idx + 3] = 255                       # A (opaque)
        return buf
  `
});
```

#### Option 2: Returning a newly created `Image` (Auto-Adapts Canvas Dimensions)
```javascript
await cmd("eval_gdscript", {
  code: `
    func run(api, image: Image, project, params: Dictionary) -> Image:
        var w: int = int(project.size.x)
        var h: int = int(project.size.y)
        var new_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
        new_img.fill(Color("#05070f"))
        return new_img
  `
});
```

> ⚠️ **CRITICAL RULE — Canvas Size & Restart Safety:**
> When Pixelorama restarts, the active canvas resets to the default **64×64**.
> - **Always call `create_canvas(width, height)`** at the start of your drawing session before issuing procedural scripts.
> - Or check `var sz = api.get_canvas_size()` inside your script.
> - In v2.4+, all `image.set_pixel()` and `image.get_pixel()` calls are **transparently bounds-checked** in-engine so out-of-bounds writes will safely clip and report a diagnostic warning rather than ever crashing the engine.

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

---

## 10. End-to-End Godot 4 Game Asset Pipeline

AI agents can draw sprites, inspect them visually, and export directly into a Godot game project as ready-to-use native resources:

### A. Exporting Animated Character Sprites to Godot:
```javascript
// 1. Draw your animation frames across timeline (frame 0, frame 1, frame 2...)
// 2. Visually verify with capture_canvas_image
// 3. Export directly into the Godot project folder
await cmd("export_godot_spriteframes", {
  target_dir: "/path/to/godot_project/assets/characters/",
  sprite_name: "knight",
  animation_name: "walk",
  fps: 8,
  loop: true
});
// Creates: knight_walk_0000.png, knight_walk_0001.png, ..., and knight_walk_frames.tres
// In Godot: Attach knight_walk_frames.tres to an AnimatedSprite2D node!
```

### B. Creating and Exporting Tilemaps to Godot:
```javascript
// 1. Create a 4x4 grid of 16x16 tiles
await cmd("create_tileset_canvas", { tile_size: 16, columns: 4, rows: 4, name: "Dungeon" });

// 2. Draw terrain tiles (walls, floors, corners) in the specified tile coordinates
// ...

// 3. Export directly into the Godot project folder
await cmd("export_godot_tileset", {
  target_dir: "/path/to/godot_project/assets/tilesets/",
  tileset_name: "dungeon_tiles",
  tile_size: 16
});
// Creates: dungeon_tiles.png and dungeon_tiles.tres
// In Godot: Assign dungeon_tiles.tres to the TileSet property of a TileMap or TileMapLayer node!
```
