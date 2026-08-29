/**
 * Direct Godot 4 Resource Exporters
 *
 * Automatically exports pixel art assets and generates native Godot 4 resources:
 * - SpriteFrames (.tres) for AnimatedSprite2D
 * - TileSet (.tres) with TileSetAtlasSource for TileMapLayer
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import * as fs from "fs";
import * as path from "path";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat, coerceBool } from "../utils/schema_helpers.js";

export function registerGodotExportTools(server: McpServer): void {
  // ── export_godot_spriteframes ───────────────────────────────────────────
  server.tool(
    "export_godot_spriteframes",
    "Export animation frames to a Godot game project folder and automatically generate a native Godot 4 SpriteFrames (.tres) resource ready to drop into an AnimatedSprite2D node.",
    {
      target_dir: z.string().describe("Target folder in the Godot project (e.g. '/home/user/my_game/assets/characters/')"),
      sprite_name: z.string().describe("Base name for the sprite (e.g. 'knight' or 'slime')"),
      animation_name: z.string().default("default").describe("Name of the animation track in Godot (e.g. 'idle', 'walk', 'attack')"),
      fps: coerceFloat(0.1).default(8).describe("Animation playback speed in frames per second"),
      loop: coerceBool().default(true).describe("Whether the animation loops"),
    },
    async ({ target_dir, sprite_name, animation_name, fps, loop }) => {
      // Ensure target directory exists
      if (!fs.existsSync(target_dir)) {
        fs.mkdirSync(target_dir, { recursive: true });
      }

      // Query frames
      const framesRes = await sendCommand("get_frames", {});
      if (!framesRes.success || !framesRes.data) {
        return { content: [{ type: "text" as const, text: `❌ Failed to query animation frames: ${framesRes.error}` }] };
      }

      const totalFrames = (framesRes.data.total_frames as number) || 1;

      // Export individual frame PNGs
      const exportRes = await sendCommand("export_animation", {
        path: target_dir,
        prefix: `${sprite_name}_${animation_name}`,
        mode: "frames",
        start_frame: 0,
        end_frame: totalFrames - 1,
      });

      if (!exportRes.success || !exportRes.data) {
        return { content: [{ type: "text" as const, text: `❌ Failed to export frame PNGs: ${exportRes.error}` }] };
      }

      const filePaths = exportRes.data.files as string[];
      const fileNames = filePaths.map((fp) => path.basename(fp));

      // Build Godot 4 .tres SpriteFrames content
      let extResources = "";
      let frameEntries = "";

      fileNames.forEach((name, i) => {
        const id = `${i + 1}_tex`;
        extResources += `[ext_resource type="Texture2D" path="${name}" id="${id}"]\n`;
        frameEntries += `{\n"duration": 1.0,\n"texture": ExtResource("${id}")\n}${i < fileNames.length - 1 ? "," : ""}\n`;
      });

      const tresContent = `[gd_resource type="SpriteFrames" load_steps=${fileNames.length + 1} format=3]

${extResources}
[resource]
animations = [{
"frames": [
${frameEntries}],
"loop": ${loop},
"name": &"${animation_name}",
"speed": ${fps.toFixed(1)}
}]
`;

      const tresPath = path.join(target_dir, `${sprite_name}_${animation_name}_frames.tres`);
      fs.writeFileSync(tresPath, tresContent, "utf-8");

      const text = `✅ Godot 4 SpriteFrames exported successfully!\n` +
        `- Destination folder: ${target_dir}\n` +
        `- Frames exported: ${fileNames.length} PNGs\n` +
        `- Godot Resource: ${tresPath}\n` +
        `- Animation: "${animation_name}" (${fps} FPS, ${loop ? "looping" : "one-shot"})\n\n` +
        `🎮 In Godot: Drag \`${path.basename(tresPath)}\` onto the 'Sprite Frames' property of an AnimatedSprite2D node!`;

      return { content: [{ type: "text" as const, text }] };
    }
  );

  // ── export_godot_tileset ────────────────────────────────────────────────
  server.tool(
    "export_godot_tileset",
    "Export a tileset PNG to a Godot game project folder and automatically generate a native Godot 4 TileSet (.tres) resource configured with a TileSetAtlasSource ready to use with TileMap / TileMapLayer.",
    {
      target_dir: z.string().describe("Target folder in the Godot project (e.g. '/home/user/my_game/assets/tilesets/')"),
      tileset_name: z.string().describe("Base name for the tileset (e.g. 'dungeon_tiles' or 'overworld')"),
      tile_size: coerceInt(8, 128).default(16).describe("Tile width and height in pixels"),
    },
    async ({ target_dir, tileset_name, tile_size }) => {
      // Ensure target directory exists
      if (!fs.existsSync(target_dir)) {
        fs.mkdirSync(target_dir, { recursive: true });
      }

      const infoRes = await sendCommand("get_canvas_info", {});
      if (!infoRes.success || !infoRes.data) {
        return { content: [{ type: "text" as const, text: `❌ No active canvas: ${infoRes.error}` }] };
      }

      const d = infoRes.data;
      const width = d.width as number;
      const height = d.height as number;
      const cols = Math.floor(width / tile_size);
      const rows = Math.floor(height / tile_size);

      const pngFileName = `${tileset_name}.png`;
      const pngPath = path.join(target_dir, pngFileName);

      const exportRes = await sendCommand("export_image", { path: pngPath, frame: 0 });
      if (!exportRes.success) {
        return { content: [{ type: "text" as const, text: `❌ Failed to export tileset PNG: ${exportRes.error}` }] };
      }

      // Generate all tile coordinates in the atlas
      let tileEntries = "";
      for (let y = 0; y < rows; y++) {
        for (let x = 0; x < cols; x++) {
          tileEntries += `${x}:${y}/0 = 0\n`;
        }
      }

      // Build Godot 4 .tres TileSet content
      const tresContent = `[gd_resource type="TileSet" load_steps=3 format=3]

[ext_resource type="Texture2D" path="${pngFileName}" id="1_tex"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_1"]
texture = ExtResource("1_tex")
texture_region_size = Vector2i(${tile_size}, ${tile_size})
${tileEntries}
[resource]
tile_size = Vector2i(${tile_size}, ${tile_size})
sources/0 = SubResource("TileSetAtlasSource_1")
`;

      const tresPath = path.join(target_dir, `${tileset_name}.tres`);
      fs.writeFileSync(tresPath, tresContent, "utf-8");

      const text = `✅ Godot 4 TileSet exported successfully!\n` +
        `- Destination folder: ${target_dir}\n` +
        `- Texture: ${pngPath} (${width}×${height} px)\n` +
        `- Godot Resource: ${tresPath}\n` +
        `- Tile size: ${tile_size}×${tile_size} px (${cols * rows} tiles configured)\n\n` +
        `🎮 In Godot: Select your TileMap or TileMapLayer node and assign \`${path.basename(tresPath)}\` to the 'Tile Set' property!`;

      return { content: [{ type: "text" as const, text }] };
    }
  );
}
