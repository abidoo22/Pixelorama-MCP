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

  // ── draw_pixel ──────────────────────────────────────────────────────
  server.tool(
    "draw_pixel",
    "Set a single pixel at the given (x, y) coordinates to the specified RGBA color on the current layer.",
    {
      x: coerceInt().describe("X coordinate (0-based, left to right)"),
      y: coerceInt().describe("Y coordinate (0-based, top to bottom)"),
      color: z
        .string()
        .default("#000000")
        .describe("Pixel color as hex string (e.g. '#FF5733', '#00FF00FF')"),
    },
    async ({ x, y, color }) => {
      const result = await sendCommand("draw_pixel", { x, y, color });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Pixel drawn at (${x}, ${y}) with color ${color}`
              : `❌ ${result.error}`,
          },
        ],
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
    },
    async ({ x1, y1, x2, y2, color }) => {
      const result = await sendCommand("draw_line", {
        x1,
        y1,
        x2,
        y2,
        color,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Line drawn from (${x1},${y1}) to (${x2},${y2})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── draw_rect ───────────────────────────────────────────────────────
  server.tool(
    "draw_rect",
    "Draw a rectangle on the current layer. Can be filled or outline only.",
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
    },
    async ({ x, y, width, height, color, filled }) => {
      const result = await sendCommand("draw_rect", {
        x,
        y,
        width,
        height,
        color,
        filled,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Rectangle drawn at (${x},${y}) size ${width}×${height} (${filled ? "filled" : "outline"})`
              : `❌ ${result.error}`,
          },
        ],
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
    },
    async ({ cx, cy, rx, ry, color, filled }) => {
      const result = await sendCommand("draw_ellipse", {
        cx,
        cy,
        rx,
        ry,
        color,
        filled,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Ellipse drawn at center (${cx},${cy}) radii ${rx}×${ry}`
              : `❌ ${result.error}`,
          },
        ],
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
    },
    async ({ x, y, color }) => {
      const result = await sendCommand("fill_area", { x, y, color });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Flood fill from (${x},${y}) — ${result.data?.pixels_filled ?? "?"} pixels filled`
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
    },
    async ({ pixels }) => {
      const result = await sendCommand("draw_pixels", { pixels });
      if (result.success && result.data) {
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Batch draw: ${result.data.drawn} pixels drawn, ${result.data.skipped} skipped (${result.data.total} total)`,
            },
          ],
        };
      }
      return {
        content: [
          { type: "text" as const, text: `❌ ${result.error}` },
        ],
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
        content: [
          { type: "text" as const, text: `❌ ${result.error}` },
        ],
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
    },
    async ({ points, color, closed }) => {
      const result = await sendCommand("draw_path", { points, color, closed });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Path drawn with ${points.length} points (${closed ? "closed" : "open"})`
              : `❌ ${result.error}`,
          },
        ],
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
    },
    async ({ points, color, filled }) => {
      const result = await sendCommand("draw_polygon", { points, color, filled });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Polygon drawn with ${points.length} vertices (${filled ? "filled" : "outline"})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
