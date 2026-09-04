/**
 * Procedural Game Art Helpers
 *
 * Tools for fast, game-ready pixel art workflows: outlines, color ramp generation,
 * mirroring/symmetry, and dithering patterns.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat, coerceBool } from "../utils/schema_helpers.js";

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
    "Automatically generate an outline around all non-transparent pixels on the target layer. Great for character silhouettes and game items.",
    {
      color: z
        .string()
        .default("#000000")
        .describe("Outline hex color (e.g. '#000000' or '#1a1020')"),
      thickness: coerceInt(1, 4)
        .default(1)
        .describe("Outline thickness in pixels (1-4, default: 1)"),
      inside: coerceBool()
        .default(false)
        .describe("If true, replaces outer pixels of the sprite; if false, expands into transparent pixels around the sprite"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ color, thickness, inside, layer, frame }) => {
      const result = await sendCommand("apply_outline", { color, thickness, inside, layer, frame });
      if (result.success && result.data) {
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Outline applied: ${result.data.outline_pixels} pixels with color ${color} (thickness: ${thickness}px, ${inside ? "inner" : "outer"}) on [frame:${result.data.frame}, layer:${result.data.layer}]`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "mirror_layer",
    "Mirror or flip the target cel image. Essential for creating symmetrical characters, monsters, weapons, chests, and vehicles.",
    {
      axis: z
        .enum(["horizontal", "vertical"])
        .default("horizontal")
        .describe("Axis to mirror on: 'horizontal' or 'vertical'"),
      mode: z
        .enum(["flip", "mirror_left_to_right", "mirror_right_to_left", "mirror_top_to_bottom"])
        .default("mirror_left_to_right")
        .describe("Operation mode: 'flip' (flips entire layer) or 'mirror_left_to_right' (copies left half onto right half)"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ axis, mode, layer, frame }) => {
      const result = await sendCommand("mirror_layer", { axis, mode, layer, frame });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Cel mirrored (${mode}) on [frame:${result.data?.frame}, layer:${result.data?.layer}]` : `❌ ${result.error}`,
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
      x: coerceInt().describe("Top-left X coordinate"),
      y: coerceInt().describe("Top-left Y coordinate"),
      width: coerceInt(1).describe("Width of dither region"),
      height: coerceInt(1).describe("Height of dither region"),
      color1: z.string().describe("First hex color (e.g. highlight or base)"),
      color2: z.string().describe("Second hex color (e.g. shadow)"),
      pattern: z.enum(["checker_50", "light_25", "dense_75"]).default("checker_50").describe("Dither density"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ x, y, width, height, color1, color2, pattern, layer, frame }) => {
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

      const result = await sendCommand("draw_pixels", { pixels, layer, frame });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Dither applied at (${x},${y}) size ${width}×${height} (${pattern}) on [frame:${result.data?.frame}, layer:${result.data?.layer}]`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "apply_drop_shadow",
    "Generate a cast drop shadow from the sprite's silhouette with customizable offsets, color, opacity, or create it as a separate layer.",
    {
      offset_x: coerceInt().default(1).describe("Horizontal shadow offset in pixels"),
      offset_y: coerceInt().default(1).describe("Vertical shadow offset in pixels"),
      color: z.string().default("#000000").describe("Shadow hex color"),
      opacity: coerceFloat(0, 1).default(0.5).describe("Shadow opacity as float (0.0 to 1.0)"),
      as_new_layer: coerceBool().default(false).describe("If true, generates the shadow onto a dedicated layer beneath the sprite"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ offset_x, offset_y, color, opacity, as_new_layer, layer, frame }) => {
      const result = await sendCommand("apply_drop_shadow", {
        offset_x,
        offset_y,
        color,
        opacity,
        as_new_layer,
        layer,
        frame,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Drop Shadow applied: ${result.data?.shadow_pixels} pixels (offset: [${offset_x}, ${offset_y}], opacity: ${opacity}, new layer: ${as_new_layer}) on [frame:${result.data?.frame}, layer:${result.data?.layer}]`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "apply_glow",
    "Generate a soft glowing halo / bloom around non-transparent pixels (ideal for magic weapons, neon lights, glowing eyes, or cyberpunk art).",
    {
      radius: coerceInt(1, 10).default(2).describe("Glow halo radius in pixels"),
      color: z.string().default("#3498db").describe("Glow hex color"),
      intensity: coerceFloat(0, 1).default(0.6).describe("Glow intensity as float (0.0 to 1.0)"),
      as_new_layer: coerceBool()
        .default(false)
        .describe("If true, places the glow on a new layer behind current layer instead of merging"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ radius, color, intensity, as_new_layer, layer, frame }) => {
      const result = await sendCommand("apply_glow", { radius, color, intensity, as_new_layer, layer, frame });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Glow effect applied with radius ${radius}px, color ${color}, intensity ${intensity} (new layer: ${as_new_layer}) on [frame:${result.data?.frame}, layer:${result.data?.layer}]`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "apply_gradient",
    "Fill a region with a smooth linear or radial color gradient, with optional ordered dithering (Bayer 4x4 matrix). Automatically clips to active selection if one exists.",
    {
      x1: coerceInt(0).default(0).describe("Top-left X of gradient area"),
      y1: coerceInt(0).default(0).describe("Top-left Y of gradient area"),
      x2: coerceInt(1).default(64).describe("Bottom-right X of gradient area"),
      y2: coerceInt(1).default(64).describe("Bottom-right Y of gradient area"),
      color1: z.string().default("#ffffff").describe("Start hex color"),
      color2: z.string().default("#000000").describe("End hex color"),
      dither: coerceBool().default(true).describe("Enable Bayer ordered dithering"),
      type: z.enum(["linear", "radial"]).default("linear").describe("Gradient type: 'linear' or 'radial'"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ x1, y1, x2, y2, color1, color2, dither, type, layer, frame }) => {
      const result = await sendCommand("apply_gradient", {
        x1,
        y1,
        x2,
        y2,
        color1,
        color2,
        dither,
        type,
        layer,
        frame,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ ${type.toUpperCase()} Gradient applied with ${dither ? "Bayer dithering" : "smooth blend"} from ${color1} to ${color2} on [frame:${result.data?.frame}, layer:${result.data?.layer}]${result.data?.selection_clipped ? " (clipped to selection)" : ""}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "check_seamless_tile",
    "Validate and optionally fix border seams on tiles so that top/bottom and left/right edges wrap seamlessly. Supports tile grid dimensions for multi-tile tileset canvases.",
    {
      tile_width: coerceInt(1).optional().describe("Tile width in pixels for multi-tile tilesets (defaults to full canvas width)"),
      tile_height: coerceInt(1).optional().describe("Tile height in pixels for multi-tile tilesets (defaults to full canvas height)"),
      fix_seams: coerceBool().default(false).describe("If true, automatically blends/fixes border seams to make tiles seamless"),
      dry_run: coerceBool().default(false).describe("If true with fix_seams, simulates seam correction without modifying canvas pixels"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ tile_width, tile_height, fix_seams, dry_run, layer, frame }) => {
      const params: Record<string, unknown> = { fix_seams, dry_run };
      if (tile_width !== undefined) params.tile_width = tile_width;
      if (tile_height !== undefined) params.tile_height = tile_height;
      if (layer !== undefined) params.layer = layer;
      if (frame !== undefined) params.frame = frame;
      const result = await sendCommand("check_seamless_tile", params);
      if (result.success && result.data) {
        const d = result.data;
        let text = d.is_seamless
          ? `✅ All ${d.tiles_checked ?? 1} tile(s) (${d.tile_width}×${d.tile_height}) are 100% SEAMLESS!`
          : `⚠️ Seamless tile errors detected across ${d.tiles_checked ?? 1} tile(s): ${d.horizontal_seam_errors} horizontal mismatches, ${d.vertical_seam_errors} vertical mismatches.`;
        if (d.seams_fixed) {
          text += `\n🔧 Seams were automatically blended and fixed!`;
        } else if (fix_seams && dry_run) {
          text += `\n🔎 Dry-run mode: no pixels modified. Run with dry_run: false to commit fixes.`;
        } else if (!d.is_seamless) {
          text += `\n💡 Pass fix_seams: true to auto-correct.`;
        }
        return {
          content: [
            {
              type: "text" as const,
              text,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "draw_text",
    "Render crisp pixel typography / bitmap font directly onto the canvas (essential for dialogue boxes, title screens, damage numbers, and HUDs).",
    {
      text: z.string().describe("Text string to draw"),
      x: coerceInt().default(0).describe("Starting X position in pixels"),
      y: coerceInt().default(0).describe("Starting Y position in pixels"),
      color: z.string().default("#ffffff").describe("Font hex color"),
      font_size: coerceInt(4, 32).default(8).describe("Font line height in pixels"),
      layer: coerceInt().optional().describe("Optional target layer index (defaults to active layer)"),
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ text, x, y, color, font_size, layer, frame }) => {
      const result = await sendCommand("draw_text", {
        text,
        x,
        y,
        color,
        font_size,
        layer,
        frame,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Rendered "${text}" (${result.data?.chars_drawn} characters) at (${x}, ${y}) with color ${color} on [frame:${result.data?.frame}, layer:${result.data?.layer}]`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
