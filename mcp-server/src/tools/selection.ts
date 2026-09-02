/**
 * Selection Tools
 *
 * Tools for selecting regions of the canvas.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat } from "../utils/schema_helpers.js";

export function registerSelectionTools(server: McpServer): void {
  server.tool(
    "select_rect",
    "Select a rectangular region of the canvas. Use operation to combine with existing selection.",
    {
      x: coerceInt().describe("Top-left X coordinate of the selection"),
      y: coerceInt().describe("Top-left Y coordinate of the selection"),
      width: coerceInt(1).describe("Selection width"),
      height: coerceInt(1).describe("Selection height"),
      operation: coerceInt(0, 2)
        .default(0)
        .describe("0 = add to selection, 1 = subtract, 2 = intersect"),
    },
    async ({ x, y, width, height, operation }) => {
      const result = await sendCommand("select_rect", {
        x,
        y,
        width,
        height,
        operation,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Selected rect at (${x},${y}) size ${width}×${height}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "select_all",
    "Select the entire canvas area.",
    {},
    async () => {
      const result = await sendCommand("select_all", {});
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? "✅ Selected all"
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "deselect",
    "Clear the current selection.",
    {},
    async () => {
      const result = await sendCommand("deselect", {});
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? "✅ Selection cleared"
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "select_by_color",
    "Select pixels by color (Magic Wand selection). Can select all matching pixels on the canvas or contiguous flood-filled matching pixels.",
    {
      color: z.string().describe("Hex color to match (e.g. '#e74c3c')"),
      tolerance: coerceFloat(0, 1).default(0.05).describe("Color match tolerance (0.0 = exact match, 0.2 = loose match)"),
      contiguous: z.boolean().default(false).describe("If true, only selects contiguous connected pixels from start_x, start_y"),
      start_x: coerceInt(0).default(0).describe("Starting X position for contiguous flood fill"),
      start_y: coerceInt(0).default(0).describe("Starting Y position for contiguous flood fill"),
    },
    async ({ color, tolerance, contiguous, start_x, start_y }) => {
      const result = await sendCommand("select_by_color", {
        color,
        tolerance,
        contiguous,
        start_x,
        start_y,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Selected ${result.data?.selected_pixels} pixels matching ${color} (Contiguous: ${contiguous})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "invert_selection",
    "Invert the current selection mask (unselected pixels become selected, and vice versa).",
    {},
    async () => {
      const result = await sendCommand("invert_selection", {});
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Selection inverted (Has selection: ${result.data?.has_selection})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "transform_selection",
    "Translate (dx, dy) only the currently selected pixels on the active cel without affecting unselected pixels.",
    {
      dx: coerceInt().default(0).describe("Horizontal offset in pixels to shift selected region"),
      dy: coerceInt().default(0).describe("Vertical offset in pixels to shift selected region"),
    },
    async ({ dx, dy }) => {
      const result = await sendCommand("transform_selection", { dx, dy });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Shifted ${result.data?.transformed_pixels} selected pixels by dx=${dx}, dy=${dy}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
