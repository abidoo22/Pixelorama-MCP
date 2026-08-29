/**
 * AI Helper Tools — Milestone 4
 *
 * High-level tools that help an AI understand the canvas state,
 * pick palettes intelligently, and plan sprite generation.
 * These are pure TypeScript — they call existing bridge tools
 * internally and return rich structured text for the AI to act on.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceBool } from "../utils/schema_helpers.js";

// ── Built-in pixel-art palettes ────────────────────────────────────────────
const BUILTIN_PALETTES: Record<string, { name: string; description: string; colors: Array<{ role: string; hex: string }> }> = {
  nes: {
    name: "NES",
    description: "Classic Nintendo Entertainment System 54-color palette, limited subset",
    colors: [
      { role: "background",  hex: "#000000" },
      { role: "sky",         hex: "#6060ff" },
      { role: "primary",     hex: "#d82800" },
      { role: "secondary",   hex: "#fc9838" },
      { role: "highlight",   hex: "#f8f8f8" },
      { role: "shadow",      hex: "#503000" },
      { role: "ground",      hex: "#009038" },
      { role: "accent",      hex: "#fce038" },
    ],
  },
  gameboy: {
    name: "Game Boy",
    description: "Original 4-color greenish monochrome",
    colors: [
      { role: "darkest",   hex: "#0f380f" },
      { role: "dark",      hex: "#306230" },
      { role: "light",     hex: "#8bac0f" },
      { role: "lightest",  hex: "#9bbc0f" },
    ],
  },
  pico8: {
    name: "PICO-8",
    description: "16-color fantasy console palette used in indie pixel art",
    colors: [
      { role: "black",      hex: "#000000" },
      { role: "dark-blue",  hex: "#1d2b53" },
      { role: "dark-purple",hex: "#7e2553" },
      { role: "dark-green", hex: "#008751" },
      { role: "brown",      hex: "#ab5236" },
      { role: "dark-grey",  hex: "#5f574f" },
      { role: "light-grey", hex: "#c2c3c7" },
      { role: "white",      hex: "#fff1e8" },
      { role: "red",        hex: "#ff004d" },
      { role: "orange",     hex: "#ffa300" },
      { role: "yellow",     hex: "#ffec27" },
      { role: "green",      hex: "#00e436" },
      { role: "blue",       hex: "#29adff" },
      { role: "lavender",   hex: "#83769c" },
      { role: "pink",       hex: "#ff77a8" },
      { role: "peach",      hex: "#ffccaa" },
    ],
  },
  cga: {
    name: "CGA Mode 4",
    description: "IBM CGA 4-color palette (magenta mode)",
    colors: [
      { role: "black",   hex: "#000000" },
      { role: "cyan",    hex: "#55ffff" },
      { role: "magenta", hex: "#ff55ff" },
      { role: "white",   hex: "#ffffff" },
    ],
  },
  endesga32: {
    name: "ENDESGA 32",
    description: "Popular indie game 32-color palette with warm earthy tones",
    colors: [
      { role: "black",        hex: "#be4a2f" },
      { role: "dark-red",     hex: "#d77643" },
      { role: "skin-dark",    hex: "#ead4aa" },
      { role: "skin-light",   hex: "#e4a672" },
      { role: "brown-dark",   hex: "#b86f50" },
      { role: "brown",        hex: "#733e39" },
      { role: "brown-darker", hex: "#3e2731" },
      { role: "night",        hex: "#1e1d39" },
      { role: "dark-navy",    hex: "#402751" },
      { role: "purple",       hex: "#7a367b" },
      { role: "magenta",      hex: "#a23e8c" },
      { role: "pink",         hex: "#c65197" },
      { role: "hot-pink",     hex: "#df84a5" },
      { role: "cream",        hex: "#b8fdbd" },
      { role: "light-green",  hex: "#5be8c4" },
      { role: "teal",         hex: "#1ebc73" },
      { role: "green",        hex: "#91db69" },
      { role: "olive",        hex: "#fbff86" },
      { role: "yellow",       hex: "#f2d648" },
      { role: "gold",         hex: "#e6a117" },
      { role: "orange",       hex: "#e07000" },
      { role: "red",          hex: "#b84200" },
      { role: "dark-brown",   hex: "#693a00" },
      { role: "tan",          hex: "#cca133" },
      { role: "sand",         hex: "#e8d282" },
      { role: "sky-light",    hex: "#f2f2e3" },
      { role: "sky",          hex: "#9dc0d4" },
      { role: "blue-mid",     hex: "#4d78a4" },
      { role: "blue",         hex: "#245d84" },
      { role: "dark-blue",    hex: "#0e3568" },
      { role: "navy",         hex: "#1e1342" },
      { role: "true-black",   hex: "#000000" },
    ],
  },
  // Mood-based palettes
  forest: {
    name: "Forest",
    description: "Natural forest tones — greens, browns, soft light",
    colors: [
      { role: "deep-shadow",  hex: "#1a2e1a" },
      { role: "dark-bark",    hex: "#3b2507" },
      { role: "bark",         hex: "#6b4423" },
      { role: "moss",         hex: "#4a6741" },
      { role: "leaf-dark",    hex: "#2d7a2d" },
      { role: "leaf",         hex: "#52a852" },
      { role: "leaf-light",   hex: "#7cc97c" },
      { role: "sunlight",     hex: "#d4e88a" },
      { role: "sky",          hex: "#a8d4e6" },
      { role: "flower",       hex: "#e8c86a" },
    ],
  },
  ocean: {
    name: "Ocean",
    description: "Deep blues and teals for underwater or coastal scenes",
    colors: [
      { role: "abyss",      hex: "#020c1b" },
      { role: "deep",       hex: "#0a1f44" },
      { role: "dark-water", hex: "#0d3b6e" },
      { role: "water",      hex: "#1a6b9a" },
      { role: "mid-water",  hex: "#2596c4" },
      { role: "shallow",    hex: "#47b8d4" },
      { role: "foam",       hex: "#8dd8e8" },
      { role: "white-cap",  hex: "#d8f4fc" },
      { role: "sand",       hex: "#e8d5a0" },
      { role: "coral",      hex: "#f08060" },
    ],
  },
  fire: {
    name: "Fire",
    description: "Warm ember and flame palette",
    colors: [
      { role: "ash",        hex: "#1a0a00" },
      { role: "coal",       hex: "#3d1500" },
      { role: "ember-dark", hex: "#7a2900" },
      { role: "ember",      hex: "#b84000" },
      { role: "flame-dark", hex: "#e05800" },
      { role: "flame",      hex: "#f07000" },
      { role: "flame-mid",  hex: "#f8a030" },
      { role: "flame-light",hex: "#ffd060" },
      { role: "core",       hex: "#fff4a0" },
      { role: "smoke",      hex: "#888080" },
    ],
  },
  retro: {
    name: "Retro",
    description: "80s synthwave neons on dark backgrounds",
    colors: [
      { role: "void",       hex: "#0a0015" },
      { role: "dark",       hex: "#150030" },
      { role: "purple",     hex: "#2d0060" },
      { role: "magenta",    hex: "#c000c0" },
      { role: "hot-pink",   hex: "#ff00aa" },
      { role: "cyan",       hex: "#00ffff" },
      { role: "electric",   hex: "#00d4ff" },
      { role: "teal",       hex: "#00a8a0" },
      { role: "yellow",     hex: "#ffee00" },
      { role: "white",      hex: "#ffffff" },
    ],
  },
};

const MOOD_KEYWORDS: Record<string, string[]> = {
  nes:      ["mario", "nintendo", "nes", "retro", "8-bit", "8bit", "classic"],
  gameboy:  ["gameboy", "game boy", "monochrome", "green", "handheld", "portable"],
  pico8:    ["pico", "pico8", "pico-8", "fantasy", "indie", "quirky"],
  cga:      ["cga", "dos", "pc", "ibm", "old school", "oldschool"],
  endesga32:["endesga", "warm", "earthy", "adventurer", "rpg", "dungeon"],
  forest:   ["forest", "nature", "tree", "leaf", "green", "natural", "jungle", "wood"],
  ocean:    ["ocean", "sea", "water", "underwater", "aquatic", "beach", "wave", "fish"],
  fire:     ["fire", "flame", "lava", "hot", "dragon", "volcano", "ember", "burn"],
  retro:    ["synthwave", "neon", "80s", "cyberpunk", "vaporwave", "night", "glow", "laser"],
};

function matchPalette(mood: string): string {
  const lower = mood.toLowerCase();
  for (const [key, keywords] of Object.entries(MOOD_KEYWORDS)) {
    if (keywords.some((kw) => lower.includes(kw))) return key;
  }
  return "pico8"; // safe default
}

// ── Sprite generation plan templates ──────────────────────────────────────
function buildSpritePlan(
  description: string,
  width: number,
  height: number,
  paletteKey: string
): string {
  const palette = BUILTIN_PALETTES[paletteKey] ?? BUILTIN_PALETTES["pico8"];
  const cx = Math.floor(width / 2);
  const cy = Math.floor(height / 2);

  return `# Sprite Generation Plan: "${description}"
Canvas: ${width}×${height} pixels
Palette: ${palette.name} — ${palette.description}

## Step-by-step instructions:

### 1. Setup
- Call \`create_canvas\` with width=${width}, height=${height}
- Call \`create_palette\` with name="${palette.name}"
- Add palette colors using \`add_palette_color\` for each:
${palette.colors.map((c) => `  • ${c.role}: ${c.hex}`).join("\n")}

### 2. Background
- Call \`fill_area\` at (0,0) with the background color (${palette.colors[0].hex})
  OR leave transparent if sprite needs a transparent background.

### 3. Layer strategy for "${description}"
- Layer 0 (bottom): Background / environment details
- Layer 1: Main sprite body — use \`draw_pixels\` for efficiency
- Layer 2: Highlights / shading — set opacity to 0.6-0.8
- Layer 3: Outline — use the darkest color (${palette.colors[0].hex})

### 4. Drawing approach
Center of canvas: (${cx}, ${cy})

For pixel art at ${width}×${height}:
- Use \`draw_pixels\` (batch) for all fill areas — much faster than draw_pixel
- Use \`draw_line\` for clean edges
- Use \`draw_ellipse\` for round shapes (heads, eyes, orbs)
- Use \`draw_rect\` for boxy shapes (torso, platforms)
- Use \`fill_area\` to flood-fill large same-color regions after outlining

### 5. Shading guide
- Outline color: ${palette.colors[0].hex} (darkest)
- Base/primary color: ${palette.colors[2]?.hex ?? palette.colors[1].hex}
- Shadow: ${palette.colors[1]?.hex ?? palette.colors[0].hex}
- Highlight: ${palette.colors[palette.colors.length - 1].hex} (lightest)

### 6. Workflow reminder
- After drawing each layer, call \`get_canvas_snapshot\` to verify the result
- Use \`switch_cel\` to move between layers
- Call \`export_image\` when done to save the result

### 7. Pixel art best practices
- Keep outlines 1px thick
- Use no more than ${Math.min(palette.colors.length, 6)} colors for ${width}≤16px sprites
- Light source typically comes from top-left
- Avoid isolated single pixels ("pixel noise")
- Mirror/symmetry works well for characters — draw half then mirror with draw_pixels`;
}

// ─────────────────────────────────────────────────────────────────────────────
export function registerAiHelperTools(server: McpServer): void {

  // ── describe_canvas ──────────────────────────────────────────────────────
  server.tool(
    "describe_canvas",
    "Get a comprehensive description of the current canvas state — dimensions, layers, frames, FPS, and a pixel-color snapshot. Use this before drawing to understand what's already there.",
    {
      snapshot_width: coerceInt(1, 64).default(32)
        .describe("Width of pixel snapshot to include (keep small, ≤64)"),
      snapshot_height: coerceInt(1, 64).default(32)
        .describe("Height of pixel snapshot to include"),
    },
    async ({ snapshot_width, snapshot_height }) => {
      // Gather all canvas state in parallel
      const [infoRes, layersRes, framesRes, snapshotRes] = await Promise.all([
        sendCommand("get_canvas_info", {}),
        sendCommand("get_layers", {}),
        sendCommand("get_frames", {}),
        sendCommand("get_canvas_snapshot", { x: 0, y: 0, width: snapshot_width, height: snapshot_height }),
      ]);

      const lines: string[] = ["# Canvas Description\n"];

      // Canvas info
      if (infoRes.success && infoRes.data) {
        const d = infoRes.data;
        lines.push(`## Canvas`);
        lines.push(`- Name: ${d.name}`);
        lines.push(`- Size: ${d.width}×${d.height} pixels`);
        lines.push(`- Current frame: ${d.current_frame}, Current layer: ${d.current_layer}`);
        lines.push(`- Layers: ${d.layers}, Frames: ${d.frames}\n`);
      }

      // Layers
      if (layersRes.success && layersRes.data) {
        const layers = layersRes.data.layers as Array<{ index: number; name: string; visible: boolean; locked: boolean; opacity: number; blend_mode: number; type: string }>;
        lines.push(`## Layers (${layers.length} total, current: ${layersRes.data.current_layer})`);
        for (const l of layers) {
          const vis = l.visible ? "👁 visible" : "🚫 hidden";
          const lock = l.locked ? " 🔒" : "";
          lines.push(`- [${l.index}] "${l.name}" | ${l.type} | ${vis}${lock} | opacity: ${Math.round(l.opacity * 100)}% | blend: ${l.blend_mode}`);
        }
        lines.push("");
      }

      // Frames
      if (framesRes.success && framesRes.data) {
        const frames = framesRes.data.frames as Array<{ index: number; duration: number; cels: number }>;
        lines.push(`## Animation (${frames.length} frames, current: ${framesRes.data.current_frame})`);
        for (const f of frames) {
          lines.push(`- [${f.index}] duration: ${f.duration}x, cels: ${f.cels}`);
        }
        lines.push("");
      }

      // Snapshot
      if (snapshotRes.success && snapshotRes.data) {
        const d = snapshotRes.data;
        const colors = d.colors as string[];
        const grid = d.grid as number[][];
        lines.push(`## Pixel Snapshot (top-left ${d.width}×${d.height})`);
        lines.push(`Colors (${colors.length} unique): ${colors.map((c: string, i: number) => `${i}=${c}`).join(", ")}`);

        const isEmpty = colors.length === 1 && (colors[0] === "00000000" || colors[0] === "ffffff00");
        if (isEmpty) {
          lines.push("Canvas appears to be blank/transparent.\n");
        } else {
          lines.push("Grid (index → color above):");
          lines.push("```");
          for (const row of grid) {
            lines.push(row.map((idx: number) => String(idx).padStart(2)).join(" "));
          }
          lines.push("```\n");
        }
      }

      lines.push("## Ready to draw?\nUse `draw_pixels` for batch drawing, `switch_cel` to change active layer/frame, and `get_canvas_snapshot` to check progress.");

      return {
        content: [{ type: "text" as const, text: lines.join("\n") }],
      };
    }
  );

  // ── suggest_palette ──────────────────────────────────────────────────────
  server.tool(
    "suggest_palette",
    "Suggest a pixel-art color palette based on a mood, theme, or style keyword. Returns hex colors with semantic roles (background, primary, shadow, etc.) ready to use with add_palette_color.",
    {
      theme: z.string().describe(
        "Mood or style — e.g. 'forest', 'ocean', 'fire', 'retro', 'NES', 'Game Boy', 'PICO-8', 'cyberpunk', 'RPG dungeon'"
      ),
      list_all: coerceBool().default(false)
        .describe("If true, list all available built-in palettes instead of matching"),
    },
    async ({ theme, list_all }) => {
      if (list_all) {
        const lines = ["# Available Built-in Palettes\n"];
        for (const [key, pal] of Object.entries(BUILTIN_PALETTES)) {
          lines.push(`## ${pal.name} (key: "${key}")`);
          lines.push(`${pal.description}`);
          lines.push(`Colors: ${pal.colors.map((c) => `${c.role}(${c.hex})`).join(", ")}\n`);
        }
        return { content: [{ type: "text" as const, text: lines.join("\n") }] };
      }

      const key = matchPalette(theme);
      const palette = BUILTIN_PALETTES[key];

      const lines = [
        `# Palette Suggestion for "${theme}"`,
        `Matched: **${palette.name}** — ${palette.description}\n`,
        `## Colors (${palette.colors.length} total)`,
      ];
      for (const c of palette.colors) {
        lines.push(`- **${c.role}**: \`${c.hex}\``);
      }
      lines.push(`\n## How to apply`);
      lines.push(`1. Call \`create_palette\` with name="${palette.name}" width=${Math.min(8, palette.colors.length)} height=${Math.ceil(palette.colors.length / 8)}`);
      lines.push(`2. For each color above, call \`add_palette_color\` with the hex value`);
      lines.push(`3. Use \`set_color\` to pick from the palette before drawing`);
      lines.push(`\nOr call \`suggest_palette\` with list_all=true to see all available palettes.`);

      return { content: [{ type: "text" as const, text: lines.join("\n") }] };
    }
  );

  // ── generate_sprite ──────────────────────────────────────────────────────
  server.tool(
    "generate_sprite",
    "Generate a step-by-step drawing plan for a pixel art sprite. Returns instructions the AI should follow using draw_pixels, draw_line, etc. This is a planning tool — you still execute the steps.",
    {
      description: z.string().describe(
        "What to draw — e.g. 'a red mushroom with white spots, Mario style', 'a blue gem', 'a walking human character (4 frames)'"
      ),
      width: coerceInt(8, 128).default(16)
        .describe("Canvas width in pixels"),
      height: coerceInt(8, 128).default(16)
        .describe("Canvas height in pixels"),
      style: z.string().default("pico8")
        .describe("Palette/style — e.g. 'nes', 'gameboy', 'pico8', 'forest', 'retro'"),
      animated: coerceBool().default(false)
        .describe("If true, include multi-frame animation guidance"),
      frames: coerceInt(2, 16).default(4)
        .describe("Number of animation frames (only used if animated=true)"),
    },
    async ({ description, width, height, style, animated, frames }) => {
      const paletteKey = matchPalette(style);
      let plan = buildSpritePlan(description, width, height, paletteKey);

      if (animated) {
        plan += `\n\n## Animation Plan (${frames} frames)\n`;
        plan += `For a ${frames}-frame animation of "${description}":\n\n`;
        plan += `### Frame-by-frame workflow:\n`;
        for (let i = 0; i < frames; i++) {
          plan += `**Frame ${i}:**\n`;
          if (i === 0) {
            plan += `- Draw the base pose using the layer strategy above\n`;
            plan += `- Call \`switch_frame\` with index=0 when done\n`;
          } else {
            plan += `- Call \`duplicate_frame\` to copy frame ${i - 1}\n`;
            plan += `- Call \`switch_frame\` index=${i}\n`;
            plan += `- Modify pixels that change between frames using \`draw_pixels\`\n`;
            plan += `- Call \`clear_cel\` on specific layers then redraw changed parts\n`;
          }
          plan += `\n`;
        }
        plan += `### Timing:\n`;
        plan += `- Call \`set_fps\` with fps=8 for a smooth walk cycle\n`;
        plan += `- Use \`set_frame_duration\` on key frames if you need hold frames\n\n`;
        plan += `### Export:\n`;
        plan += `- Call \`export_animation\` with mode="spritesheet" to get all frames in one image\n`;
        plan += `- Or mode="frames" for individual PNGs\n`;
      }

      plan += `\n\n## Quick-start commands:\n`;
      plan += `\`\`\`\n`;
      plan += `1. create_canvas(width=${width}, height=${height})\n`;
      plan += `2. suggest_palette(theme="${style}") → add_palette_color for each\n`;
      plan += `3. describe_canvas() → verify setup\n`;
      plan += `4. draw_pixels(pixels=[...]) → draw your sprite\n`;
      plan += `5. get_canvas_snapshot() → verify result\n`;
      plan += `6. export_image(path="/path/to/output.png")\n`;
      plan += `\`\`\``;

      return { content: [{ type: "text" as const, text: plan }] };
    }
  );
}
