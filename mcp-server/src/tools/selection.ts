/**
 * Selection Tools
 *
 * Tools for selecting regions of the canvas.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt } from "../utils/schema_helpers.js";

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
}
