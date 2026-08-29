/**
 * Drawing, Painting & History Tools
 *
 * Tools for drawing pixels, lines, rectangles, ellipses, polygons, flood-filling,
 * and undo/redo operations.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceBool, safeJsonArray } from "../utils/schema_helpers.js";

export function registerDrawingTools(server: McpServer): void {
  // ── undo ────────────────────────────────────────────────────────────
  server.tool(
    "undo",
    "Undo the last drawing, layer, or cel modification in Pixelorama.",
    {},
    async () => {
      const result = await sendCommand("undo", {});
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `↩️ ${result.data?.message ?? "Undone last action"}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── redo ────────────────────────────────────────────────────────────
  server.tool(
    "redo",
    "Redo the previously undone action in Pixelorama.",
    {},
    async () => {
      const result = await sendCommand("redo", {});
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `↪️ ${result.data?.message ?? "Redone action"}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── get_pixel ───────────────────────────────────────────────────────
  server.tool(
    "get_pixel",
    "Directly inspect the color at coordinates (x, y) on a cel. Returns exact hex and RGBA values.",
    {
      x: coerceInt().describe("X coordinate"),
      y: coerceInt().describe("Y coordinate"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ x, y, layer, frame }) => {
      const result = await sendCommand("get_pixel", { x, y, layer, frame });
      if (result.success && result.data) {
        return {
          content: [
            {
              type: "text" as const,
              text: `🔍 Pixel at (${x}, ${y}): ${result.data.color} (R:${result.data.r} G:${result.data.g} B:${result.data.b} A:${result.data.a}) [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── get_pixels ──────────────────────────────────────────────────────
  server.tool(
    "get_pixels",
    "Batch inspect multiple pixel coordinates in one call. Returns exact colors for each coordinate.",
    {
      coords: safeJsonArray(
        z.object({
          x: coerceInt().describe("X coordinate"),
          y: coerceInt().describe("Y coordinate"),
        }),
        1
      ).describe("Array of coordinate objects [{x, y}, ...]"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ coords, layer, frame }) => {
      const result = await sendCommand("get_pixels", { coords, layer, frame });
      if (result.success && result.data) {
        const pixels = result.data.pixels as Array<{ x: number; y: number; color: string | null; error?: string }>;
        const list = pixels
          .map((p) =>
            p.error ? `(${p.x},${p.y}): out_of_bounds` : `(${p.x},${p.y}): ${p.color}`
          )
          .join("\n");
        return {
          content: [
            {
              type: "text" as const,
              text: `🔍 Inspected ${result.data.count} pixels [frame:${result.data.frame}, layer:${result.data.layer}]:\n${list}`,
            },
          ],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── get_region ──────────────────────────────────────────────────────
  server.tool(
    "get_region",
    "Get a direct 2D matrix of hex colors for a rectangular area (no palette index decoding required). Perfect for checking tile seams and alignment.",
    {
      x: coerceInt().default(0).describe("Top-left X coordinate"),
      y: coerceInt().default(0).describe("Top-left Y coordinate"),
      width: coerceInt(1, 128).default(16).describe("Width of region (max 128)"),
      height: coerceInt(1, 128).default(16).describe("Height of region (max 128)"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ x, y, width, height, layer, frame }) => {
      const result = await sendCommand("get_region", { x, y, width, height, layer, frame });
      if (result.success && result.data) {
        const d = result.data;
        const grid = d.grid as string[][];
        let text = `Region (${d.x},${d.y}) ${d.width}×${d.height} [frame:${d.frame}, layer:${d.layer}]:\n`;
        for (const row of grid) {
          text += row.join(" ") + "\n";
        }
        return {
          content: [{ type: "text" as const, text }],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── transform_cel ───────────────────────────────────────────────────
  server.tool(
    "transform_cel",
    "Nudge, translate, or offset all pixels on a cel by (dx, dy). Essential for creating walking/breathing animation frames without redrawing, and for composition adjustments.",
    {
      dx: coerceInt().describe("Horizontal shift in pixels (+ right, - left)"),
      dy: coerceInt().describe("Vertical shift in pixels (+ down, - up)"),
      wrap_around: coerceBool().default(false).describe("If true, pixels shifted off one edge wrap to the opposite edge (useful for seamless textures)"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ dx, dy, wrap_around, layer, frame }) => {
      const result = await sendCommand("transform_cel", { dx, dy, wrap_around, layer, frame });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `🚀 Cel transformed by (${dx}, ${dy}) — ${result.data?.shifted_pixels ?? 0} pixels shifted [frame:${result.data?.frame}, layer:${result.data?.layer}]`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── rotate_cel ──────────────────────────────────────────────────────
  server.tool(
    "rotate_cel",
    "Rotate all pixels on a cel in 90-degree increments (90, 180, 270).",
    {
      angle: coerceInt().describe("Rotation angle in degrees (90, 180, or 270)"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ angle, layer, frame }) => {
      const result = await sendCommand("rotate_cel", { angle, layer, frame });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `🔄 Cel rotated ${angle}° [frame:${result.data?.frame}, layer:${result.data?.layer}]`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── draw_pixel ──────────────────────────────────────────────────────
  server.tool(
    "draw_pixel",
    "Set a single pixel at the given (x, y) coordinates to the specified RGBA color.",
    {
      x: coerceInt().describe("X coordinate (0-based, left to right)"),
      y: coerceInt().describe("Y coordinate (0-based, top to bottom)"),
      color: z
        .string()
        .default("#000000")
        .describe("Pixel color as hex string (e.g. '#FF5733', '#00FF00FF')"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ x, y, color, layer, frame }) => {
      const result = await sendCommand("draw_pixel", { x, y, color, layer, frame });
      if (result.success && result.data) {
        const clipped = Number(result.data.pixels_clipped) > 0 ? ` (⚠️ clipped outside canvas)` : "";
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Pixel at (${x}, ${y}) set to ${color} on [frame:${result.data.frame}, layer:${result.data.layer}]${clipped}`,
            },
          ],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── draw_line ───────────────────────────────────────────────────────
  server.tool(
    "draw_line",
    "Draw a straight line from point (x1, y1) to point (x2, y2) using Bresenham's algorithm.",
    {
      x1: coerceInt().describe("Start X coordinate"),
      y1: coerceInt().describe("Start Y coordinate"),
      x2: coerceInt().describe("End X coordinate"),
      y2: coerceInt().describe("End Y coordinate"),
      color: z
        .string()
        .default("#000000")
        .describe("Line color as hex string"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ x1, y1, x2, y2, color, layer, frame }) => {
      const result = await sendCommand("draw_line", {
        x1,
        y1,
        x2,
        y2,
        color,
        layer,
        frame,
      });
      if (result.success && result.data) {
        const clippedInfo = Number(result.data.pixels_clipped) > 0 ? ` (${result.data.pixels_clipped} pixels clipped)` : "";
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Line drawn from (${x1},${y1}) to (${x2},${y2}) [${result.data.pixels_drawn} px drawn${clippedInfo}] on [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── draw_rect ───────────────────────────────────────────────────────
  server.tool(
    "draw_rect",
    "Draw a rectangle on the specified cel. Can be filled or outline only.",
    {
      x: coerceInt().describe("Top-left X coordinate"),
      y: coerceInt().describe("Top-left Y coordinate"),
      width: coerceInt(1).describe("Rectangle width in pixels"),
      height: coerceInt(1).describe("Rectangle height in pixels"),
      color: z
        .string()
        .default("#000000")
        .describe("Rectangle color as hex string"),
      filled: coerceBool()
        .default(true)
        .describe("If true, fill the rectangle; if false, draw outline only"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ x, y, width, height, color, filled, layer, frame }) => {
      const result = await sendCommand("draw_rect", {
        x,
        y,
        width,
        height,
        color,
        filled,
        layer,
        frame,
      });
      if (result.success && result.data) {
        const clippedInfo = Number(result.data.pixels_clipped) > 0 ? ` (⚠️ ${result.data.pixels_clipped} px clipped)` : "";
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Rectangle drawn at (${x},${y}) size ${width}×${height} (${filled ? "filled" : "outline"}) [${result.data.pixels_drawn} px drawn${clippedInfo}] on [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── draw_ellipse ────────────────────────────────────────────────────
  server.tool(
    "draw_ellipse",
    "Draw an ellipse (or circle if rx == ry) centered at (cx, cy) with the given radii.",
    {
      cx: coerceInt().describe("Center X coordinate"),
      cy: coerceInt().describe("Center Y coordinate"),
      rx: coerceInt(1).describe("Horizontal radius in pixels"),
      ry: coerceInt(1).describe("Vertical radius in pixels"),
      color: z
        .string()
        .default("#000000")
        .describe("Ellipse color as hex string"),
      filled: coerceBool()
        .default(true)
        .describe("If true, fill the ellipse; if false, draw outline only"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ cx, cy, rx, ry, color, filled, layer, frame }) => {
      const result = await sendCommand("draw_ellipse", {
        cx,
        cy,
        rx,
        ry,
        color,
        filled,
        layer,
        frame,
      });
      if (result.success && result.data) {
        const clippedInfo = Number(result.data.pixels_clipped) > 0 ? ` (⚠️ ${result.data.pixels_clipped} px clipped)` : "";
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Ellipse drawn at center (${cx},${cy}) radii ${rx}×${ry} [${result.data.pixels_drawn} px drawn${clippedInfo}] on [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── fill_area ───────────────────────────────────────────────────────
  server.tool(
    "fill_area",
    "Flood-fill a contiguous area starting from the seed pixel at (x, y). Fills all connected pixels of the same color with the new color.",
    {
      x: coerceInt().describe("Seed X coordinate for flood fill"),
      y: coerceInt().describe("Seed Y coordinate for flood fill"),
      color: z
        .string()
        .default("#000000")
        .describe("Fill color as hex string"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ x, y, color, layer, frame }) => {
      const result = await sendCommand("fill_area", { x, y, color, layer, frame });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Flood fill from (${x},${y}) — ${result.data?.pixels_filled ?? "?"} pixels filled on [frame:${result.data?.frame}, layer:${result.data?.layer}]`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── draw_pixels ─────────────────────────────────────────────────────
  server.tool(
    "draw_pixels",
    "Batch draw multiple pixels in a single operation. Much faster than calling draw_pixel repeatedly. All pixels are committed as a single undoable action. Use this for complex shapes, sprite art, or any multi-pixel drawing.",
    {
      pixels: safeJsonArray(
        z.object({
          x: coerceInt().describe("X coordinate"),
          y: coerceInt().describe("Y coordinate"),
          color: z.string().describe("Pixel color as hex string"),
        }),
        1
      ).describe("Array of pixel objects, each with x, y, and color"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ pixels, layer, frame }) => {
      const result = await sendCommand("draw_pixels", { pixels, layer, frame });
      if (result.success && result.data) {
        const clippedInfo = Number(result.data.skipped) > 0 ? ` (${result.data.skipped} skipped/clipped)` : "";
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Batch draw: ${result.data.drawn} pixels drawn${clippedInfo} (${result.data.total} total) on [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── get_canvas_snapshot ─────────────────────────────────────────────
  server.tool(
    "get_canvas_snapshot",
    "Get a snapshot of the current canvas content. Returns pixel data as a color-indexed grid. Useful for inspecting what's currently drawn before making changes. Keep the region small (e.g. 32x32) for faster response.",
    {
      x: coerceInt()
        .default(0)
        .describe("Top-left X coordinate of the region to snapshot"),
      y: coerceInt()
        .default(0)
        .describe("Top-left Y coordinate of the region to snapshot"),
      width: coerceInt(1, 128)
        .default(32)
        .describe("Width of the snapshot region (max 128)"),
      height: coerceInt(1, 128)
        .default(32)
        .describe("Height of the snapshot region (max 128)"),
    },
    async ({ x, y, width, height }) => {
      const result = await sendCommand("get_canvas_snapshot", {
        x,
        y,
        width,
        height,
      });
      if (result.success && result.data) {
        const d = result.data;
        const colors = d.colors as string[];
        const grid = d.grid as number[][];
        let text = `Canvas snapshot (${d.x},${d.y}) ${d.width}×${d.height}\n`;
        text += `Colors (${colors.length}): ${colors.map((c, i) => `${i}=${c}`).join(", ")}\n`;
        text += "Grid:\n";
        for (const row of grid) {
          text += row.map((idx) => String(idx).padStart(2)).join(" ") + "\n";
        }
        return {
          content: [{ type: "text" as const, text }],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── draw_path ───────────────────────────────────────────────────────
  server.tool(
    "draw_path",
    "Draw a continuous multi-segment line through an array of points in order.",
    {
      points: safeJsonArray(
        z.object({
          x: coerceInt().describe("X coordinate"),
          y: coerceInt().describe("Y coordinate"),
        }),
        2
      ).describe("Array of points to connect with lines [{x, y}, ...]"),
      color: z
        .string()
        .default("#000000")
        .describe("Line color as hex string"),
      closed: coerceBool()
        .default(false)
        .describe("If true, connect the last point back to the first"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ points, color, closed, layer, frame }) => {
      const result = await sendCommand("draw_path", { points, color, closed, layer, frame });
      if (result.success && result.data) {
        const clippedInfo = Number(result.data.pixels_clipped) > 0 ? ` (${result.data.pixels_clipped} px clipped)` : "";
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Path drawn with ${points.length} points (${closed ? "closed" : "open"}) [${result.data.pixels_drawn} px drawn${clippedInfo}] on [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );

  // ── draw_polygon ────────────────────────────────────────────────────
  server.tool(
    "draw_polygon",
    "Draw a polygon from an array of vertices. Can be filled or outline only.",
    {
      points: safeJsonArray(
        z.object({
          x: coerceInt().describe("X coordinate"),
          y: coerceInt().describe("Y coordinate"),
        }),
        3
      ).describe("Array of vertices [{x, y}, ...] (minimum 3)"),
      color: z
        .string()
        .default("#000000")
        .describe("Polygon color as hex string"),
      filled: coerceBool()
        .default(true)
        .describe("If true, fill the polygon; if false, draw outline only"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ points, color, filled, layer, frame }) => {
      const result = await sendCommand("draw_polygon", { points, color, filled, layer, frame });
      if (result.success && result.data) {
        const clippedInfo = Number(result.data.pixels_clipped) > 0 ? ` (${result.data.pixels_clipped} px clipped)` : "";
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Polygon drawn with ${points.length} vertices (${filled ? "filled" : "outline"}) [${result.data.pixels_drawn} px drawn${clippedInfo}] on [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return {
        content: [{ type: "text" as const, text: `❌ ${result.error}` }],
      };
    }
  );
}
