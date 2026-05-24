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
Exports the active frame as PNG.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | ✅ | Absolute path for output PNG |
| `frame_idx` | number | — | Frame index (default: current frame) |

```json
{ "success": true, "data": { "path": "/home/user/output.png", "format": "png" } }
```

---

### `get_canvas_snapshot`
Returns a base64-encoded PNG of the current canvas. Useful for agents to inspect progress.

```json
{ "success": true, "data": { "base64": "iVBORw0KGgoAAAANSUhEUgAAAD..." } }
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
| `color` | string | — | Hex color (default: active color) |

---

### `draw_rect`
Draws a filled or outlined rectangle.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x` | number | ✅ | Top-left X |
| `y` | number | ✅ | Top-left Y |
| `width` | number | ✅ | Width in pixels |
| `height` | number | ✅ | Height in pixels |
| `color` | string | — | Hex color |
| `fill` | boolean | — | `true` = filled (default), `false` = outline only |

---

### `draw_ellipse`
Draws a filled or outlined ellipse or circle.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x` | number | ✅ | Center X |
| `y` | number | ✅ | Center Y |
| `rx` | number | ✅ | X radius |
| `ry` | number | ✅ | Y radius |
| `color` | string | — | Hex color |
| `fill` | boolean | — | `true` = filled (default) |

---

### `draw_line`
Draws a straight line using Bresenham's algorithm.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x0`, `y0` | number | ✅ | Start point |
| `x1`, `y1` | number | ✅ | End point |
| `color` | string | — | Hex color |
| `width` | number | — | Line width in pixels (default: 1) |

---

### `draw_polygon`
Draws a polygon from a vertex array.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `vertices` | array | ✅ | `[{"x": 10, "y": 12}, ...]` |
| `color` | string | — | Hex color |
| `fill` | boolean | — | `true` = filled (default) |

---

### `draw_path`
Draws a continuous polyline connecting ordered points.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `points` | array | ✅ | Ordered `[{x, y}, ...]` coordinates |
| `color` | string | — | Hex color |

---

### `fill_area`
Flood-fills from a seed coordinate (paint bucket).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x` | number | ✅ | Seed X |
| `y` | number | ✅ | Seed Y |
| `color` | string | — | Fill color |

---

## 3. Layers

Pixelorama supports multi-layer projects. Use layers to separate background, body, outline, and effects — especially useful when game engines need to manipulate parts independently.

### `add_layer`
Adds a new layer on top of the stack.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | string | ✅ | Layer name |

```json
{ "success": true, "data": { "layer_idx": 1, "name": "Outline" } }
```

---

### `delete_layer`

| Parameter | Type | Required | Description |
|---|---|---|---|
| `layer_idx` | number | ✅ | 0-indexed layer to delete |

---

### `set_layer_opacity`

| Parameter | Type | Required | Description |
|---|---|---|---|
| `layer_idx` | number | ✅ | Target layer |
| `opacity` | number | ✅ | `0.0` (transparent) to `1.0` (opaque) |

---

### `set_layer_blend_mode`

| Parameter | Type | Required | Description |
|---|---|---|---|
| `layer_idx` | number | ✅ | Target layer |
| `blend_mode` | string | ✅ | See modes below |

Available blend modes: `Normal`, `Multiply`, `Screen`, `Overlay`, `Darken`, `Lighten`, `Color Dodge`, `Color Burn`, `Difference`, `Exclusion`, `Hue`, `Saturation`, `Color`, `Luminosity`

---

### `set_layer_visibility`

| Parameter | Type | Required | Description |
|---|---|---|---|
| `layer_idx` | number | ✅ | Target layer |
| `visible` | boolean | ✅ | Show or hide |

---

## 4. Animation & Frames

### `add_frame`
Appends a blank frame to the animation timeline.

### `delete_frame`

| Parameter | Type | Required |
|---|---|---|
| `frame_idx` | number | ✅ |

### `duplicate_frame`
Copies a frame (all layers) to a new position.

| Parameter | Type | Required |
|---|---|---|
| `frame_idx` | number | ✅ |

### `set_frame_duration`

| Parameter | Type | Required | Description |
|---|---|---|---|
| `frame_idx` | number | ✅ | Target frame |
| `duration` | number | ✅ | Duration multiplier (default: `1.0`) |

### `switch_frame`
Sets the active viewport frame.

| Parameter | Type | Required |
|---|---|---|
| `frame_idx` | number | ✅ |

### `get_fps` / `set_fps`

| Parameter | Type | Required |
|---|---|---|
| `fps` | number | ✅ (set only) |

### `switch_cel` / `copy_cel` / `clear_cel`
Fine-grained control over individual layer×frame cels.

| Parameter | Type | Required |
|---|---|---|
| `layer_idx` | number | ✅ |
| `frame_idx` | number | ✅ |

### `export_animation`
Exports all frames as PNGs or a spritesheet.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | ✅ | Output folder or file path |
| `mode` | string | ✅ | `"frames"` or `"spritesheet"` |
| `columns` | number | — | Spritesheet columns (default: 8) |

---

## 5. Color & Palettes

### `set_color`

| Parameter | Type | Required | Description |
|---|---|---|---|
| `color` | string | ✅ | Hex color (e.g. `"#ff0055"`) |
| `is_secondary` | boolean | — | `true` = right-click color |

### `get_assigned_color`
Returns current foreground and background colors.
```json
{ "foreground": "#ffffff", "background": "#000000" }
```

### `create_palette`

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | string | ✅ | Palette name |
| `width` / `height` | number | — | Swatch grid dimensions |
| `is_global` | boolean | — | Available across projects |

### `get_palette_colors` / `add_palette_color` / `set_palette_color`
Read and modify swatches in the active palette.

---

## 6. Selections & Transforms

### `select_rect` / `select_ellipse`

| Parameter | Type | Required |
|---|---|---|
| `x`, `y` | number | ✅ |
| `width`, `height` | number | ✅ |

### `clear_selection` / `invert_selection` / `deselect`
Standard selection modifiers, no parameters.

> **Note:** Move, resize, flip, and rotate transforms operate on the active selection. Make a selection first, then apply the transform tool.

---

## 7. AI Helpers

### `describe_canvas`
Reads canvas snapshot + layers and returns a descriptive text summary. Useful for agents to self-evaluate drawing progress.

### `suggest_palette`
Suggests a color palette based on a keyword theme.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `keyword` | string | ✅ | Theme keyword (e.g. `"desert"`, `"synthwave"`, `"forest"`) |

### `generate_sprite`
High-level orchestrator. Accepts a text prompt and returns a structured drawing plan.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `prompt` | string | ✅ | Plain English sprite description |

Returns a drawing plan with coordinate and color parameters. Pass the output to `draw_pixels` to execute.
```json
{
  "success": true,
  "data": {
    "plan": "...",
    "pixels": [{ "x": 10, "y": 10, "color": "#ff0000" }, "..."]
  }
}
```
