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
    "Create a new palette, with optional batch colors array to populate swatches in a single tool call.",
    {
      name: z.string().describe("Name of the new palette"),
      width: coerceInt(1).default(8).describe("Palette width"),
      height: coerceInt(1).default(8).describe("Palette height"),
      is_global: coerceBool().default(true).describe("If true, saves globally. If false, saves to project."),
      colors: z.array(z.string()).optional().describe("Optional array of hex color strings to populate immediately in batch (e.g. ['#1a1a2e', '#16213e', '#0f3460', '#e94560'])"),
    },
    async ({ name, width, height, is_global, colors }) => {
      const result = await sendCommand("create_palette", { name, width, height, is_global, colors });
      const finalW = result.data?.width ?? width;
      const finalH = result.data?.height ?? height;
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Palette "${name}" created (${finalW}x${finalH})${result.data?.colors_added ? ` with ${result.data.colors_added} colors` : ""}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "add_palette_color",
    "Add one or multiple colors to the currently active palette in batch.",
    {
      color: z.string().optional().describe("Single color hex string to add (e.g. '#ff0000')"),
      colors: z.array(z.string()).optional().describe("Optional array of hex color strings to add in bulk (e.g. ['#ff0000', '#00ff00', '#0000ff'])"),
    },
    async ({ color, colors }) => {
      const result = await sendCommand("add_palette_color", { color, colors });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Added ${result.data?.colors_added ?? 1} color(s) to palette "${result.data?.palette_name}"`
              : `❌ ${result.error}`,
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
    "list_palettes",
    "List all available palettes in Pixelorama (both global and project palettes), including dimensions, color count, and which one is active.",
    {},
    async () => {
      const result = await sendCommand("list_palettes", {});
      if (result.success && result.data) {
        const d = result.data;
        const palettes = (d.palettes || []) as Array<{
          name: string;
          width: number;
          height: number;
          colors_count: number;
          is_global: boolean;
          is_active: boolean;
        }>;
        if (palettes.length === 0) {
          return { content: [{ type: "text" as const, text: "No palettes found." }] };
        }
        const lines = palettes.map(
          (p) =>
            `• ${p.is_active ? "⭐ [ACTIVE] " : ""}${p.name} (${p.width}x${p.height}, ${p.colors_count} colors, ${p.is_global ? "global" : "project"})`
        );
        return {
          content: [
            {
              type: "text" as const,
              text: `Palettes (${palettes.length} total, active: "${d.active_palette}"):\n${lines.join("\n")}`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "switch_palette",
    "Switch the active palette in Pixelorama by name.",
    {
      name: z.string().describe("The name of the palette to switch to"),
    },
    async ({ name }) => {
      const result = await sendCommand("switch_palette", { name });
      if (result.success && result.data) {
        const d = result.data;
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Switched to palette "${d.name}" (${d.width}x${d.height}, ${d.colors_count} colors, ${d.is_global ? "global" : "project"})`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "delete_palette",
    "Delete a palette by name from Pixelorama.",
    {
      name: z.string().describe("The name of the palette to delete"),
    },
    async ({ name }) => {
      const result = await sendCommand("delete_palette", { name });
      if (result.success && result.data) {
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ ${result.data.message || `Palette "${name}" deleted`}`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "get_palette_usage",
    "Analyze the palette usage of the canvas (or a specific layer) and return an exact histogram of all unique colors used, total pixel counts, and percentages.",
    {
      all_layers: coerceBool().default(true).describe("If true, analyzes the full composite of all visible layers. If false, analyzes only the specified or active layer."),
      layer: coerceInt(0).optional().describe("Target layer index to analyze when all_layers is false (defaults to active layer)"),
      frame: coerceInt(0).optional().describe("Target frame index to analyze (defaults to active frame)"),
    },
    async ({ all_layers, layer, frame }) => {
      const result = await sendCommand("get_palette_usage", { all_layers, layer, frame });
      if (result.success && result.data) {
        const colors = (result.data.colors as Array<{ color: string; count: number; percentage: number }>)
          .slice(0, 32)
          .map((c) => `  ${c.color}: ${c.count} px (${c.percentage}%)`)
          .join("\n");
        return {
          content: [
            {
              type: "text" as const,
              text: `🎨 Palette Usage [${result.data.all_layers ? "Full Canvas Composite" : `Layer ${layer ?? "active"}`}] (${result.data.unique_colors_count} unique colors, ${result.data.total_colored_pixels} colored pixels):\n${colors}`,
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
