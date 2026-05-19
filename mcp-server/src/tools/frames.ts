/**
 * Frame / Animation Tools  — Milestone 3
 *
 * Full animation support: add, delete, duplicate, navigate, set duration/fps,
 * operate on individual cels, and export frames or spritesheet.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";

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
      fps: z.number().positive().describe("Frames per second (e.g. 12, 24)"),
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
      after_frame: z
        .number()
        .int()
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
      index: z
        .number()
        .int()
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
      index: z
        .number()
        .int()
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
      index: z
        .number()
        .int()
        .optional()
        .describe("Frame index (defaults to current frame)"),
      duration: z
        .number()
        .positive()
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
      index: z.number().int().min(0).describe("Frame index to switch to"),
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
      frame: z
        .number()
        .int()
        .min(0)
        .describe("Frame index"),
      layer: z
        .number()
        .int()
        .min(0)
        .describe("Layer index"),
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
      src_frame: z.number().int().min(0).describe("Source frame index"),
      src_layer: z.number().int().min(0).describe("Source layer index"),
      dst_frame: z.number().int().min(0).describe("Destination frame index"),
      dst_layer: z.number().int().min(0).describe("Destination layer index"),
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
      frame: z
        .number()
        .int()
        .min(0)
        .optional()
        .describe("Frame index (defaults to current frame)"),
      layer: z
        .number()
        .int()
        .min(0)
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
      columns: z
        .number()
        .int()
        .min(1)
        .optional()
        .describe("Spritesheet columns (only for 'spritesheet' mode, defaults to frame count)"),
      start_frame: z
        .number()
        .int()
        .min(0)
        .optional()
        .describe("First frame to export (only for 'frames' mode, defaults to 0)"),
      end_frame: z
        .number()
        .int()
        .min(0)
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
}
