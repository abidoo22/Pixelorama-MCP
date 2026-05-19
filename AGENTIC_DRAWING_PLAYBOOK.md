# 📚 Agentic Drawing Playbook: How to Draw with pix-MCP & Pixelorama

Welcome! This guide is designed for AI agents and developer subagents to learn how to interact with **pix-MCP** and **Pixelorama** to draw breathtaking pixel art assets on the very first try.

---

## 🚀 1. The Core Drawing Pipeline

To draw any high-fidelity pixel art asset, always structure your drawing agent or script following this exact sequence:

1. **Verify Health:** Make sure the local HTTP bridge is running by querying `GET http://127.0.0.1:7373/health`.
2. **Create Canvas:** Call the `create_canvas` tool with specific dimensions (e.g. `64x64`, `128x128`) and a descriptive asset name.
3. **Fill Background:** Fill the canvas with a solid, premium dark background color (e.g., `#191a21` carbon grey-blue or `#141226` dark synthwave purple) using `fill_area` or let it remain transparent.
4. **Compute Geometry & Shading (Locally):** Loop through your coordinate grid and determine the color of each pixel based on lighting vectors, curves, and shapes. Keep all outline, body, highlight, and shadow calculations in-memory.
5. **Draw Batched Pixels:** Send the final pixel list to Pixelorama in batches to minimize HTTP roundtrips.
6. **Focus & Zoom:** Simulate OS window focus and trigger the viewport center/fit shortcuts to showcase the completed canvas.

---

## 🎨 2. Geometry, Outlining, & Shading Recipes

### A. Perfectly Beveled Circular Rims (e.g., Coins, Shields)
Use a polar/distance-based calculation to render concentric circles with beveled highlights and shadows (assuming light source is **top-left**):

```javascript
const CX = 32, CY = 32; // Center
const R_OUTER = 22;     // Outer boundary
const R_INNER = 18;     // Inner boundary

for (let y = 0; y < 64; y++) {
  for (let x = 0; x < 64; x++) {
    const dx = x - CX;
    const dy = y - CY;
    const r = Math.hypot(dx, dy);

    if (r <= R_OUTER && r >= R_INNER) {
      // Shading vector pointing towards top-left light source
      const light = -0.7 * (dx / r) - 0.7 * (dy / r);

      if (light > 0.4) {
        grid[y * W + x] = "#fff6b0"; // Highlight (bright yellow)
      } else if (light > 0.0) {
        grid[y * W + x] = "#fcd116"; // Light gold
      } else if (light > -0.5) {
        grid[y * W + x] = "#f39c12"; // Mid gold
      } else {
        grid[y * W + x] = "#b87300"; // Shadow gold
      }
    }
  }
}
```

### B. Procedural Star Math (e.g., RPG Icons, Medals)
A robust function to determine if a pixel lies within a classic 5-pointed star:

```javascript
function inStar(x, y, cx, cy, rOuter, rInner) {
  const dx = x - cx;
  const dy = y - cy;
  const r = Math.hypot(dx, dy);
  if (r > rOuter) return false;
  if (r < rInner) return true;

  const angle = Math.atan2(dy, dx);
  const normAngle = angle < 0 ? angle + 2 * Math.PI : angle;
  
  const segment = (2 * Math.PI) / 5;
  const halfSegment = segment / 2;
  const localAngle = normAngle % segment;
  
  let dist = localAngle < halfSegment
    ? rOuter * (1 - (localAngle / halfSegment)) + rInner * (localAngle / halfSegment)
    : rInner * (1 - ((localAngle - halfSegment) / halfSegment)) + rOuter * ((localAngle - halfSegment) / halfSegment);
  
  return r <= dist;
}
```

### C. Automatic Outlines
Any colored pixel adjacent to an empty (`null`) pixel is considered a border and should be outlined with a dark, high-contrast outline color (e.g., `#281605` or `#0e0d12`):

```javascript
const finalPixels = [];
for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    if (grid[y * W + x] === null) continue;
    let isBorder = false;
    for (let dy = -1; dy <= 1 && !isBorder; dy++) {
      for (let dx = -1; dx <= 1 && !isBorder; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= W || ny < 0 || ny >= H || grid[ny * W + nx] === null) {
          isBorder = true;
        }
      }
    }
    finalPixels.push({
      x,
      y,
      color: isBorder ? colors.outline : grid[y * W + x]
    });
  }
}
```

### D. Cozy Drop Shadows
Generate a realistic offset shadow (offset `+3` on x-axis, `+3` on y-axis) directly behind the object:

```javascript
const shadowPixels = [];
for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    if (grid[y * W + x] !== null) {
      const sx = x + 3;
      const sy = y + 3;
      if (sx < W && sy < H && grid[sy * W + sx] === null) {
        shadowPixels.push({ x: sx, y: sy, color: "#0c0c0e" });
      }
    }
  }
}
```

---

## ⚡ 3. Drawing Optimization & Batching

To prevent Godot HTTP connection overhead and keep drawing execution under **2 seconds**, always batch your pixel drawing calls:

* **GDScript Color Cache:** The bridge plugin features a built-in `color_cache` dictionary. Color hex parsing is only executed **once per unique color in a batch**, reducing string parsing operations by over 20,000x!
* **Group by Color:** When compiling coordinates, group pixels with the same color together in your array payload. This ensures that the engine only executes a single string validation parse per unique hex key.
* **Optimal Batch Sizes:**
  - For small canvases (e.g. 64x64 or less), send all pixels in a single batch.
  - For large canvases (e.g. 128x128 to 1024x1024), split the drawing payload into chunks of **`15,000` pixels per request** (e.g., `BATCH_SIZE = 15000` in Node/Python).
* **Single Commit:** The `draw_pixels` tool processes the array in a single undo step inside Pixelorama, ensuring that pressing `Ctrl+Z` undoes the entire object cleanly!

---

## 🔎 4. Focusing, Zooming, and Fitting Viewport

Always automate viewport centering so that the user immediately sees the masterpiece:

1. **Focus Pixelorama Window:** Focus the active window ID in X11 or OS window manager.
2. **Close menus:** Simulate pressing `Escape` twice to clear any accidental dropdowns.
3. **Fit to Frame:** Simulate pressing `f` (or `Home` key) to center the current canvas, or call the native `fit_viewport` REST command.
4. **Zoom Box:** To zoom to custom levels, click the zoom input box at top toolbar coordinates `x=660, y=50`, clear the field, type a zoom value (e.g., `400`), and hit `Return`.

---

## 🛠️ 5. Troubleshooting & Maintenance

If you run into connection refused errors on port `7373`, follow this diagnostic checklist:

### 1. Check for Quarantined Extensions
Pixelorama has an automatic safety system: if it encounters a compilation/runtime error in an extension, it flags it as **"Faulty"** and immediately moves it out of the active `extensions/` directory into a hidden directory:
* Active Path: `/home/abido/.local/share/pixelorama/extensions/`
* Quarantine Path: `/home/abido/.local/share/pixelorama/give_in_bug_report/`

**Fix:** Delete any files in `give_in_bug_report/`, compile a clean PCK using the pack script, and copy it back to the active extensions directory.

### 2. Clean Start Command (Single Window Bypass)
When Godot crashes or is force-killed, on next startup it pops up a modal alert window: *"Restore crash session?"*. This modal blocks the REST loop until it is clicked.
**Fix:** Launch Pixelorama with the `--single-window` flag so the alert stays in the main window, wait for it to load, and send X11 Escape keys to clear it:
```bash
pkill -9 -f Pixelorama || true
rm -f /home/abido/.local/share/pixelorama/.running
export DISPLAY=:0
nohup /home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.x86_64 --rendering-driver opengl3 --single-window > /home/abido/Downloads/pix-MCP/pix_live.log 2>&1 &
```

### 3. Rebuild Extensions
Always compile the GDScript package with Godot's pack script to package and copy changes:
```bash
/home/abido/Downloads/Godot_v4.6.2-stable_linux.x86_64 --headless -s pack.gd
```

