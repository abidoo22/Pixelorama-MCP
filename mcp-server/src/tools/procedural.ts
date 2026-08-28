/**
 * Procedural Game Art Helpers
 *
 * Tools for fast, game-ready pixel art workflows: outlines, color ramp generation,
 * mirroring/symmetry, and dithering patterns.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";

// Helper: Convert Hex to RGB
function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const clean = hex.replace("#", "");
  const num = parseInt(clean, 16);
  return {
    r: (num >> 16) & 255,
    g: (num >> 8) & 255,
    b: num & 255,
  };
}

// Helper: Convert RGB to Hex
function rgbToHex(r: number, g: number, b: number): string {
  const clR = Math.max(0, Math.min(255, Math.round(r)));
  const clG = Math.max(0, Math.min(255, Math.round(g)));
  const clB = Math.max(0, Math.min(255, Math.round(b)));
  return "#" + ((1 << 24) | (clR << 16) | (clG << 8) | clB).toString(16).slice(1);
}

// Calculate color ramps (highlight, base, shadow, dark_shadow) with hue-shifting
function generateRamp(baseHex: string): {
  highlight: string;
  light: string;
  base: string;
  shadow: string;
  deepShadow: string;
} {
  const { r, g, b } = hexToRgb(baseHex);

  // Perceptual brightness adjustment with subtle warm highlight / cool shadow hue shifting
  const highlight = rgbToHex(r * 1.35 + 30, g * 1.35 + 25, b * 1.25 + 10);
  const light = rgbToHex(r * 1.15 + 15, g * 1.15 + 12, b * 1.10 + 5);
  const base = rgbToHex(r, g, b);
  const shadow = rgbToHex(r * 0.70 - 10, g * 0.65 - 10, b * 0.75 + 5);
  const deepShadow = rgbToHex(r * 0.40 - 20, g * 0.35 - 20, b * 0.45);

  return {
    highlight,
    light,
    base,
    shadow,
    deepShadow,
  };
}

export function registerProceduralTools(server: McpServer): void {
  server.tool(
    "apply_outline",
    "Automatically generate an outline around all non-transparent pixels on the active layer. Great for character silhouettes and game items.",
    {
      color: z
        .string()
        .default("#000000")
        .describe("Outline hex color (e.g. '#000000' or '#1a1020')"),
      thickness: z
        .number()
        .int()
        .min(1)
        .max(4)
        .default(1)
        .describe("Outline thickness in pixels (1-4, default: 1)"),
      inside: z
        .boolean()
        .default(false)
        .describe("If true, replaces outer pixels of the sprite; if false, expands into transparent pixels around the sprite"),
    },
    async ({ color, thickness, inside }) => {
      const result = await sendCommand("apply_outline", { color, thickness, inside });
      if (result.success && result.data) {
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Outline applied: ${result.data.outline_pixels} pixels with color ${color} (thickness: ${thickness}px, ${inside ? "inner" : "outer"})`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "mirror_layer",
    "Mirror or flip the active cel image. Essential for creating symmetrical characters, monsters, weapons, chests, and vehicles.",
    {
      axis: z
        .enum(["horizontal", "vertical"])
        .default("horizontal")
        .describe("Axis to mirror on: 'horizontal' or 'vertical'"),
      mode: z
        .enum(["flip", "mirror_left_to_right", "mirror_right_to_left", "mirror_top_to_bottom"])
        .default("mirror_left_to_right")
        .describe("Operation mode: 'flip' (flips entire layer) or 'mirror_left_to_right' (copies left half onto right half)"),
    },
    async ({ axis, mode }) => {
      const result = await sendCommand("mirror_layer", { axis, mode });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Cel mirrored (${mode})` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "generate_color_ramp",
    "Calculate a professional 5-step shading color ramp from a single base color using perceptual lighting and hue-shifting math (highlight, light, base, shadow, deep shadow).",
    {
      base_color: z.string().describe("Base hex color (e.g. '#e74c3c' for red armor, '#3498db' for blue tunic)"),
    },
    async ({ base_color }) => {
      const ramp = generateRamp(base_color);
      const text = `# Color Ramp for ${base_color}\n` +
        `- **Highlight**: \`${ramp.highlight}\` (specular reflections, top edges)\n` +
        `- **Light**: \`${ramp.light}\` (direct light)\n` +
        `- **Base**: \`${ramp.base}\` (primary color)\n` +
        `- **Shadow**: \`${ramp.shadow}\` (ambient / core shadow)\n` +
        `- **Deep Shadow**: \`${ramp.deepShadow}\` (occlusion crevices / bottom)\n\n` +
        `Use these hex values when drawing with \`draw_pixels\` or adding to palette with \`add_palette_color\`.`;

      return { content: [{ type: "text" as const, text }] };
    }
  );

  server.tool(
    "apply_dithering",
    "Fill a rectangular area with a 2x2 checkerboard dither pattern between two colors to blend shading smoothly without color noise.",
    {
      x: z.number().int().describe("Top-left X coordinate"),
      y: z.number().int().describe("Top-left Y coordinate"),
      width: z.number().int().min(1).describe("Width of dither region"),
      height: z.number().int().min(1).describe("Height of dither region"),
      color1: z.string().describe("First hex color (e.g. highlight or base)"),
      color2: z.string().describe("Second hex color (e.g. shadow)"),
      pattern: z.enum(["checker_50", "light_25", "dense_75"]).default("checker_50").describe("Dither density"),
    },
    async ({ x, y, width, height, color1, color2, pattern }) => {
      const pixels: Array<{ x: number; y: number; color: string }> = [];

      for (let py = y; py < y + height; py++) {
        for (let px = x; px < x + width; px++) {
          let useColor2 = false;
          if (pattern === "checker_50") {
            useColor2 = (px + py) % 2 === 0;
          } else if (pattern === "light_25") {
            useColor2 = px % 2 === 0 && py % 2 === 0;
          } else if (pattern === "dense_75") {
            useColor2 = !(px % 2 === 1 && py % 2 === 1);
          }
          pixels.push({ x: px, y: py, color: useColor2 ? color2 : color1 });
        }
      }

      const result = await sendCommand("draw_pixels", { pixels });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Dither applied at (${x},${y}) size ${width}×${height} (${pattern})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
