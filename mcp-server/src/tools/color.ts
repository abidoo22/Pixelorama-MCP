/**
 * Color Tools
 *
 * Tools for setting and querying the active foreground/background colors.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";

export function registerColorTools(server: McpServer): void {
  server.tool(
    "set_color",
    "Set the active drawing color (foreground or background). This affects all subsequent drawing operations.",
    {
      color: z
        .string()
        .describe("Color as hex string (e.g. '#FF5733', '#00FF00')"),
      button: z
        .number()
        .int()
        .min(0)
        .max(1)
        .default(0)
        .describe("0 for foreground (left mouse button), 1 for background (right mouse button)"),
    },
    async ({ color, button }) => {
      const result = await sendCommand("set_color", { color, button });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ ${button === 0 ? "Foreground" : "Background"} color set to ${color}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "get_color",
    "Get the current foreground and background drawing colors.",
    {},
    async () => {
      const result = await sendCommand("get_color", {});
      if (result.success && result.data) {
        return {
          content: [
            {
              type: "text" as const,
              text: `Colors:\n- Foreground: ${result.data.foreground}\n- Background: ${result.data.background}`,
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
    "get_palette_colors",
    "Get all colors in the currently active palette. Returns the palette name, dimensions, and all color swatches with their indices.",
    {},
    async () => {
      const result = await sendCommand("get_palette_colors", {});
      if (result.success && result.data) {
        const d = result.data;
        const colors = d.colors as Array<{ index: number; color: string }>;
        const colorList = colors
          .map((c) => `  [${c.index}] ${c.color}`)
          .join("\n");
        return {
          content: [
            {
              type: "text" as const,
              text: `Palette: ${d.palette_name} (${d.width}×${d.height})\n${colorList}`,
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
    "create_palette",
    "Create a new empty palette.",
    {
      name: z.string().describe("Name of the new palette"),
      width: z.number().int().min(1).default(8).describe("Palette width"),
      height: z.number().int().min(1).default(8).describe("Palette height"),
      is_global: z.boolean().default(true).describe("If true, saves globally. If false, saves to project."),
    },
    async ({ name, width, height, is_global }) => {
      const result = await sendCommand("create_palette", { name, width, height, is_global });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Palette "${name}" created (${width}x${height})` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "add_palette_color",
    "Add a color to the currently active palette.",
    {
      color: z.string().describe("Color hex string"),
    },
    async ({ color }) => {
      const result = await sendCommand("add_palette_color", { color });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Color ${color} added to palette` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "set_palette_color",
    "Set the color at a specific index in the currently active palette.",
    {
      index: z.number().int().min(0).describe("Index in the palette"),
      color: z.string().describe("Color hex string"),
    },
    async ({ index, color }) => {
      const result = await sendCommand("set_palette_color", { index, color });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Color at index ${index} set to ${color}` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
