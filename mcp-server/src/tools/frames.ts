/**
 * Frame / Animation Tools
 *
 * Full animation support: add, delete, duplicate, navigate, set duration/fps,
 * operate on individual cels, and export frames or spritesheet.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat } from "../utils/schema_helpers.js";

export function registerFrameTools(server: McpServer): void {
  // ── FRAME QUERIES ──────────────────────────────────────────────────────

  server.tool(
    "get_frames",
    "List all animation frames with their index, duration multiplier, and cel count.",
    {},
    async () => {
      const result = await sendCommand("get_frames", {});
      if (result.success && result.data) {
        const frames = result.data.frames as Array<{
          index: number;
          duration: number;
          cels: number;
        }>;
        const list = frames
          .map((f) => `  [${f.index}] duration:${f.duration}x  cels:${f.cels}`)
          .join("\n");
        return {
          content: [
            {
              type: "text" as const,
              text: `Frames (current:${result.data.current_frame}, total:${result.data.total_frames}):\n${list}`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "get_fps",
    "Get the animation playback speed in frames per second.",
    {},
    async () => {
      const result = await sendCommand("get_fps", {});
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `FPS: ${result.data?.fps}` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── FRAME MUTATIONS ────────────────────────────────────────────────────

  server.tool(
    "set_fps",
    "Set the animation playback speed in frames per second.",
    {
      fps: coerceFloat(0.1).describe("Frames per second (e.g. 12, 24)"),
    },
    async ({ fps }) => {
      const result = await sendCommand("set_fps", { fps });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ FPS set to ${fps}` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "add_frame",
    "Add a new blank animation frame after the specified frame index.",
    {
      after_frame: coerceInt(0)
        .optional()
        .describe("Insert after this frame index (defaults to current frame)"),
    },
    async ({ after_frame }) => {
      const params: Record<string, unknown> = {};
      if (after_frame !== undefined) params.after_frame = after_frame;
      const result = await sendCommand("add_frame", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Frame added (total: ${result.data?.total_frames})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "delete_frame",
    "Delete an animation frame by index. Cannot delete the last remaining frame.",
    {
      index: coerceInt(0)
        .optional()
        .describe("Frame index to delete (defaults to current frame)"),
    },
    async ({ index }) => {
      const params: Record<string, unknown> = {};
      if (index !== undefined) params.index = index;
      const result = await sendCommand("delete_frame", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Frame ${index ?? "current"} deleted (total: ${result.data?.total_frames})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "duplicate_frame",
    "Duplicate an animation frame, inserting the copy immediately after the original. All layer pixel data is deep-copied.",
    {
      index: coerceInt(0)
        .optional()
        .describe("Frame index to duplicate (defaults to current frame)"),
    },
    async ({ index }) => {
      const params: Record<string, unknown> = {};
      if (index !== undefined) params.index = index;
      const result = await sendCommand("duplicate_frame", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Frame duplicated at index ${result.data?.inserted_at} (total: ${result.data?.total_frames})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "set_frame_duration",
    "Set the duration multiplier of a frame (relative to 1/fps). E.g. 2 means the frame lasts twice as long.",
    {
      index: coerceInt(0)
        .optional()
        .describe("Frame index (defaults to current frame)"),
      duration: coerceFloat(0.01)
        .describe("Duration multiplier (1.0 = normal speed, 2.0 = half speed)"),
    },
    async ({ index, duration }) => {
      const params: Record<string, unknown> = { duration };
      if (index !== undefined) params.index = index;
      const result = await sendCommand("set_frame_duration", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Frame ${index ?? "current"} duration set to ${duration}x`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "switch_frame",
    "Switch the active animation frame (makes it current for drawing).",
    {
      index: coerceInt(0).describe("Frame index to switch to"),
    },
    async ({ index }) => {
      const result = await sendCommand("switch_frame", { index });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Switched to frame ${result.data?.current_frame}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── CEL OPERATIONS ─────────────────────────────────────────────────────

  server.tool(
    "switch_cel",
    "Switch the active cel (frame + layer combination). This controls which cel subsequent drawing commands target.",
    {
      frame: coerceInt(0).describe("Frame index"),
      layer: coerceInt(0).describe("Layer index"),
    },
    async ({ frame, layer }) => {
      const result = await sendCommand("switch_cel", { frame, layer });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Active cel → frame:${result.data?.frame} layer:${result.data?.layer}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "copy_cel",
    "Copy pixel data from one cel to another. Useful for animation — copy frame 0 to frame 1 then make small changes.",
    {
      src_frame: coerceInt(0).describe("Source frame index"),
      src_layer: coerceInt(0).describe("Source layer index"),
      dst_frame: coerceInt(0).describe("Destination frame index"),
      dst_layer: coerceInt(0).describe("Destination layer index"),
    },
    async ({ src_frame, src_layer, dst_frame, dst_layer }) => {
      const result = await sendCommand("copy_cel", {
        src_frame,
        src_layer,
        dst_frame,
        dst_layer,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Cel [frame:${src_frame} layer:${src_layer}] → [frame:${dst_frame} layer:${dst_layer}]`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "clear_cel",
    "Clear all pixels in a cel, making it fully transparent.",
    {
      frame: coerceInt(0)
        .optional()
        .describe("Frame index (defaults to current frame)"),
      layer: coerceInt(0)
        .optional()
        .describe("Layer index (defaults to current layer)"),
    },
    async ({ frame, layer }) => {
      const params: Record<string, unknown> = {};
      if (frame !== undefined) params.frame = frame;
      if (layer !== undefined) params.layer = layer;
      const result = await sendCommand("clear_cel", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Cel cleared (frame:${result.data?.frame} layer:${result.data?.layer})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── EXPORT ─────────────────────────────────────────────────────────────

  server.tool(
    "export_animation",
    "Export the animation. Mode 'frames' saves individual PNGs (frame_0000.png, frame_0001.png, …). Mode 'spritesheet' packs all frames into one image grid.",
    {
      path: z.string().describe("Absolute directory path to export into"),
      prefix: z
        .string()
        .default("frame")
        .describe("Filename prefix (e.g. 'walk' → walk_0000.png)"),
      mode: z
        .enum(["frames", "spritesheet"])
        .default("frames")
        .describe("Export mode: 'frames' or 'spritesheet'"),
      columns: coerceInt(1)
        .optional()
        .describe("Spritesheet columns (only for 'spritesheet' mode, defaults to frame count)"),
      start_frame: coerceInt(0)
        .optional()
        .describe("First frame to export (only for 'frames' mode, defaults to 0)"),
      end_frame: coerceInt(0)
        .optional()
        .describe("Last frame to export (only for 'frames' mode, defaults to last frame)"),
    },
    async ({ path, prefix, mode, columns, start_frame, end_frame }) => {
      const params: Record<string, unknown> = { path, prefix, mode };
      if (columns !== undefined) params.columns = columns;
      if (start_frame !== undefined) params.start_frame = start_frame;
      if (end_frame !== undefined) params.end_frame = end_frame;

      const result = await sendCommand("export_animation", params);
      if (result.success && result.data) {
        const d = result.data;
        if (d.mode === "spritesheet") {
          return {
            content: [
              {
                type: "text" as const,
                text: `✅ Spritesheet exported: ${d.path}\n  ${d.frames} frames, ${d.columns}×${d.rows} grid`,
              },
            ],
          };
        }
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Frames exported: ${d.count} files\n  ${(d.files as string[]).join("\n  ")}`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "reverse_frames",
    "Reverse the sequence of animation frames in the timeline (or a sub-range). Ideal for creating ping-pong / breathing / bobbing loops.",
    {
      from_frame: coerceInt(0).optional().describe("Starting frame index to reverse (defaults to 0)"),
      to_frame: coerceInt(0).optional().describe("Ending frame index to reverse (defaults to last frame)"),
    },
    async ({ from_frame, to_frame }) => {
      const params: Record<string, unknown> = {};
      if (from_frame !== undefined) params.from_frame = from_frame;
      if (to_frame !== undefined) params.to_frame = to_frame;
      const result = await sendCommand("reverse_frames", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Frames reversed from [${result.data?.reversed_from}] to [${result.data?.reversed_to}] (Total frames: ${result.data?.total_frames})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "tween_cel",
    "Interpolate position (dx, dy) across intermediate animation frames between src_frame and dst_frame to create smooth in-betweens.",
    {
      src_frame: coerceInt(0).describe("Starting frame index"),
      dst_frame: coerceInt(0).describe("Ending frame index"),
      layer: coerceInt(0).optional().describe("Layer index to tween (defaults to active layer)"),
      dx: coerceInt().default(0).describe("Total horizontal offset to interpolate across frames"),
      dy: coerceInt().default(0).describe("Total vertical offset to interpolate across frames"),
    },
    async ({ src_frame, dst_frame, layer, dx, dy }) => {
      const params: Record<string, unknown> = { src_frame, dst_frame, dx, dy };
      if (layer !== undefined) params.layer = layer;
      const result = await sendCommand("tween_cel", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Tweened ${result.data?.tweened_frames} frames on layer ${result.data?.layer} (dx: ${dx}, dy: ${dy})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "add_animation_tag",
    "Define a named animation tag range (e.g. 'idle', 'walk', 'attack') with timeline color bands in Pixelorama.",
    {
      name: z.string().describe("Animation tag name (e.g. 'walk', 'attack')"),
      from_frame: coerceInt(0).describe("Starting frame index (0-based)"),
      to_frame: coerceInt(0).describe("Ending frame index (0-based)"),
      color: z.string().default("#ff5500").describe("Hex color for timeline tag marker"),
    },
    async ({ name, from_frame, to_frame, color }) => {
      const result = await sendCommand("add_animation_tag", {
        name,
        from_frame,
        to_frame,
        color,
      });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Animation Tag '${name}' added (Frames ${from_frame}..${to_frame}, Total tags: ${result.data?.total_tags})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "get_animation_tags",
    "List all defined animation tracks/tags with their frame ranges and marker colors.",
    {},
    async () => {
      const result = await sendCommand("get_animation_tags", {});
      if (result.success && result.data) {
        const tags = (result.data.tags as Array<{
          index: number;
          name: string;
          from_frame: number;
          to_frame: number;
          color: string;
          frames_count: number;
        }>)
          .map(
            (t) =>
              `  [${t.index}] "${t.name}" -> Frames ${t.from_frame}..${t.to_frame} (${t.frames_count} frames, Color: ${t.color})`
          )
          .join("\n");
        return {
          content: [
            {
              type: "text" as const,
              text: `Animation Tags (${result.data.total} total):\n${tags || "  (None)"}`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "delete_animation_tag",
    "Remove an animation tag by its name or index.",
    {
      name: z.string().optional().describe("Tag name to delete"),
      index: coerceInt(0).optional().describe("Tag index to delete"),
    },
    async ({ name, index }) => {
      const params: Record<string, unknown> = {};
      if (name !== undefined) params.name = name;
      if (index !== undefined) params.index = index;
      const result = await sendCommand("delete_animation_tag", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Deleted animation tag '${result.data?.deleted}'. Remaining tags: ${result.data?.remaining_tags}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "export_gif",
    "Render the current project's animation directly to an animated .gif file on disk.",
    {
      path: z.string().describe("Absolute file path to save the .gif file (e.g. '/path/to/animation.gif')"),
    },
    async ({ path }) => {
      const result = await sendCommand("export_gif", { path });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Animated GIF exported to: ${result.data?.path} (${result.data?.frames} frames, ${result.data?.size_bytes ?? ""} bytes)`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "export_apng",
    "Render the current project's animation directly to an animated .apng file on disk.",
    {
      path: z.string().describe("Absolute file path to save the .apng file (e.g. '/path/to/animation.apng')"),
    },
    async ({ path }) => {
      const result = await sendCommand("export_apng", { path });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Animated APNG exported to: ${result.data?.path} (${result.data?.frames} frames)`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "export_aseprite_json",
    "Export a spritesheet PNG along with standardized Aseprite-compatible .json metadata manifest (supported by Unity, Godot, Phaser, Bevy, GameMaker).",
    {
      target_dir: z.string().describe("Directory where the spritesheet PNG and JSON manifest will be saved"),
      base_name: z.string().optional().describe("Base filename prefix (defaults to project name)"),
    },
    async ({ target_dir, base_name }) => {
      const params: Record<string, unknown> = { target_dir };
      if (base_name !== undefined) params.base_name = base_name;
      const result = await sendCommand("export_aseprite_json", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Aseprite JSON & Spritesheet exported successfully:\n  PNG: ${result.data?.png_path}\n  JSON: ${result.data?.json_path}\n  Frames: ${result.data?.frames_count}, Tags: ${result.data?.tags_count}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
