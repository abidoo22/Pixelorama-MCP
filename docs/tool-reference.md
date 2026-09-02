# 🛠️ Pixelorama-MCP Tool Reference

All MCP tools exposed by Pixelorama-MCP. They communicate via HTTP REST on `localhost:7373` to control Pixelorama programmatically.

**Quick rule:** Use `draw_pixels` (batch) for all drawing — never `draw_pixel` in a loop.

---

## Categories
1. [Canvas & Project](#1-canvas--project)
2. [Drawing & Painting](#2-drawing--painting)
3. [Layers](#3-layers)
4. [Animation & Frames](#4-animation--frames)
5. [Color & Palettes](#5-color--palettes)
6. [Selections](#6-selections)
7. [AI Helpers](#7-ai-helpers)
8. [Vision & Inspection](#8-vision--inspection)
9. [Image Importer & Pixelizer](#9-image-importer--pixelizer)
10. [Procedural Game Art](#10-procedural-game-art)
11. [Tilemaps & Tilesets](#11-tilemaps--tilesets)
12. [Direct Godot 4 Resource Export](#12-direct-godot-4-resource-export)

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

### `list_canvases` ⭐ Tab Management
Lists all open canvas/project tabs in Pixelorama with full metadata.

```json
{
  "success": true,
  "data": {
    "total_canvases": 2,
    "active_index": 0,
    "canvases": [
      {
        "index": 0,
        "name": "Knight_Sprite",
        "width": 32,
        "height": 32,
        "layers": 3,
        "frames": 4,
        "save_path": "/home/user/knight.pxo",
        "has_unsaved_changes": false,
        "is_active": true
      },
      {
        "index": 1,
        "name": "Dungeon_Tileset",
        "width": 64,
        "height": 64,
        "layers": 1,
        "frames": 1,
        "save_path": "",
        "has_unsaved_changes": true,
        "is_active": false
      }
    ]
  }
}
```

---

### `switch_canvas`
Switches active focus to a different open project tab by its index.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `index` | number | ✅ | 0-based index of the canvas tab to switch to |

```json
{ "success": true, "data": { "active_index": 1, "name": "Dungeon_Tileset", "width": 64, "height": 64 } }
```

---

### `close_canvas`
Closes an open canvas/project tab.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `index` | number | — | Canvas index to close (defaults to active canvas) |

```json
{ "success": true, "data": { "closed_index": 1, "closed_name": "Dungeon_Tileset", "remaining_canvases": 1, "active_index": 0 } }
```

---

### `save_project`
Saves the active project to Pixelorama's native `.pxo` file format (preserves all layers, animation frames, palettes, and cels).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | — | Absolute file path to save `.pxo` project (e.g. `/home/user/art.pxo`). For new untitled projects, specify `path` to save directly to disk. |

```json
{ "success": true, "data": { "path": "/home/user/project.pxo" } }
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

### `crop_to_content`
Automatically trims and crops the canvas to fit the bounding box of all non-transparent pixels. Essential for removing blank padding after drawing sprites.

```json
{ "success": true, "data": { "original_size": [64, 64], "new_size": [24, 32], "crop_rect": [20, 16, 24, 32] } }
```

---

### `scale_canvas`
Scales the canvas using pixel-perfect nearest-neighbor interpolation. Use integer factors (`2`, `3`, `4`) for crisp retro upscale.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `factor` | number | — | Integer scaling factor (`2` = 2x, `4` = 4x) |
| `width` | number | — | Target width in pixels (if not using factor) |
| `height` | number | — | Target height in pixels (if not using factor) |

```json
{ "success": true, "data": { "original_size": [16, 16], "new_size": [32, 32] } }
```

---

## 2. Drawing, Painting & Inspection

> 💡 **Stateless Targeting**: All drawing tools accept optional `layer` and `frame` parameters. This allows you to draw directly to background layers or specific animation frames in a single turn without needing `switch_cel` first!

### `undo` / `redo`
Undo or redo drawing actions, layer edits, or cel modifications in Pixelorama.

```json
// undo
{ "success": true, "data": { "message": "Undone: Draw Pixels" } }

// redo
{ "success": true, "data": { "message": "Redone action" } }
```

---

### `get_pixel` / `get_pixels` / `get_region` ⭐ Direct Inspection
Fast, lightweight tools for inspecting canvas colors without needing to decode color-indexed snapshot palettes.

* **`get_pixel`**: Inspect single coordinate.
  - `{ x: number, y: number, layer?: number, frame?: number }`
  - Response: `{ color: "#ffffff", r: 255, g: 255, b: 255, a: 255 }`
* **`get_pixels`**: Batch query multiple coordinates in one round-trip.
  - `{ coords: [{x: 10, y: 12}, {x: 15, y: 12}], layer?: number, frame?: number }`
* **`get_region`**: Direct 2D matrix of hex colors for a bounding box (great for tilemap seams).
  - `{ x: 0, y: 0, width: 16, height: 16, layer?: number, frame?: number }`

---

### `transform_cel` / `rotate_cel` ⭐ Cel Manipulation & Animation
Nudge or rotate pixels on a cel without erasing and redrawing.

* **`transform_cel`**: Shifts all pixels by `(dx, dy)`. Essential for walk cycles, breathing idle frames (`copy_cel` → `transform_cel(dy: -1)`), and composition corrections.
  - `{ dx: number, dy: number, wrap_around?: boolean, layer?: number, frame?: number }`
* **`rotate_cel`**: Rotates cel in 90-degree steps.
  - `{ angle: 90 | 180 | 270, layer?: number, frame?: number }`

---

### `draw_pixels` ⭐ Primary drawing tool
Draws multiple pixels in a single batch. **Always use this — never loop `draw_pixel`.**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `pixels` | array | ✅ | Array of `{ x, y, color }` objects |
| `layer` | number | — | Optional target layer index |
| `frame` | number | — | Optional target frame index |

Each pixel object:
- `x` — X coordinate (0-indexed)
- `y` — Y coordinate (0-indexed)
- `color` — hex color string (`"#ffd700"`)

```json
{ "success": true, "data": { "drawn": 1500, "skipped": 0, "pixels_drawn": 1500, "pixels_clipped": 0 } }
```

---

### `draw_pixel`
Draws a single pixel.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x` | number | ✅ | X coordinate |
| `y` | number | ✅ | Y coordinate |
| `color` | string | — | Hex color (default: `"#000000"`) |
| `layer` | number | — | Optional target layer index |
| `frame` | number | — | Optional target frame index |

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
| `layer` | number | — | Optional target layer index |
| `frame` | number | — | Optional target frame index |

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
| `layer` | number | — | Optional target layer index |
| `frame` | number | — | Optional target frame index |

---

### `draw_line`
Draws a straight line using Bresenham's algorithm.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x1`, `y1` | number | ✅ | Start point |
| `x2`, `y2` | number | ✅ | End point |
| `color` | string | — | Hex color (default: `"#000000"`) |
| `layer` | number | — | Optional target layer index |
| `frame` | number | — | Optional target frame index |

---

### `draw_polygon`
Draws a polygon from a vertex array.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `points` | array | ✅ | `[{"x": 10, "y": 12}, ...]` (min 3) |
| `color` | string | — | Hex color (default: `"#000000"`) |
| `filled` | boolean | — | `true` = filled (default), `false` = outline only |
| `layer` | number | — | Optional target layer index |
| `frame` | number | — | Optional target frame index |

---

### `draw_path`
Draws a continuous polyline connecting ordered points.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `points` | array | ✅ | Ordered `[{"x": 10, "y": 12}, ...]` coordinates (min 2) |
| `closed` | boolean | — | If `true`, closes path back to start (default: `false`) |
| `color` | string | — | Hex color (default: `"#000000"`) |
| `layer` | number | — | Optional target layer index |
| `frame` | number | — | Optional target frame index |

---

### `fill_area`
Flood-fills from a seed coordinate (paint bucket).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `x` | number | ✅ | Seed X |
| `y` | number | ✅ | Seed Y |
| `color` | string | — | Fill color (default: `"#000000"`) |
| `layer` | number | — | Optional target layer index |
| `frame` | number | — | Optional target frame index |

---

## 3. Layers

Pixelorama supports multi-layer projects. Use layers to separate background, body, outline, and effects.

### `add_layer`
Adds a new layer to the current project.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | string | `""` | Layer name (empty for auto-naming) |
| `type` | number | `0` | `0` = Pixel, `1` = Group, `2` = 3D |
| `above_layer` | number | — | Insert above this layer index (defaults to current layer) |

---

### `set_layer_name` / `reorder_layers`
- **`set_layer_name`**: `{ index: number, name: string }` — Renames a layer.
- **`reorder_layers`**: `{ from_index: number, to_index: number }` — Moves a layer in the stack order.

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

### `color_replace`
Replaces all pixels of `old_color` with `new_color` on the active cel. Invaluable for palette swapping, elemental variants (fire/ice armor), and skin tone customization.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `old_color` | string | ✅ | Color hex to replace (e.g. `"#e74c3c"`) |
| `new_color` | string | ✅ | Replacement color hex (e.g. `"#3498db"`) |
| `tolerance` | number | — | Distance tolerance (default: `0.05`) |

```json
{ "success": true, "data": { "replaced_pixels": 240, "old_color": "e74c3cff", "new_color": "3498dbff" } }
```

---

### `adjust_hsv`
Adjusts Hue shift, Saturation, and Brightness/Value on the active cel. Perfect for environmental tints (night/dungeon darkness, poison green glows, frozen blue tints).

| Parameter | Type | Default | Description |
|---|---|---|---|
| `hue_shift` | number | `0.0` | Hue angle shift in degrees (`-180` to `+180`) |
| `saturation` | number | `1.0` | Saturation multiplier (`0` = grayscale, `2.0` = hyper-vibrant) |
| `value` | number | `1.0` | Value/Brightness multiplier (`0` = black, `1.5` = bright) |

```json
{ "success": true, "data": { "modified_pixels": 350, "hue_shift": 120, "saturation": 1.2, "value": 1.0 } }
```

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

---

## 8. Vision & Inspection

### `capture_canvas_image`
Captures a visual screenshot of the current canvas (all layers blended) and returns it as a real MCP image artifact (`type: "image"`). Enables multimodal AI models (Claude 3.7, GPT-4o) to visually inspect their drawing, verify proportions, check lighting, and self-correct.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `frame` | number | current | Frame index to capture |

---

## 9. Image Importer & Pixelizer

### `import_image`
Imports any external PNG image into Pixelorama as clean pixel art. Automatically samples and removes background colors, supports color quantization to retro palettes (PICO-8, NES, Game Boy), and streams pixels with transparency into Pixelorama.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `file_path` | string | — | Absolute path to PNG image |
| `target_width` | number | — | Optional target width in pixels |
| `target_height` | number | — | Optional target height in pixels |
| `remove_background` | boolean | `true` | Auto-detect and strip background |
| `tolerance` | number | `20` | Color distance tolerance for background cleaning |
| `palette` | string | — | Optional palette quantization (`"pico8"`, `"gameboy"`, `"nes"`) |
| `create_new_canvas` | boolean | `true` | Create new canvas or draw on active cel |
| `canvas_name` | string | `"Imported Sprite"` | Name for new canvas |

---

## 10. Procedural Game Art

### `apply_outline`
Automatically detects sprite borders on the active layer and applies an outline of specified color and thickness.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `color` | string | `"#000000"` | Outline hex color |
| `thickness` | number | `1` | Outline thickness in pixels (1–4) |
| `inside` | boolean | `false` | Inner outline (`true`) or outer border (`false`) |

---

### `mirror_layer`
Mirrors or flips the active cel. Essential for symmetrical characters, monsters, weapons, armor, and chests.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `axis` | string | `"horizontal"` | `"horizontal"` or `"vertical"` |
| `mode` | string | `"mirror_left_to_right"` | `"flip"`, `"mirror_left_to_right"`, `"mirror_right_to_left"`, or `"mirror_top_to_bottom"` |

---

### `generate_color_ramp`
Calculates a 5-step shading ramp (`highlight`, `light`, `base`, `shadow`, `deepShadow`) from any base color using perceptual lighting and hue-shifting math.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `base_color` | string | ✅ | Base hex color (e.g. `"#e74c3c"`) |

---

### `apply_dithering`
Fills a region with 2×2 checkerboard dithering between two colors for smooth retro shading transitions.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `x`, `y` | number | — | Top-left position |
| `width`, `height` | number | — | Region size in pixels |
| `color1`, `color2` | string | — | Two hex colors to blend |
| `pattern` | string | `"checker_50"` | `"checker_50"`, `"light_25"`, or `"dense_75"` |

---

## 11. Tilemaps & Tilesets

### `create_tileset_canvas`
Creates a canvas partitioned into an $N \times M$ grid of uniform tiles (e.g. 4×4 grid of 16×16 tiles = 64×64 canvas).

| Parameter | Type | Default | Description |
|---|---|---|---|
| `tile_size` | number | `16` | Size of individual tiles in pixels (e.g. 16 or 32) |
| `columns` | number | `4` | Number of columns |
| `rows` | number | `4` | Number of rows |
| `name` | string | `"Tileset"` | Project name |

---

### `export_tileset`
Exports the canvas as a tileset PNG and generates an accompanying JSON metadata file with tile coordinates and IDs.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `export_path` | string | — | Output file path for PNG |
| `tile_size` | number | `16` | Size of tiles in pixels |
| `generate_metadata` | boolean | `true` | Generate JSON metadata file |

---

## 12. Direct Godot 4 Resource Export

### `export_godot_spriteframes`
Exports animation frame PNGs directly into a Godot project folder and generates a native Godot 4 `SpriteFrames` text resource (`.tres`) ready to attach to an `AnimatedSprite2D` node.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `target_dir` | string | — | Destination directory (e.g. `"/path/to/godot_project/assets/characters/"`) |
| `sprite_name` | string | — | Base name for sprite (e.g. `"knight"`) |
| `animation_name` | string | `"default"` | Animation name in Godot (e.g. `"walk"`, `"idle"`) |
| `fps` | number | `8` | Animation playback speed |
| `loop` | boolean | `true` | Whether animation loops |

---

### `export_godot_tileset`
Exports a tileset PNG and generates a native Godot 4 `TileSet` text resource (`.tres`) with a pre-configured `TileSetAtlasSource` ready to attach to a `TileMap` or `TileMapLayer` node.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `target_dir` | string | — | Destination directory (e.g. `"/path/to/godot_project/assets/tilesets/"`) |
| `tileset_name` | string | — | Base name for tileset (e.g. `"dungeon_tiles"`) |
| `tile_size` | number | `16` | Tile size in pixels (e.g. 16 or 32) |

---

## 13. Advanced Project & Viewport Guides

### `open_project`
Open an existing native Pixelorama `.pxo` project file from disk.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | ✅ | Absolute file path to the `.pxo` file |

---

### `set_tile_mode`
Enable Pixelorama's native 3×3 live repeating viewport tile mode for seamless textures.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `mode` | string | `"both"` | `"off"`, `"x"`, `"y"`, or `"both"` |

---

### `set_symmetry_guide`
Enable and configure horizontal & vertical symmetry guide planes.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `horizontal` | boolean | `false` | Enable horizontal symmetry axis |
| `vertical` | boolean | `false` | Enable vertical symmetry axis |
| `x_pos` | number | `center` | X position for vertical mirror line |
| `y_pos` | number | `center` | Y position for horizontal mirror line |

---

### `set_onion_skinning`
Configure past/future frame ghosting overlays in the live animation editor.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Enable/disable onion skinning |
| `past_frames` | number | `1` | Number of past frames shown |
| `future_frames` | number | `1` | Number of future frames shown |
| `blue_red_tint` | boolean | `true` | Blue/Red color tinting |

---

## 14. Animation Tags & Timeline Superchargers

### `add_animation_tag`
Define named animation ranges (e.g. "idle", "walk", "attack") with color bands in the timeline.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | string | ✅ | Tag name (e.g. `"attack"`) |
| `from_frame` | number | ✅ | Start frame index (0-based) |
| `to_frame` | number | ✅ | End frame index (0-based) |
| `color` | string | `"#ff5500"` | Hex color for timeline tag marker |

---

### `get_animation_tags`
List all animation tracks, their frame spans, and marker colors.

---

### `delete_animation_tag`
Delete an animation tag by name or index.

---

### `reverse_frames`
Reverse the order of timeline frames (or a sub-range) for ping-pong loops.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `from_frame` | number | `0` | Starting frame index |
| `to_frame` | number | `last` | Ending frame index |

---

### `tween_cel`
Interpolate cel translation `(dx, dy)` across intermediate frames for smooth motion.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `src_frame` | number | — | Starting frame index |
| `dst_frame` | number | — | Target frame index |
| `dx`, `dy` | number | `0` | Total translation offsets |

---

### `export_gif` / `export_apng`
Render animated `.gif` or `.apng` directly to disk.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | ✅ | Destination file path |

---

### `export_aseprite_json`
Export a spritesheet PNG alongside standard Aseprite-compatible `.json` metadata (Unity, Godot, Unreal, Phaser).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `target_dir` | string | ✅ | Output directory |
| `base_name` | string | project name | Filename prefix |

---

### `import_spritesheet`
Slice an external spritesheet image into sequential timeline frames in Pixelorama.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `path` | string | — | File path to spritesheet |
| `frame_width` | number | `32` | Width of single frame |
| `frame_height` | number | `32` | Height of single frame |
| `start_frame` | number | `0` | Insert position |

---

## 15. Advanced Selections & Floating Transforms

### `select_by_color` (Magic Wand)
Select pixels matching target color with tolerance. Contiguous or global.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `color` | string | — | Hex color to match |
| `tolerance` | number | `0.05` | Match tolerance (0.0 to 1.0) |
| `contiguous` | boolean | `false` | Flood fill from start coordinates |

---

### `invert_selection`
Invert the active selection mask.

---

### `transform_selection`
Shift only the selected pixels by `(dx, dy)` on the active cel.

---

## 16. Layer Operations & Organizations

### `duplicate_layer`
Clone an entire layer and all its cels across every frame.

---

### `merge_layers`
Merge a source layer down into a target layer with alpha blending.

---

### `create_layer_group`
Create a folder / GroupLayer in Pixelorama.

---

## 17. FX, Typography & QA Linters

### `apply_drop_shadow`
Generate an offset silhouette cast shadow under the sprite or as a new layer.

---

### `apply_glow`
Generate a soft neon/magic bloom halo around non-transparent pixels.

---

### `apply_gradient`
Fill an area with linear/radial color gradients and optional Bayer dithering.

---

### `check_seamless_tile`
Verify and auto-fix tile wrap-around border seams.

---

### `draw_text`
Render crisp bitmap pixel typography directly onto the canvas.

---

### `get_palette_usage`
Get a frequency histogram of every color on the canvas.

---

### `clean_isolated_pixels`
Scan and remove 1px orphan noise pixels.

---

### `remap_to_palette`
Quantize and snap canvas pixels to the nearest colors in a target palette.

