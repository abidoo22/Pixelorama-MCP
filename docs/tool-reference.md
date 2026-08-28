# 🛠️ pix-MCP Tool Reference

All MCP tools exposed by pix-MCP. They communicate via HTTP REST on `localhost:7373` to control Pixelorama v1.1.10 programmatically.

**Quick rule:** Use `draw_pixels` (batch) for all drawing — never `draw_pixel` in a loop.

---

## Categories
1. [Canvas & Project](#1-canvas--project)
2. [Drawing & Painting](#2-drawing--painting)
3. [Layers](#3-layers)
4. [Animation & Frames](#4-animation--frames)
5. [Color & Palettes](#5-color--palettes)
6. [Selections & Transforms](#6-selections--transforms)
7. [AI Helpers](#7-ai-helpers)

---

## 1. Canvas & Project

### `create_canvas`
Creates a new project tab in Pixelorama.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `width` | number | ✅ | Canvas width in pixels |
| `height` | number | ✅ | Canvas height in pixels |
| `name` | string | — | Project tab name |

```json
{ "success": true, "data": { "width": 64, "height": 64, "name": "Golden Coin" } }
```

---

### `get_canvas_info`
Returns dimensions, layers, and frame count of the active project.

```json
{
  "success": true,
  "data": {
    "width": 64, "height": 64,
    "layers": ["Layer 1"],
    "frames_count": 1,
    "current_frame": 0
  }
}
```

---

### `save_project`
Saves the active project to a `.pxo` file.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | ✅ | Absolute path (e.g. `/home/user/project.pxo`) |

```json
{ "success": true }
```

---

### `export_image`
Exports a specific frame of the canvas as a PNG image.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | ✅ | Absolute path for output PNG |
| `frame` | number | — | Frame index (default: `0`) |

```json
{ "success": true, "data": { "path": "/home/user/output.png", "format": "png" } }
```

---

### `get_canvas_snapshot`
Returns pixel data for a region of the canvas as a compact color-indexed grid.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `x` | number | `0` | Top-left X coordinate |
| `y` | number | `0` | Top-left Y coordinate |
| `width` | number | `32` | Width of snapshot region (max 128) |
| `height` | number | `32` | Height of snapshot region (max 128) |

```json
{
  "success": true,
  "data": {
    "x": 0,
    "y": 0,
    "width": 32,
    "height": 32,
    "colors": ["00000000", "ffd700ff"],
    "grid": [[0, 0, 1, 0], [0, 1, 1, 1]]
  }
}
```

---

### `fit_viewport`
Centers and fits the canvas in the Pixelorama viewport. Always call this at the end of a drawing sequence.

```json
{ "success": true }
```

---

## 2. Drawing & Painting

### `draw_pixels` ⭐ Primary drawing tool
Draws multiple pixels in a single batch. **Always use this — never loop `draw_pixel`.**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `pixels` | array | ✅ | Array of `{ x, y, color }` objects |

Each pixel object:
- `x` — X coordinate (0-indexed)
- `y` — Y coordinate (0-indexed)
- `color` — hex color string (`"#ffd700"`)

```json
{ "success": true, "data": { "drawn": 1500, "skipped": 0 } }
```

> `skipped > 0` means some coordinates were out of bounds for the canvas. Check your geometry bounds if this happens.

---

### `draw_pixel`
Draws a single pixel. Only use for one-off corrections — never in a loop.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x` | number | ✅ | X coordinate |
| `y` | number | ✅ | Y coordinate |
| `color` | string | — | Hex color (default: `"#000000"`) |

---

### `draw_rect`
Draws a filled or outlined rectangle.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x` | number | ✅ | Top-left X |
| `y` | number | ✅ | Top-left Y |
| `width` | number | ✅ | Width in pixels |
| `height` | number | ✅ | Height in pixels |
| `color` | string | — | Hex color (default: `"#000000"`) |
| `filled` | boolean | — | `true` = filled (default), `false` = outline only |

---

### `draw_ellipse`
Draws a filled or outlined ellipse or circle.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `cx` | number | ✅ | Center X |
| `cy` | number | ✅ | Center Y |
| `rx` | number | ✅ | X radius |
| `ry` | number | ✅ | Y radius |
| `color` | string | — | Hex color (default: `"#000000"`) |
| `filled` | boolean | — | `true` = filled (default), `false` = outline only |

---

### `draw_line`
Draws a straight line using Bresenham's algorithm.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x1`, `y1` | number | ✅ | Start point |
| `x2`, `y2` | number | ✅ | End point |
| `color` | string | — | Hex color (default: `"#000000"`) |

---

### `draw_polygon`
Draws a polygon from a vertex array.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `points` | array | ✅ | `[{"x": 10, "y": 12}, ...]` (min 3) |
| `color` | string | — | Hex color (default: `"#000000"`) |
| `filled` | boolean | — | `true` = filled (default), `false` = outline only |

---

### `draw_path`
Draws a continuous polyline connecting ordered points.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `points` | array | ✅ | Ordered `[{"x": 10, "y": 12}, ...]` coordinates (min 2) |
| `closed` | boolean | — | If `true`, closes path back to start (default: `false`) |
| `color` | string | — | Hex color (default: `"#000000"`) |

---

### `fill_area`
Flood-fills from a seed coordinate (paint bucket).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x` | number | ✅ | Seed X |
| `y` | number | ✅ | Seed Y |
| `color` | string | — | Fill color (default: `"#000000"`) |

---

## 3. Layers

Pixelorama supports multi-layer projects. Use layers to separate background, body, outline, and effects — especially useful when game engines need to manipulate parts independently.

### `add_layer`
Adds a new layer to the current project.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | string | `""` | Layer name (empty for auto-naming) |
| `type` | number | `0` | `0` = Pixel, `1` = Group, `2` = 3D |
| `above_layer` | number | — | Insert above this layer index (defaults to current layer) |

```json
{ "success": true, "data": { "name": "Outline", "type": 0, "above_layer": 0 } }
```

---

### `get_layers`
Lists all layers with index, name, visibility, locked state, opacity, blend mode, and type.

---

### `delete_layer`
Deletes a layer by index.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `index` | number | ✅ | 0-indexed layer to delete |

---

### `set_layer_opacity`
Sets the opacity of a layer.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `index` | number | ✅ | Target layer index |
| `opacity` | number | ✅ | `0.0` (transparent) to `1.0` (opaque) |

---

### `set_layer_blend_mode`
Sets the blend mode of a layer.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `index` | number | ✅ | Target layer index |
| `blend_mode` | number | ✅ | Enum value `0`–`21` (e.g. `0` = Normal, `1` = Erase, `2` = Darken, `3` = Multiply, `4` = Color Burn, `7` = Screen, `10` = Overlay) |

---

### `set_layer_visibility`
Shows or hides a layer.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `index` | number | ✅ | Target layer index |
| `visible` | boolean | ✅ | `true` to show, `false` to hide |

---

## 4. Animation & Frames

### `get_frames`
Lists all frames with index, duration multiplier, and cel count.

---

### `get_fps` / `set_fps`
Gets or sets playback speed in frames per second.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `fps` | number | ✅ (set only) | Frames per second (e.g. `8`, `12`, `24`) |

---

### `add_frame`
Appends a blank frame to the animation timeline.

| Parameter | Type | Description |
|---|---|---|
| `after_frame` | number | Insert after this frame index (default: current frame) |

---

### `delete_frame`
Deletes a frame by index (cannot delete the only remaining frame).

| Parameter | Type | Description |
|---|---|---|
| `index` | number | Frame index to delete (default: current frame) |

---

### `duplicate_frame`
Deep-copies all layer pixel data of a frame into a new frame.

| Parameter | Type | Description |
|---|---|---|
| `index` | number | Frame index to duplicate (default: current frame) |

---

### `set_frame_duration`
Sets duration multiplier of a frame.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `index` | number | — | Frame index (default: current frame) |
| `duration` | number | ✅ | Multiplier (`1.0` = normal speed, `2.0` = half speed) |

---

### `switch_frame`
Switches the active frame for drawing.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `index` | number | ✅ | Frame index to switch to |

---

### `switch_cel` / `copy_cel` / `clear_cel`
Fine-grained control over individual layer × frame cels.

- **`switch_cel`**: `{ frame: number, layer: number }`
- **`copy_cel`**: `{ src_frame: number, src_layer: number, dst_frame: number, dst_layer: number }`
- **`clear_cel`**: `{ frame?: number, layer?: number }`

---

### `export_animation`
Exports animation frames as individual PNG files or packed into a spritesheet.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `path` | string | — | Directory path to export into |
| `prefix` | string | `"frame"` | Filename prefix (e.g. `"walk"`) |
| `mode` | string | `"frames"` | `"frames"` (individual PNGs) or `"spritesheet"` |
| `columns` | number | — | Spritesheet columns (only for `"spritesheet"`) |
| `start_frame` | number | `0` | First frame to export (only for `"frames"`) |
| `end_frame` | number | last | Last frame to export (only for `"frames"`) |

---

## 5. Color & Palettes

### `set_color`
Sets active foreground or background drawing color.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `color` | string | — | Hex color string (e.g. `"#ff0055"`) |
| `button` | number | `0` | `0` = foreground (left click), `1` = background (right click) |

---

### `get_color`
Returns current foreground and background colors.
```json
{ "foreground": "#ffffff", "background": "#000000" }
```

---

### `get_palette_colors`
Returns all swatches and dimensions of the active palette.

---

### `create_palette`
Creates a new palette in Pixelorama.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | Palette name |
| `width` | number | `8` | Palette width |
| `height` | number | `8` | Palette height |
| `is_global` | boolean | `true` | Save globally (`true`) or to project (`false`) |

---

### `add_palette_color` / `set_palette_color`
- **`add_palette_color`**: `{ color: string }`
- **`set_palette_color`**: `{ index: number, color: string }`

---

## 6. Selections

### `select_rect`
Selects a rectangular region on canvas.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `x` | number | — | Top-left X |
| `y` | number | — | Top-left Y |
| `width` | number | — | Selection width |
| `height` | number | — | Selection height |
| `operation` | number | `0` | `0` = add, `1` = subtract, `2` = intersect |

---

### `select_all`
Selects the entire canvas area.

---

### `deselect`
Clears the current selection.

---

## 7. AI Helpers

### `describe_canvas`
Reads canvas dimensions, layers, frames, and an indexed pixel snapshot.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `snapshot_width` | number | `32` | Snapshot width (max 64) |
| `snapshot_height` | number | `32` | Snapshot height (max 64) |

---

### `suggest_palette`
Suggests a color palette based on a keyword theme or lists all built-in palettes.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `theme` | string | — | Mood or style keyword (e.g. `"nes"`, `"gameboy"`, `"pico8"`, `"forest"`, `"retro"`) |
| `list_all` | boolean | `false` | If `true`, lists all available built-in palettes |

---

### `generate_sprite`
Generates a structured, step-by-step drawing plan for an AI agent to execute using `draw_pixels`, `draw_line`, etc.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `description` | string | — | What to draw (e.g. `"a golden coin with a star"`) |
| `width` | number | `16` | Canvas width |
| `height` | number | `16` | Canvas height |
| `style` | string | `"pico8"` | Palette style key |
| `animated` | boolean | `false` | Include multi-frame animation guidance |
| `frames` | number | `4` | Number of animation frames |
