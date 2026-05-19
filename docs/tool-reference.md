# 🛠️ pix-MCP Tool Reference

This document provides a comprehensive reference of all Model Context Protocol (MCP) tools exposed by the **pix-MCP** server. These tools communicate via local **HTTP REST** (port `7373`) to control **Pixelorama v1.1.10** programmatically, allowing any AI agent or client to manage layers, frames, colors, and perform high-fidelity drawing operations.

---

## 📂 Categories
1. [Canvas & Project Control](#1-canvas--project-control)
2. [Drawing & Painting](#2-drawing--painting)
3. [Layers Management](#3-layers-management)
4. [Animation & Frames](#4-animation--frames)
5. [Color & Palettes](#5-color--palettes)
6. [Selections & Transforms](#6-selections--transforms)
7. [AI Helpers & Intelligence](#7-ai-helpers--intelligence)

---

## 1. Canvas & Project Control

These tools manage the active Pixelorama canvas, project state, and exports.

### 📝 `create_canvas`
Creates a brand-new tab/project canvas inside Pixelorama.
* **Parameters:**
  * `width` (number, required): Width of the canvas in pixels (e.g. `64`, `128`).
  * `height` (number, required): Height of the canvas in pixels.
  * `name` (string, optional): The name of the project tab.
* **Return Format:**
  ```json
  { "success": true, "data": { "width": 64, "height": 64, "name": "Golden Coin" } }
  ```

### 📝 `get_canvas_info`
Retrieves dimensions, frame count, layer count, and overall structure of the active project.
* **Parameters:** None.
* **Return Format:**
  ```json
  {
    "success": true,
    "data": {
      "width": 64,
      "height": 64,
      "layers": ["Layer 1"],
      "frames_count": 1,
      "current_frame": 0
    }
  }
  ```

### 📝 `save_project`
Saves the active Pixelorama project to a `.pxo` (Pixelorama native format) file.
* **Parameters:**
  * `path` (string, required): Absolute file path to save the project (e.g., `/home/user/project.pxo`).
* **Return Format:**
  ```json
  { "success": true }
  ```

### 📝 `export_image`
Exports a high-fidelity rendering of the active frame/cel to a PNG file.
* **Parameters:**
  * `path` (string, required): Absolute file path of the target PNG (e.g., `/home/user/output.png`).
  * `frame_idx` (number, optional, default: current): Index of the frame to export (0-indexed).
* **Return Format:**
  ```json
  { "success": true, "data": { "path": "/home/user/output.png", "format": "png" } }
  ```

### 📝 `get_canvas_snapshot`
Generates a raw base64-encoded PNG image of the current canvas viewport. Used by drawing agents to inspect progress.
* **Parameters:** None.
* **Return Format:**
  ```json
  { "success": true, "data": { "base64": "iVBORw0KGgoAAAANSUhEUgAAAD..." } }
  ```

---

## 2. Drawing & Painting

Core raster operations. These commands write pixel data directly onto the active cel.

### 🖌️ `draw_pixel`
Draws a single pixel.
* **Parameters:**
  * `x` (number, required): X coordinate (0-indexed).
  * `y` (number, required): Y coordinate (0-indexed).
  * `color` (string, optional, default: active color): Hex color code (e.g. `"#ffd700"`).
* **Return Format:**
  ```json
  { "success": true }
  ```

### 🖌️ `draw_pixels`
Draws multiple pixels in a single batch. **Extremely fast and highly recommended** for rendering complex figures.
* **Parameters:**
  * `pixels` (array of objects, required): List of pixels. Each pixel object:
    * `x` (number, required)
    * `y` (number, required)
    * `color` (string, required): Hex color code.
* **Return Format:**
  ```json
  { "success": true, "data": { "drawn": 1500, "skipped": 0 } }
  ```

### 🖌️ `draw_rect`
Draws a rectangle (filled or outlined).
* **Parameters:**
  * `x` (number, required): Starting top-left X coordinate.
  * `y` (number, required): Starting top-left Y coordinate.
  * `width` (number, required)
  * `height` (number, required)
  * `color` (string, optional): Hex color.
  * `fill` (boolean, optional, default: `true`): True to fill, false for outline.
* **Return Format:**
  ```json
  { "success": true }
  ```

### 🖌️ `draw_ellipse`
Draws a perfect circle or ellipse.
* **Parameters:**
  * `x` (number, required): Center X.
  * `y` (number, required): Center Y.
  * `rx` (number, required): X radius.
  * `ry` (number, required): Y radius.
  * `color` (string, optional): Hex color.
  * `fill` (boolean, optional, default: `true`): True to fill, false for outline.

### 🖌️ `draw_line`
Draws a straight line from start to end using Bresenham's algorithm.
* **Parameters:**
  * `x0`, `y0` (number, required): Start coordinate.
  * `x1`, `y1` (number, required): End coordinate.
  * `color` (string, optional): Hex color.
  * `width` (number, optional, default: `1`): Line width.

### 🖌️ `draw_polygon`
Draws a polygon from an array of vertices.
* **Parameters:**
  * `vertices` (array of objects, required): Coordinates `[{"x": 10, "y": 12}, ...]`.
  * `color` (string, optional): Hex color.
  * `fill` (boolean, optional, default: `true`)

### 🖌️ `draw_path`
Draws a continuous polyline/curve connecting a list of points.
* **Parameters:**
  * `points` (array of objects, required): Ordered path coordinates.
  * `color` (string, optional): Hex color.

### 🖌️ `fill_area`
Performs a flood-fill (bucket fill) starting at seed coordinates.
* **Parameters:**
  * `x` (number, required): Seed X coordinate.
  * `y` (number, required): Seed Y coordinate.
  * `color` (string, optional): Hex color.

---

## 3. Layers Management

Pixelorama supports multi-layer layouts. These tools allow agents to separate foregrounds, backgrounds, outlines, and effects.

### 🥞 `add_layer`
Adds a new layer on top of the active project.
* **Parameters:**
  * `name` (string, required): Layer name.
* **Return Format:**
  ```json
  { "success": true, "data": { "layer_idx": 1, "name": "Outline" } }
  ```

### 🥞 `delete_layer`
Deletes a layer by index.
* **Parameters:**
  * `layer_idx` (number, required): Index of layer to remove (0-indexed).

### 🥞 `set_layer_opacity`
Modifies the opacity of a target layer.
* **Parameters:**
  * `layer_idx` (number, required)
  * `opacity` (number, required): Floating point value from `0.0` (fully transparent) to `1.0` (fully opaque).

### 🥞 `set_layer_blend_mode`
Changes blend modes for creative composition.
* **Parameters:**
  * `layer_idx` (number, required)
  * `blend_mode` (string, required): One of `"Normal"`, `"Multiply"`, `"Screen"`, `"Overlay"`, `"Darken"`, `"Lighten"`, `"Color Dodge"`, `"Color Burn"`, `"Difference"`, `"Exclusion"`, `"Hue"`, `"Saturation"`, `"Color"`, `"Luminosity"`.

### 🥞 `set_layer_visibility`
Toggles layer visibility.
* **Parameters:**
  * `layer_idx` (number, required)
  * `visible` (boolean, required)

---

## 4. Animation & Frames

Exposes standard frame and cel APIs to orchestrate frame-by-frame sprites and export GIFs or spritesheets.

### 🎞️ `add_frame`
Appends a blank frame to the animation.
* **Parameters:** None.

### 🎞️ `delete_frame`
Deletes a frame by index.
* **Parameters:**
  * `frame_idx` (number, required)

### 🎞️ `duplicate_frame`
Copies a frame and all its layers to a new frame position.
* **Parameters:**
  * `frame_idx` (number, required)

### 🎞️ `set_frame_duration`
Adjusts the display duration of a target frame.
* **Parameters:**
  * `frame_idx` (number, required)
  * `duration` (number, required): Duration factor (default: `1.0`).

### 🎞️ `switch_frame`
Changes active viewport focus to a specific frame.
* **Parameters:**
  * `frame_idx` (number, required)

### 🎞️ `get_fps` / `set_fps`
Manages project global playback speed.
* **Parameters:**
  * `fps` (number, required, for set_fps): Animation frames per second.

### 🎞️ `switch_cel` / `copy_cel` / `clear_cel`
Finer control over individual frames of a specific layer.
* `layer_idx` (number, required) and `frame_idx` (number, required) parameters to select and manipulate cels.

### 🎞️ `export_animation`
Renders project frames into a finished animated asset.
* **Parameters:**
  * `path` (string, required): Destination folder or file path.
  * `mode` (string, required): Either `"frames"` (individual PNG files) or `"spritesheet"` (single grid spritesheet).
  * `columns` (number, optional, default: 8): Spritesheet columns grid.

---

## 5. Color & Palettes

Manages active painting swatches and custom game palettes.

### 🎨 `set_color`
Selects primary and secondary painting colors in Pixelorama.
* **Parameters:**
  * `color` (string, required): Hex color code (e.g. `"#ff0055"`).
  * `is_secondary` (boolean, optional, default: `false`): Set true for right-click color.

### 🎨 `get_assigned_color`
Retrieves currently selected colors.
* **Parameters:** None.
* **Return:** `{"foreground": "#ffffff", "background": "#000000"}`

### 🎨 `create_palette`
Creates a brand-new palette file.
* **Parameters:**
  * `name` (string, required)
  * `width` / `height` (number, optional): Swatches layout size.
  * `is_global` (boolean, optional, default: `false`)

### 🎨 `get_palette_colors` / `add_palette_color` / `set_palette_color`
Modifies swatches inside active and custom palettes.

---

## 6. Selections & Transforms

Enables pixel manipulations, cropping, rotations, and selections.

### ✂️ `select_rect` / `select_ellipse`
Selects specific regions of the active canvas frame.
* **Parameters:** `x`, `y`, `width`, `height`.

### ✂️ `clear_selection` / `invert_selection` / `deselect`
Standard viewport selection modifiers.

---

## 7. AI Helpers & Intelligence

High-level assistant tools that help orchestrate drawing plans or summarize visual feedback.

### 🧠 `describe_canvas`
Reads canvas data (snapshot + layers + active frame) and synthesizes a descriptive text block for the AI. Helpful for evaluating ongoing progress.
* **Parameters:** None.

### 🧠 `suggest_palette`
Suggests structured game palettes based on semantic keywords (e.g. *"desert"*, *"synthwave"*).
* **Parameters:**
  * `keyword` (string, required): Color theme or theme prompt.

### 🧠 `generate_sprite`
High-level structural orchestrator tool. Accepts plain-text prompt, builds a coordinate-by-coordinate drawing plan, and outputs the drawing command parameters.
* **Parameters:**
  * `prompt` (string, required): Description of the sprite you want to draw.
