/**
 * Procedural Game Art Helpers
 *
 * Tools for fast, game-ready pixel art workflows: outlines, color ramp generation,
 * mirroring/symmetry, and dithering patterns.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat, coerceBool, layerHandleSchema, frameRangeFields } from "../utils/schema_helpers.js";

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
    "Automatically generate an outline around all non-transparent pixels on the target layer across one or multiple frames. Accepts layer index, stable ID, or layer name, plus multi-frame targeting ('frames', 'from_frame'/'to_frame', 'tag', 'all_frames').",
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
      layer: layerHandleSchema,
      frame: coerceInt().optional().describe("Optional single target frame index (defaults to active frame when no batch selector is given)"),
      ...frameRangeFields,
    },
    async ({ color, thickness, inside, layer, frame, frames, from_frame, to_frame, tag, all_frames }) => {
      const params: Record<string, unknown> = { color, thickness, inside };
      if (layer !== undefined) params.layer = layer;
      if (frame !== undefined) params.frame = frame;
      if (frames !== undefined) params.frames = frames;
      if (from_frame !== undefined) params.from_frame = from_frame;
      if (to_frame !== undefined) params.to_frame = to_frame;
      if (tag !== undefined) params.tag = tag;
      if (all_frames !== undefined) params.all_frames = all_frames;
      const result = await sendCommand("apply_outline", params);
      if (result.success && result.data) {
        const count = result.data.frames_processed ?? 1;
        const frameLabel =
          count > 1
            ? `frames:[${(result.data.frames as number[]).join(",")}]`
            : `frame:${result.data.frame}`;
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Outline applied: ${result.data.outline_pixels} pixels with color ${color} (thickness: ${thickness}px, ${inside ? "inner" : "outer"}) on [${frameLabel}, layer:${result.data.layer}]`,
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
        .describe("Axis used when mode is 'flip': 'horizontal' flips horizontally (left-to-right reflection), 'vertical' flips vertically (top-to-bottom reflection)"),
      mode: z
        .enum(["flip", "mirror_left_to_right", "mirror_right_to_left", "mirror_top_to_bottom", "mirror_bottom_to_top"])
        .default("mirror_left_to_right")
        .describe("Operation mode: 'flip' (flips entire layer along axis), 'mirror_left_to_right' (copies left half onto right half for symmetrical sprites), 'mirror_right_to_left', 'mirror_top_to_bottom', or 'mirror_bottom_to_top'"),
      layer: layerHandleSchema,
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
    "Fill a rectangular, elliptical, or selected region with a pixel-art dither pattern between two colors (or stamp a single shadow/highlight color while keeping alternating pixels intact). Supports active selection clipping ('within_selection'), alpha preservation ('preserve_alpha': only dithers existing opaque pixels), string layer handles, and multi-frame targeting.",
    {
      x: coerceInt().optional().describe("Top-left X coordinate (defaults to selection bounds or 0)"),
      y: coerceInt().optional().describe("Top-left Y coordinate (defaults to selection bounds or 0)"),
      width: coerceInt(1).optional().describe("Width of dither region (defaults to selection width or canvas width)"),
      height: coerceInt(1).optional().describe("Height of dither region (defaults to selection height or canvas height)"),
      color1: z
        .string()
        .optional()
        .describe("First hex color, or 'keep'/omitted to leave alternating pixels untouched (ideal for non-destructive shading)"),
      color2: z
        .string()
        .optional()
        .describe("Second hex color (or 'keep'/omitted to only draw color1 pixels)"),
      pattern: z
        .enum(["checker_50", "light_25", "dense_75", "bayer_25", "bayer_50", "bayer_75", "horizontal", "vertical", "diagonal"])
        .default("checker_50")
        .describe("Dither pattern density/style"),
      shape: z
        .enum(["rect", "ellipse"])
        .default("rect")
        .describe("Region mask shape: 'rect' (axis-aligned rectangle) or 'ellipse' (inscribed nub-free ellipse for curved shading / radial falloff)"),
      within_selection: coerceBool()
        .default(true)
        .describe("If true (default), clips dithering to the active Pixelorama selection when one exists"),
      preserve_alpha: coerceBool()
        .default(false)
        .describe("If true, only dithers pixels where the target cel is currently non-transparent (alpha > alpha_threshold)"),
      alpha_threshold: coerceFloat(0, 1)
        .default(0.01)
        .describe("Alpha threshold used when preserve_alpha=true (0.0..1.0, default: 0.01)"),
      blend: coerceBool()
        .default(false)
        .describe("If true, alpha-blends dither colors over existing pixels instead of overwriting"),
      layer: layerHandleSchema,
      frame: coerceInt().optional().describe("Optional single target frame index (defaults to active frame when no batch selector is given)"),
      ...frameRangeFields,
    },
    async ({
      x,
      y,
      width,
      height,
      color1,
      color2,
      pattern,
      shape,
      within_selection,
      preserve_alpha,
      alpha_threshold,
      blend,
      layer,
      frame,
      frames,
      from_frame,
      to_frame,
      tag,
      all_frames,
    }) => {
      const payload: Record<string, unknown> = {
        pattern,
        shape,
        within_selection,
        preserve_alpha,
        alpha_threshold,
        blend,
      };
      if (x !== undefined) payload.x = x;
      if (y !== undefined) payload.y = y;
      if (width !== undefined) payload.width = width;
      if (height !== undefined) payload.height = height;
      if (color1 !== undefined) payload.color1 = color1;
      if (color2 !== undefined) payload.color2 = color2;
      if (layer !== undefined) payload.layer = layer;
      if (frame !== undefined) payload.frame = frame;
      if (frames !== undefined) payload.frames = frames;
      if (from_frame !== undefined) payload.from_frame = from_frame;
      if (to_frame !== undefined) payload.to_frame = to_frame;
      if (tag !== undefined) payload.tag = tag;
      if (all_frames !== undefined) payload.all_frames = all_frames;

      const result = await sendCommand("apply_dithering", payload);
      if (result.success && result.data) {
        const d = result.data;
        const count = d.frames_processed ?? 1;
        const frameLabel =
          count > 1
            ? `frames:[${(d.frames as number[]).join(",")}]`
            : `frame:${d.frame}`;
        const masks: string[] = [];
        if (d.shape === "ellipse") masks.push("ellipse");
        if (d.within_selection) masks.push("selection-clipped");
        if (d.preserve_alpha) masks.push("preserve-alpha");
        const maskStr = masks.length > 0 ? ` [${masks.join(", ")}]` : "";
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Dither applied at (${d.x},${d.y}) size ${d.width}×${d.height} (${d.pattern}${maskStr}, ${d.pixels_drawn} px) on [${frameLabel}, layer:${d.layer}]`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
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
      layer: layerHandleSchema,
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
    "Generate a glowing bloom / halo around non-transparent pixels (ideal for lanterns, neon lights, magic, or celestial shrines). Additively blends over existing pixels so glowing cores remain bright. TIP: To prevent creating oversized blobs around the entire layer, use 'source_color', 'luminance_threshold', or 'rect' to target only the emitting light sources (e.g. lantern flame or magic crystal). When 'as_new_layer: true', inserts a dedicated glow layer directly above the source layer with ADD blend mode.",
    {
      radius: coerceInt(1, 16).default(2).describe("Glow halo radius in pixels (1..16)"),
      color: z.string().default("#3498db").describe("Glow hex color (e.g. #ffb703)"),
      intensity: coerceFloat(0, 1).default(0.6).describe("Glow intensity as float (0.0 to 1.0)"),
      source_color: z
        .string()
        .optional()
        .describe("Optional hex color (e.g. '#ffb703'). If set, only pixels matching this color will emit glow, leaving all other artwork untouched."),
      tolerance: coerceFloat(0, 1)
        .default(0.15)
        .describe("Color matching tolerance when source_color is provided (0.0=exact, 1.0=match all)"),
      luminance_threshold: coerceFloat(0, 1)
        .optional()
        .describe("Optional minimum brightness threshold (0.0..1.0). If set, only pixels brighter than this threshold emit glow (ideal for lights/lanterns without glowing dark outlines/bark)."),
      falloff: z
        .enum(["smooth", "linear", "dither"])
        .default("smooth")
        .describe("Falloff curve: 'smooth' (quadratic falloff preventing solid blocky halos), 'linear', or 'dither' (Bayer matrix dithered pixel-art light)."),
      rect: z
        .array(coerceInt(0))
        .length(4)
        .optional()
        .describe("Optional [x, y, width, height] bounding box to restrict glow emission to a specific rectangular region."),
      as_new_layer: coerceBool()
        .default(false)
        .describe("If true, places the glow on a dedicated layer inserted directly above the target layer with ADD blend mode"),
      layer: layerHandleSchema,
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ radius, color, intensity, source_color, tolerance, luminance_threshold, falloff, rect, as_new_layer, layer, frame }) => {
      const params: Record<string, unknown> = { radius, color, intensity, tolerance, falloff, as_new_layer };
      if (source_color !== undefined) params.source_color = source_color;
      if (luminance_threshold !== undefined) params.luminance_threshold = luminance_threshold;
      if (rect !== undefined) params.rect = rect;
      if (layer !== undefined) params.layer = layer;
      if (frame !== undefined) params.frame = frame;

      const result = await sendCommand("apply_glow", params);
      const emitters = result.data?.emitters_found !== undefined ? ` (${result.data.emitters_found} emitters found)` : "";
      const glowPixels = result.data?.candidate_pixels !== undefined ? ` [${result.data.candidate_pixels} glow pixels]` : "";
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Glow effect applied with radius ${radius}px, color ${color}, intensity ${intensity}, falloff: ${falloff}${emitters}${glowPixels} (new layer: ${as_new_layer}) on [frame:${result.data?.frame}, layer:${result.data?.layer}]`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "apply_gradient",
    "Fill a region with a smooth linear, radial, or elliptical color gradient, with optional ordered dithering (Bayer 4x4 matrix), customizable falloff curves (smoothstep, inverse_square, exponential), feathering, and alpha-blending. Automatically clips to active selection if one exists.",
    {
      x1: coerceInt(0).default(0).describe("Top-left X of gradient area"),
      y1: coerceInt(0).default(0).describe("Top-left Y of gradient area"),
      x2: coerceInt(0).default(64).describe("Bottom-right X of gradient area"),
      y2: coerceInt(0).default(64).describe("Bottom-right Y of gradient area"),
      color1: z.string().default("#ffffff").describe("Start hex color"),
      color2: z.string().default("#000000").describe("End hex color"),
      blend: coerceBool().default(true).describe("If true, alpha-blends over underlying pixels instead of overwriting them"),
      dither: coerceBool().optional().describe("Enable Bayer ordered dithering (default: true for opaque gradients, auto-disabled for transparent/alpha endpoints)"),
      type: z.enum(["linear", "radial", "elliptical", "circle", "ellipse", "horizontal", "vertical"]).default("linear").describe("Gradient type / shape: 'linear', 'radial' (circular), or 'elliptical'"),
      shape: z.enum(["linear", "radial", "elliptical", "circle", "ellipse", "horizontal", "vertical"]).optional().describe("Alternative alias for type"),
      direction: z.enum(["vertical", "horizontal", "auto"]).default("auto").describe("Gradient direction for linear gradients: 'auto' (default, infers horizontal if width > height, else vertical), 'horizontal', or 'vertical'"),
      falloff: z.enum(["linear", "smoothstep", "smooth", "inverse_square", "exponential", "exp", "feather"]).default("linear").describe("Falloff curve: 'linear', 'smoothstep', 'inverse_square', or 'exponential'"),
      feather: coerceFloat(0.0, 1.0).default(0.0).describe("Feather edge softening amount (0.0 to 1.0)"),
      alpha: coerceFloat(0.0, 1.0).default(1.0).describe("Optional overall opacity multiplier (0.0 to 1.0, default: 1.0)"),
      layer: layerHandleSchema,
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({ x1, y1, x2, y2, color1, color2, blend, dither, type, shape, direction, falloff, feather, alpha, layer, frame }) => {
      const gradType = shape || type;
      const payload: Record<string, unknown> = {
        x1,
        y1,
        x2,
        y2,
        color1,
        color2,
        blend,
        type: gradType,
        shape: gradType,
        direction,
        falloff,
        feather,
        alpha,
        layer,
        frame,
      };
      if (dither !== undefined) {
        payload.dither = dither;
      }
      const result = await sendCommand("apply_gradient", payload);
      const ditherDesc = result.data?.dither ? "Bayer dithering" : "smooth blend";
      const resolvedDir = result.data?.direction || "linear";
      const inferredDir = result.data?.inferred_direction || resolvedDir;
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ ${gradType.toUpperCase()} Gradient [direction: "${resolvedDir}", inferred_direction: "${inferredDir}", dither: ${Boolean(result.data?.dither)}] (${resolvedDir} direction, ${falloff} falloff) applied with ${ditherDesc} from ${color1} to ${color2} (blend: ${blend}) on [frame:${result.data?.frame}, layer:${result.data?.layer}]${result.data?.selection_clipped ? " (clipped to selection)" : ""}`
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
      layer: layerHandleSchema,
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
    "Render crisp pixel typography / full printable ASCII (32–126) bitmap font directly onto the canvas — supports uppercase (A–Z), true lowercase (a–z with descenders), digits (0–9), and all standard ASCII punctuation/symbols, plus optional drop shadow, outline, custom letter spacing, and fixed cell width for bitmap font atlases. Uses a stepped scaling ladder (Tier 1: 4-10 -> 1x/5px, Tier 2: 11-18 -> 2x/10px, Tier 3: 19-26 -> 3x/15px, Tier 4: 27-34 -> 4x/20px) or explicit 'scale' (1..8).",
    {
      text: z.string().describe("Text string to draw (full ASCII 32–126 + newline '\\n')"),
      x: coerceInt().default(0).describe("Starting top-left X position in pixels"),
      y: coerceInt().default(0).describe("Starting top-left Y position in pixels"),
      color: z.string().default("#ffffff").describe("Font hex color (e.g. '#ffffff' or '#e3d0a6')"),
      font_size: coerceInt(4, 64)
        .default(8)
        .describe("Font size ladder (pixels): 4-10 (1x / 5px glyphs), 11-18 (2x / 10px glyphs), 19-26 (3x / 15px glyphs), 27-34 (4x / 20px glyphs), >34 (round(fs/7)). For direct control, pass 'scale' (1..8)"),
      scale: coerceInt(1, 8)
        .optional()
        .describe("Explicit integer pixel scaling factor (1 to 8: 1=5px glyphs, 2=10px glyphs, 3=15px glyphs, etc.). Takes precedence over font_size"),
      shadow_color: z
        .string()
        .optional()
        .describe("Optional drop-shadow hex color drawn behind text (e.g. '#1a1020' or '#000000aa')"),
      shadow_offset_x: coerceInt(-16, 16)
        .optional()
        .describe("Horizontal shadow offset in pixels (defaults to effective scale)"),
      shadow_offset_y: coerceInt(-16, 16)
        .optional()
        .describe("Vertical shadow offset in pixels (defaults to effective scale)"),
      outline_color: z
        .string()
        .optional()
        .describe("Optional 1-texel outline hex color drawn around text glyphs (e.g. '#000000')"),
      outline_mode: z
        .enum(["full", "cardinal"])
        .default("full")
        .describe("Outline connectivity when outline_color is set: 'full' (8-way including corners) or 'cardinal' (4-way N/S/E/W)"),
      letter_spacing: coerceInt(0, 16)
        .default(1)
        .describe("Horizontal spacing between glyphs in unscaled font texels (default: 1)"),
      cell_width: coerceInt(1, 32)
        .optional()
        .describe("Optional fixed advance width per character in unscaled font texels (useful for fixed-grid bitmap font atlases)"),
      layer: layerHandleSchema,
      frame: coerceInt().optional().describe("Optional target frame index (defaults to active frame)"),
    },
    async ({
      text,
      x,
      y,
      color,
      font_size,
      scale,
      shadow_color,
      shadow_offset_x,
      shadow_offset_y,
      outline_color,
      outline_mode,
      letter_spacing,
      cell_width,
      layer,
      frame,
    }) => {
      const payload: Record<string, unknown> = {
        text,
        x,
        y,
        color,
        font_size,
        outline_mode,
        letter_spacing,
      };
      if (scale !== undefined) payload.scale = scale;
      if (shadow_color !== undefined) payload.shadow_color = shadow_color;
      if (shadow_offset_x !== undefined) payload.shadow_offset_x = shadow_offset_x;
      if (shadow_offset_y !== undefined) payload.shadow_offset_y = shadow_offset_y;
      if (outline_color !== undefined) payload.outline_color = outline_color;
      if (cell_width !== undefined) payload.cell_width = cell_width;
      if (layer !== undefined) payload.layer = layer;
      if (frame !== undefined) payload.frame = frame;
      const result = await sendCommand("draw_text", payload);
      const d = result.data;
      const bbox = d?.bounding_box;
      const metricsStr = d?.scale !== undefined
        ? ` (scale: ${d.scale}x, glyph_height: ${d.glyph_height ?? d.scale * 5}px, char_advance: ${d.char_advance ?? d.scale * 5}px)`
        : "";
      const fxTags: string[] = [];
      if (d?.has_outline) fxTags.push(`outline:${outline_color}`);
      if (d?.has_shadow) fxTags.push(`shadow:${shadow_color}`);
      const fxStr = fxTags.length > 0 ? ` [${fxTags.join(", ")}]` : "";
      const bboxStr = bbox ? ` [BoundingBox: ${bbox.width}×${bbox.height} at (${bbox.left},${bbox.top}) to (${bbox.right},${bbox.bottom}), advance: ${bbox.advance}px]` : "";
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Rendered "${text}" (${d?.chars_drawn} characters)${metricsStr}${fxStr} at (${x}, ${y}) with color ${color} on [frame:${d?.frame}, layer:${d?.layer}]${bboxStr}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── eval_gdscript ──────────────────────────────────────────────────────────
  server.tool(
    "eval_gdscript",
    "Execute custom GDScript code natively inside Pixelorama. The script runs with direct access to 'api' (ApiContext with get_pixel, get_layer_image, get_composite_image, get_layers, get_canvas_size, create_image, set_pixel_safe, has_layer, is_valid_image), 'image' (target Cel Image), 'project', and 'params'. HIGH PERFORMANCE BULK WRITES: To avoid slow per-pixel loops, 'run()' can return a PackedByteArray (raw RGBA8/RGB8 bytes) or Image (Image.create(w, h, false, Image.FORMAT_RGBA8) or api.create_image(w, h)) for instant blit commit in < 0.1ms; canvas automatically adapts if dimensions differ. Custom values: 'run()' can also return arbitrary JSON-serializable values (String, Array, Dictionary, int, float, bool) which are returned in 'Value:'. Out-of-bounds 'set_pixel', 'get_pixel', and null 'get_width()'/'get_height()' calls are transparently bounds-checked to guarantee zero crash. 'api.get_layer_image(name)' safely returns an empty transparent canvas-sized Image if the layer does not exist, preventing null pointer segfaults.",
    {
      code: z
        .string()
        .describe("GDScript code. Can define 'func run(api, image: Image, project, params: Dictionary):' (can return Image, PackedByteArray, or custom value) or provide bare script statements that mutate 'image'."),
      layer: layerHandleSchema,
      frame: coerceInt(0).optional().describe("Optional target frame index (defaults to active frame)"),
      params: z
        .record(z.any())
        .optional()
        .describe("Optional key-value parameters dictionary passed into script (e.g. { width: 320, height: 180 })"),
      record_undo: coerceBool()
        .optional()
        .describe("If true (default), records this change in Pixelorama's Undo/Redo history. Set to false during heavy multi-layer bulk procedural generation passes to drastically conserve editor memory."),
    },
    async ({ code, layer, frame, params, record_undo }) => {
      const result = await sendCommand("eval_gdscript", { code, layer, frame, params: params ?? {}, record_undo: record_undo ?? true }, 120_000);
      const resVal = result.data?.result;
      const val = result.data?.value;
      const resStr = resVal !== undefined ? JSON.stringify(resVal) : "completed";
      const valStr = val !== null && val !== undefined ? `\nValue: ${typeof val === "object" ? JSON.stringify(val, null, 2) : String(val)}` : "";
      const warnStr = result.data?.warning ? `\n${result.data.warning}` : "";
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `⚡ GDScript executed successfully on [frame:${result.data?.frame}, layer:${result.data?.layer}]: ${resStr}${valStr}${warnStr}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
