/**
 * Drawing & Painting Tools
 *
 * Tools for drawing pixels, lines, rectangles, ellipses, and flood-filling.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";

export function registerDrawingTools(server: McpServer): void {
  server.tool(
    "draw_pixel",
    "Set a single pixel at the given (x, y) coordinates to the specified RGBA color on the current layer.",
    {
      x: z.number().int().describe("X coordinate (0-based, left to right)"),
      y: z.number().int().describe("Y coordinate (0-based, top to bottom)"),
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

  server.tool(
    "draw_line",
    "Draw a straight line from point (x1, y1) to point (x2, y2) using Bresenham's algorithm.",
    {
      x1: z.number().int().describe("Start X coordinate"),
      y1: z.number().int().describe("Start Y coordinate"),
      x2: z.number().int().describe("End X coordinate"),
      y2: z.number().int().describe("End Y coordinate"),
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

  server.tool(
    "draw_rect",
    "Draw a rectangle on the current layer. Can be filled or outline only.",
    {
      x: z.number().int().describe("Top-left X coordinate"),
      y: z.number().int().describe("Top-left Y coordinate"),
      width: z.number().int().min(1).describe("Rectangle width in pixels"),
      height: z.number().int().min(1).describe("Rectangle height in pixels"),
      color: z
        .string()
        .default("#000000")
        .describe("Rectangle color as hex string"),
      filled: z
        .boolean()
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

  server.tool(
    "draw_ellipse",
    "Draw an ellipse (or circle if rx == ry) centered at (cx, cy) with the given radii.",
    {
      cx: z.number().int().describe("Center X coordinate"),
      cy: z.number().int().describe("Center Y coordinate"),
      rx: z.number().int().min(1).describe("Horizontal radius in pixels"),
      ry: z.number().int().min(1).describe("Vertical radius in pixels"),
      color: z
        .string()
        .default("#000000")
        .describe("Ellipse color as hex string"),
      filled: z
        .boolean()
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

  server.tool(
    "fill_area",
    "Flood-fill a contiguous area starting from the seed pixel at (x, y). Fills all connected pixels of the same color with the new color.",
    {
      x: z.number().int().describe("Seed X coordinate for flood fill"),
      y: z.number().int().describe("Seed Y coordinate for flood fill"),
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

  server.tool(
    "draw_pixels",
    "Batch draw multiple pixels in a single operation. Much faster than calling draw_pixel repeatedly. All pixels are committed as a single undoable action. Use this for complex shapes, sprite art, or any multi-pixel drawing.",
    {
      pixels: z
        .array(
          z.object({
            x: z.number().int().describe("X coordinate"),
            y: z.number().int().describe("Y coordinate"),
            color: z.string().describe("Pixel color as hex string"),
          })
        )
        .min(1)
        .describe("Array of pixel objects, each with x, y, and color"),
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

  server.tool(
    "get_canvas_snapshot",
    "Get a snapshot of the current canvas content. Returns pixel data as a color-indexed grid. Useful for inspecting what's currently drawn before making changes. Keep the region small (e.g. 32x32) for faster response.",
    {
      x: z
        .number()
        .int()
        .default(0)
        .describe("Top-left X coordinate of the region to snapshot"),
      y: z
        .number()
        .int()
        .default(0)
        .describe("Top-left Y coordinate of the region to snapshot"),
      width: z
        .number()
        .int()
        .min(1)
        .max(128)
        .default(32)
        .describe("Width of the snapshot region (max 128)"),
      height: z
        .number()
        .int()
        .min(1)
        .max(128)
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

  server.tool(
    "draw_path",
    "Draw a path of connected lines.",
    {
      points: z
        .array(
          z.object({
            x: z.number().int(),
            y: z.number().int(),
          })
        )
        .min(2)
        .describe("Array of point objects {x, y}"),
      closed: z
        .boolean()
        .default(false)
        .describe("If true, a line is drawn from the last point back to the first"),
      color: z.string().default("#000000").describe("Path color as hex string"),
    },
    async ({ points, closed, color }) => {
      const result = await sendCommand("draw_path", { points, closed, color });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Path drawn with ${points.length} points` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "draw_polygon",
    "Draw a polygon defined by an array of points. Can be filled or outline only.",
    {
      points: z
        .array(
          z.object({
            x: z.number().int(),
            y: z.number().int(),
          })
        )
        .min(3)
        .describe("Array of point objects {x, y}"),
      filled: z
        .boolean()
        .default(true)
        .describe("If true, fill the polygon; if false, draw outline only"),
      color: z.string().default("#000000").describe("Polygon color as hex string"),
    },
    async ({ points, filled, color }) => {
      const result = await sendCommand("draw_polygon", { points, filled, color });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Polygon drawn with ${points.length} points (${filled ? "filled" : "outline"})` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
