/**
 * Tilemap & Tileset Creation Tools
 *
 * Tools for structuring, drawing, and exporting 2D tilemaps and tilesets (16x16, 32x32, etc.)
 * for platforms, top-down RPGs, and dungeons.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import * as fs from "fs";
import * as path from "path";
import { sendCommand } from "../bridge/pixelorama_client.js";

export function registerTilemapTools(server: McpServer): void {
  server.tool(
    "create_tileset_canvas",
    "Create a new canvas partitioned into a grid for drawing tilesets (e.g. 4x4 grid of 16x16 tiles = 64x64 canvas).",
    {
      tile_size: z
        .number()
        .int()
        .min(8)
        .max(128)
        .default(16)
        .describe("Size of individual tiles in pixels (e.g. 16 or 32)"),
      columns: z
        .number()
        .int()
        .min(1)
        .max(64)
        .default(4)
        .describe("Number of tile columns in the tileset grid"),
      rows: z
        .number()
        .int()
        .min(1)
        .max(64)
        .default(4)
        .describe("Number of tile rows in the tileset grid"),
      name: z
        .string()
        .default("Tileset")
        .describe("Name for the tileset project"),
    },
    async ({ tile_size, columns, rows, name }) => {
      const width = tile_size * columns;
      const height = tile_size * rows;

      const result = await sendCommand("create_canvas", {
        width,
        height,
        name,
        fill_color: "",
      });

      if (!result.success) {
        return { content: [{ type: "text" as const, text: `❌ Failed to create tileset canvas: ${result.error}` }] };
      }

      await sendCommand("fit_viewport", {});

      const tileList: string[] = [];
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < columns; c++) {
          const index = r * columns + c;
          const x = c * tile_size;
          const y = r * tile_size;
          tileList.push(`  - Tile [${index}] (col:${c}, row:${r}) -> Rect: (${x}, ${y}) to (${x + tile_size - 1}, ${y + tile_size - 1})`);
        }
      }

      const text = `✅ Tileset canvas created: "${name}" (${width}×${height} pixels)\n` +
        `- Tile size: ${tile_size}×${tile_size} px\n` +
        `- Grid: ${columns} columns × ${rows} rows (${columns * rows} total tiles)\n` +
        `Tile Map Locations:\n${tileList.slice(0, 16).join("\n")}${tileList.length > 16 ? "\n  ... and more" : ""}\n\n` +
        `Ready to draw! Use \`draw_pixels\` or shapes to fill each tile region.`;

      return { content: [{ type: "text" as const, text }] };
    }
  );

  server.tool(
    "export_tileset",
    "Export the active canvas as a tileset PNG image and optionally generate a JSON metadata file defining tile coordinates, tile IDs, and collision flags.",
    {
      export_path: z.string().describe("Absolute file path for the tileset PNG (e.g. '/path/to/dungeon_tiles.png')"),
      tile_size: z.number().int().min(8).max(128).default(16).describe("Tile size in pixels"),
      generate_metadata: z.boolean().default(true).describe("If true, generates a .json metadata file alongside the PNG"),
    },
    async ({ export_path, tile_size, generate_metadata }) => {
      const infoRes = await sendCommand("get_canvas_info", {});
      if (!infoRes.success || !infoRes.data) {
        return { content: [{ type: "text" as const, text: `❌ No active canvas: ${infoRes.error}` }] };
      }

      const d = infoRes.data;
      const width = d.width as number;
      const height = d.height as number;
      const cols = Math.floor(width / tile_size);
      const rows = Math.floor(height / tile_size);
      const totalTiles = cols * rows;

      // Ensure directory exists
      const targetDir = path.dirname(export_path);
      if (!fs.existsSync(targetDir)) {
        fs.mkdirSync(targetDir, { recursive: true });
      }

      const exportRes = await sendCommand("export_image", { path: export_path, frame: 0 });
      if (!exportRes.success) {
        return { content: [{ type: "text" as const, text: `❌ Failed to export tileset image: ${exportRes.error}` }] };
      }

      let metadataFile = "";
      if (generate_metadata) {
        const metadata = {
          tileset_name: d.name,
          image: path.basename(export_path),
          image_width: width,
          image_height: height,
          tile_size: tile_size,
          columns: cols,
          rows: rows,
          total_tiles: totalTiles,
          tiles: [] as Array<{ id: number; x: number; y: number; col: number; row: number }>,
        };

        for (let r = 0; r < rows; r++) {
          for (let c = 0; c < cols; c++) {
            metadata.tiles.push({
              id: r * cols + c,
              x: c * tile_size,
              y: r * tile_size,
              col: c,
              row: r,
            });
          }
        }

        const jsonPath = export_path.replace(/\.[^/.]+$/, ".json");
        fs.writeFileSync(jsonPath, JSON.stringify(metadata, null, 2), "utf-8");
        metadataFile = jsonPath;
      }

      const text = `✅ Tileset exported successfully!\n` +
        `- Image: ${export_path} (${width}×${height} px)\n` +
        `- Tiles: ${totalTiles} tiles (${cols}×${rows} grid of ${tile_size}×${tile_size} px)` +
        (metadataFile ? `\n- Metadata: ${metadataFile}` : "");

      return { content: [{ type: "text" as const, text }] };
    }
  );
}
