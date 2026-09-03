/**
 * Color & Palette Tools
 *
 * Tools for setting/querying colors, palette management, color replacement,
 * and HSV color adjustments.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat, coerceBool } from "../utils/schema_helpers.js";

export function registerColorTools(server: McpServer): void {
  server.tool(
    "set_color",
    "Set the active drawing color (foreground or background). This affects all subsequent drawing operations.",
    {
      color: z
        .string()
        .describe("Color as hex string (e.g. '#FF5733', '#00FF00')"),
      button: coerceInt(0, 1)
        .default(0)
        .describe("0 for foreground (left mouse button), 1 for background (right mouse button)"),
    },
    async ({ color, button }) => {
      const hexRegex = /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;
      if (!hexRegex.test(color.trim())) {
        return {
          content: [
            {
              type: "text" as const,
              text: `❌ Invalid color hex format: "${color}". Expected valid hex color such as '#FF5733' or '#00FF00'`,
            },
          ],
        };
      }
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
    "color_replace",
    "Replace all pixels of old_color with new_color on the target cel. Invaluable for palette swapping, elemental variants (fire/ice armor), shiny monsters, and skin tone adjustments.",
    {
      old_color: z.string().describe("Hex color to be replaced (e.g. '#e74c3c')"),
      new_color: z.string().describe("New hex color to replace with (e.g. '#3498db')"),
      tolerance: coerceFloat(0, 1)
        .default(0.05)
        .describe("Color distance tolerance (0.0 = exact match, 0.1 = includes near shades)"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ old_color, new_color, tolerance, layer, frame }) => {
      const result = await sendCommand("color_replace", { old_color, new_color, tolerance, layer, frame });
      if (result.success && result.data) {
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Replaced ${result.data.replaced_pixels} pixels from ${old_color} to ${new_color} on [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "adjust_hsv",
    "Adjust Hue, Saturation, and Brightness/Value on the target cel. Perfect for environmental tints (night/dungeon darkness, poison green glow, frozen blue tint).",
    {
      hue_shift: coerceFloat(-180, 180)
        .default(0)
        .describe("Hue shift in degrees (-180 to +180)"),
      saturation: coerceFloat(0, 5)
        .default(1.0)
        .describe("Saturation multiplier (0 = grayscale, 1.0 = original, 2.0 = highly vibrant)"),
      value: coerceFloat(0, 5)
        .default(1.0)
        .describe("Value/Brightness multiplier (0 = black, 1.0 = original, 1.5 = brighter)"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ hue_shift, saturation, value, layer, frame }) => {
      const result = await sendCommand("adjust_hsv", { hue_shift, saturation, value, layer, frame });
      if (result.success && result.data) {
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Adjusted HSV on ${result.data.modified_pixels} pixels (Hue: ${hue_shift}°, Sat: ${saturation}x, Val: ${value}x) on [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
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
      width: coerceInt(1).default(8).describe("Palette width"),
      height: coerceInt(1).default(8).describe("Palette height"),
      is_global: coerceBool().default(true).describe("If true, saves globally. If false, saves to project."),
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
      index: coerceInt(0).describe("Index in the palette"),
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

  server.tool(
    "get_palette_usage",
    "Analyze the active canvas and return an exact histogram/frequency list of all unique colors used, total pixel counts, and percentages.",
    {},
    async () => {
      const result = await sendCommand("get_palette_usage", {});
      if (result.success && result.data) {
        const colors = (result.data.colors as Array<{ color: string; count: number; percentage: number }>)
          .slice(0, 32)
          .map((c) => `  ${c.color}: ${c.count} px (${c.percentage}%)`)
          .join("\n");
        return {
          content: [
            {
              type: "text" as const,
              text: `🎨 Canvas Palette Usage (${result.data.unique_colors_count} unique colors, ${result.data.total_colored_pixels} total pixels):\n${colors}`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "clean_isolated_pixels",
    "Automatically scan the canvas and remove/blend orphan 1px noise (isolated rogue pixels with 0 matching neighbors) for clean retro pixel art.",
    {},
    async () => {
      const result = await sendCommand("clean_isolated_pixels", {});
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Cleaned ${result.data?.isolated_pixels_cleaned} isolated noise pixels from active cel`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "remap_to_palette",
    "Quantize and snap all canvas pixels to the closest matching Euclidean color in the specified palette array.",
    {
      palette_colors: z.array(z.string()).describe("Array of hex colors to quantize onto (e.g. ['#000000', '#ffffff', '#e74c3c'])"),
    },
    async ({ palette_colors }) => {
      const result = await sendCommand("remap_to_palette", { palette_colors });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Remapped ${result.data?.remapped_pixels} pixels to ${result.data?.palette_size}-color palette`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
