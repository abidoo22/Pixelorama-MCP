import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import * as fs from "fs";
import * as zlib from "zlib";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat, coerceBool, safeJsonArray } from "../utils/schema_helpers.js";

// Helper: Paeth Predictor for raw PNG scanline filtering
function paethPredictor(a: number, b: number, c: number): number {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

interface DecodedPNG {
  width: number;
  height: number;
  bpp: number;
  data: Buffer;
}

// Lightweight zero-dependency PNG decoder
function decodePNG(buffer: Buffer): DecodedPNG {
  const signature = buffer.subarray(0, 8).toString("hex");
  if (signature !== "89504e470d0a1a0a") {
    throw new Error("Not a valid PNG file signature.");
  }

  let offset = 8;
  let width = 0;
  let height = 0;
  let colorType = 0;
  let bpp = 4;
  const idatBuffers: Buffer[] = [];

  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString("ascii");
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    offset += length + 12;

    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      colorType = data.readUInt8(9);
      bpp = colorType === 6 ? 4 : colorType === 2 ? 3 : 0;
      if (bpp === 0) {
        throw new Error("Only standard RGB (colorType=2) or RGBA (colorType=6) PNGs are supported.");
      }
    } else if (type === "IDAT") {
      idatBuffers.push(data);
    } else if (type === "IEND") {
      break;
    }
  }

  const compressed = Buffer.concat(idatBuffers);
  const inflated = zlib.inflateSync(compressed);

  const out = Buffer.alloc(width * height * bpp);
  const rowSize = width * bpp;
  let pos = 0;

  for (let y = 0; y < height; y++) {
    const filter = inflated[pos++];
    for (let x = 0; x < rowSize; x++) {
      const raw = inflated[pos++];
      const left = x >= bpp ? out[y * rowSize + x - bpp] : 0;
      const up = y > 0 ? out[(y - 1) * rowSize + x] : 0;
      const upLeft = x >= bpp && y > 0 ? out[(y - 1) * rowSize + x - bpp] : 0;

      let val = raw;
      if (filter === 1) val += left;
      else if (filter === 2) val += up;
      else if (filter === 3) val += Math.floor((left + up) / 2);
      else if (filter === 4) val += paethPredictor(left, up, upLeft);

      out[y * rowSize + x] = val & 0xff;
    }
  }

  return { width, height, bpp, data: out };
}

function rgbToHex(r: number, g: number, b: number): string {
  return "#" + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1);
}

function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const clean = hex.replace("#", "");
  const num = parseInt(clean, 16);
  return {
    r: (num >> 16) & 255,
    g: (num >> 8) & 255,
    b: num & 255,
  };
}

function colorDistance(r1: number, g1: number, b1: number, r2: number, g2: number, b2: number): number {
  return Math.hypot(r1 - r2, g1 - g2, b1 - b2);
}

// Built-in palettes for optional color quantization
const QUANT_PALETTES: Record<string, Array<{ r: number; g: number; b: number; hex: string }>> = {
  pico8: [
    "#000000", "#1d2b53", "#7e2553", "#008751", "#ab5236", "#5f574f", "#c2c3c7", "#fff1e8",
    "#ff004d", "#ffa300", "#ffec27", "#00e436", "#29adff", "#83769c", "#ff77a8", "#ffccaa",
  ].map((h) => ({ ...hexToRgb(h), hex: h })),
  gameboy: [
    "#0f380f", "#306230", "#8bac0f", "#9bbc0f",
  ].map((h) => ({ ...hexToRgb(h), hex: h })),
  nes: [
    "#000000", "#6060ff", "#d82800", "#fc9838", "#f8f8f8", "#503000", "#009038", "#fce038",
  ].map((h) => ({ ...hexToRgb(h), hex: h })),
};

function quantizeToPalette(r: number, g: number, b: number, paletteKey: string): string {
  const palette = QUANT_PALETTES[paletteKey.toLowerCase()];
  if (!palette) return rgbToHex(r, g, b);

  let closestHex = palette[0].hex;
  let minDist = Infinity;
  for (const entry of palette) {
    const dist = colorDistance(r, g, b, entry.r, entry.g, entry.b);
    if (dist < minDist) {
      minDist = dist;
      closestHex = entry.hex;
    }
  }
  return closestHex;
}

export function registerImporterTools(server: McpServer): void {
  server.tool(
    "import_image",
    "Import any PNG image file into Pixelorama as pixel art. Automatically detects and strips the background, handles optional color quantization to a retro palette, downscales cleanly if requested, and streams pixels with transparency into Pixelorama.",
    {
      file_path: z.string().describe("Absolute file path to the PNG image (e.g. '/path/to/character.png')"),
      target_width: coerceInt(8, 1024)
        .optional()
        .describe("Optional target width in pixels to downscale the sprite"),
      target_height: coerceInt(8, 1024)
        .optional()
        .describe("Optional target height in pixels to downscale the sprite"),
      remove_background: coerceBool()
        .default(true)
        .describe("If true, auto-detects and strips the background color"),
      tolerance: coerceFloat(0, 100)
        .default(20)
        .describe("Color distance tolerance for background removal (higher = cleans more edge halo)"),
      banned_colors: safeJsonArray(z.string())
        .optional()
        .describe("Optional list of additional hex colors to treat as background and strip"),
      palette: z
        .string()
        .optional()
        .describe("Optional retro palette to quantize colors to ('pico8', 'gameboy', 'nes', or leave empty for original colors)"),
      create_new_canvas: coerceBool()
        .default(true)
        .describe("If true, creates a new canvas with the image dimensions. If false, draws onto current canvas."),
      canvas_name: z
        .string()
        .default("Imported Sprite")
        .describe("Canvas name if creating a new canvas"),
    },
    async ({
      file_path,
      target_width,
      target_height,
      remove_background,
      tolerance,
      banned_colors,
      palette,
      create_new_canvas,
      canvas_name,
    }) => {
      if (!fs.existsSync(file_path)) {
        return {
          content: [{ type: "text" as const, text: `❌ File not found at path: ${file_path}` }],
        };
      }

      let img: DecodedPNG;
      try {
        const fileBuffer = fs.readFileSync(file_path);
        img = decodePNG(fileBuffer);
      } catch (err) {
        return {
          content: [
            {
              type: "text" as const,
              text: `❌ Failed to decode PNG: ${err instanceof Error ? err.message : String(err)}`,
            },
          ],
        };
      }

      const origW = img.width;
      const origH = img.height;
      const bpp = img.bpp;
      const rawData = img.data;

      const outW = target_width ?? origW;
      const outH = target_height ?? origH;

      // Sample background colors from corners
      const bg1 = { r: rawData[0], g: rawData[1], b: rawData[2] };
      const bannedRgbList = (banned_colors ?? []).map(hexToRgb);

      if (create_new_canvas) {
        await sendCommand("create_canvas", { width: outW, height: outH, name: canvas_name });
      }

      const pixels: Array<{ x: number; y: number; color: string }> = [];

      for (let y = 0; y < outH; y++) {
        for (let x = 0; x < outW; x++) {
          // Nearest-neighbor sampling from original coordinates
          const srcX = Math.min(Math.floor((x / outW) * origW), origW - 1);
          const srcY = Math.min(Math.floor((y / outH) * origH), origH - 1);
          const i = (srcY * origW + srcX) * bpp;

          const r = rawData[i];
          const g = rawData[i + 1];
          const b = rawData[i + 2];
          const a = bpp === 4 ? rawData[i + 3] : 255;

          if (a <= 10) continue; // transparent in source

          if (remove_background) {
            const distToBg = colorDistance(r, g, b, bg1.r, bg1.g, bg1.b);
            if (distToBg <= tolerance) continue;

            let matchesBanned = false;
            for (const banned of bannedRgbList) {
              if (colorDistance(r, g, b, banned.r, banned.g, banned.b) <= tolerance) {
                matchesBanned = true;
                break;
              }
            }
            if (matchesBanned) continue;
          }

          const hex = palette ? quantizeToPalette(r, g, b, palette) : rgbToHex(r, g, b);
          pixels.push({ x, y, color: hex });
        }
      }

      // Stream in batches of 2500
      const BATCH_SIZE = 2500;
      let drawn = 0;
      for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
        const batch = pixels.slice(i, i + BATCH_SIZE);
        const res = await sendCommand("draw_pixels", { pixels: batch });
        if (res.success && res.data) {
          drawn += (res.data.drawn as number) ?? batch.length;
        }
      }

      await sendCommand("fit_viewport", {});

      return {
        content: [
          {
            type: "text" as const,
            text: `✅ Image imported successfully: "${file_path}"\n- Dimensions: ${outW}×${outH} pixels (source was ${origW}×${origH})\n- Pixels drawn: ${drawn} / ${pixels.length}\n- Background stripped: ${remove_background ? `Yes (tolerance: ${tolerance})` : "No"}\n- Palette: ${palette ?? "original"}`,
          },
        ],
      };
    }
  );
}
