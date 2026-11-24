/**
 * Frame / Animation Tools
 *
 * Full animation support: add, delete, duplicate, navigate, set duration/fps,
 * operate on individual cels, and export frames or spritesheet.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import * as nodePath from "path";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat, layerHandleSchema, framesArraySchema, frameRangeFields } from "../utils/schema_helpers.js";
import { resolveSafeDirectory, resolveSafeOutputFile, sanitizeAssetName } from "../utils/path_guard.js";

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
    "Add one or more blank animation frames after the specified frame index in a single undoable operation.",
    {
      after_frame: coerceInt(0)
        .optional()
        .describe("Insert after this frame index (defaults to current frame)"),
      count: coerceInt(1, 500)
        .default(1)
        .describe("Number of blank frames to insert sequentially (1..500, default: 1)"),
    },
    async ({ after_frame, count }) => {
      const params: Record<string, unknown> = { count };
      if (after_frame !== undefined) params.after_frame = after_frame;
      const result = await sendCommand("add_frame", params);
      const inserted = result.data?.inserted_range as number[] | undefined;
      const rangeStr = count > 1 && inserted ? ` [frames ${inserted[0]}..${inserted[1]}]` : "";
      let text = result.success
        ? `✅ Added ${result.data?.count ?? count} frame(s)${rangeStr} (total: ${result.data?.total_frames})`
        : `❌ ${result.error}`;
      if (result.data?.active_cursor) {
        text += `\n🎯 Active: frame ${result.data.active_cursor.frame}, layer ${result.data.active_cursor.layer} ("${result.data.active_cursor.layer_name}")`;
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
      let text = result.success
        ? `✅ Frame ${index ?? "current"} deleted (total: ${result.data?.total_frames})`
        : `❌ ${result.error}`;
      if (result.data?.active_cursor) {
        text += `\n🎯 Active: frame ${result.data.active_cursor.frame}, layer ${result.data.active_cursor.layer} ("${result.data.active_cursor.layer_name}")`;
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
  );

  server.tool(
    "duplicate_frame",
    "Duplicate an animation frame one or more times, inserting copies immediately after the original in a single undoable operation. All layer pixel data is deep-copied.",
    {
      index: coerceInt(0)
        .optional()
        .describe("Frame index to duplicate (defaults to current frame)"),
      count: coerceInt(1, 100)
        .default(1)
        .describe("Number of copies to insert (1..100, default: 1)"),
    },
    async ({ index, count }) => {
      const params: Record<string, unknown> = { count };
      if (index !== undefined) params.index = index;
      const result = await sendCommand("duplicate_frame", params);
      const inserted = result.data?.inserted_range as number[] | undefined;
      const whereStr =
        count > 1 && inserted
          ? `at indices ${inserted[0]}..${inserted[1]}`
          : `at index ${result.data?.inserted_at}`;
      let text = result.success
        ? `✅ Frame duplicated ${count > 1 ? `${count}x ` : ""}${whereStr} (total: ${result.data?.total_frames}, pixels copied: ${result.data?.pixels_copied ?? 0})`
        : `❌ ${result.error}`;
      if (result.data?.warning) {
        text += `\n⚠️ Warning: ${result.data.warning}`;
      }
      if (result.data?.active_cursor) {
        text += `\n🎯 Active: frame ${result.data.active_cursor.frame}, layer ${result.data.active_cursor.layer} ("${result.data.active_cursor.layer_name}")`;
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
  );

  server.tool(
    "set_frame_duration",
    "Set the duration multiplier of one or more frames (relative to 1/fps). Supports single 'index', explicit 'frames' list, 'from_frame'/'to_frame' range, 'tag', or 'all_frames'.",
    {
      index: coerceInt(0)
        .optional()
        .describe("Single frame index (defaults to current frame when no batch selector is given)"),
      duration: coerceFloat(0.01)
        .describe("Duration multiplier (1.0 = normal speed, 2.0 = half speed)"),
      ...frameRangeFields,
    },
    async ({ index, duration, frames, from_frame, to_frame, tag, all_frames }) => {
      const params: Record<string, unknown> = { duration };
      if (index !== undefined) params.index = index;
      if (frames !== undefined) params.frames = frames;
      if (from_frame !== undefined) params.from_frame = from_frame;
      if (to_frame !== undefined) params.to_frame = to_frame;
      if (tag !== undefined) params.tag = tag;
      if (all_frames !== undefined) params.all_frames = all_frames;
      const result = await sendCommand("set_frame_duration", params);
      const count = result.data?.frames_updated ?? 1;
      const label = count > 1 ? `${count} frames (${(result.data?.frames as number[]).join(", ")})` : `Frame ${result.data?.index ?? index ?? "current"}`;
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ ${label} duration set to ${duration}x`
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
      layer: layerHandleSchema.describe("Target layer index (0-based integer), stable layer ID, or layer name"),
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
    "Copy pixel data from one cel to one or multiple destination frames in a single call. Supports single 'dst_frame', explicit 'dst_frames' list, 'dst_from_frame'/'dst_to_frame' range, or 'dst_tag'.",
    {
      src_frame: coerceInt(0).describe("Source frame index"),
      src_layer: layerHandleSchema.describe("Source layer index, ID, or name (defaults to active layer)"),
      dst_frame: coerceInt(0)
        .optional()
        .describe("Single destination frame index (optional if dst_frames, dst_from_frame/dst_to_frame, or dst_tag is given)"),
      dst_frames: framesArraySchema.describe("Optional array of destination frame indices to copy into (e.g. [1, 2, 3])"),
      dst_from_frame: coerceInt(0)
        .optional()
        .describe("Optional inclusive start destination frame index"),
      dst_to_frame: coerceInt(0)
        .optional()
        .describe("Optional inclusive end destination frame index"),
      dst_tag: z
        .string()
        .optional()
        .describe("Optional animation tag name — copies source cel into all frames of that tag"),
      dst_layer: layerHandleSchema.describe("Destination layer index, ID, or name (defaults to src_layer)"),
    },
    async ({ src_frame, src_layer, dst_frame, dst_frames, dst_from_frame, dst_to_frame, dst_tag, dst_layer }) => {
      const params: Record<string, unknown> = { src_frame };
      if (src_layer !== undefined) params.src_layer = src_layer;
      if (dst_frame !== undefined) params.dst_frame = dst_frame;
      if (dst_frames !== undefined) params.dst_frames = dst_frames;
      if (dst_from_frame !== undefined) params.dst_from_frame = dst_from_frame;
      if (dst_to_frame !== undefined) params.dst_to_frame = dst_to_frame;
      if (dst_tag !== undefined) params.dst_tag = dst_tag;
      if (dst_layer !== undefined) params.dst_layer = dst_layer;

      const result = await sendCommand("copy_cel", params);
      const copiedList = result.data?.dst_frames as number[] | undefined;
      const dstLabel =
        copiedList && copiedList.length > 1
          ? `frames:[${copiedList.join(",")}]`
          : `frame:${result.data?.dst_frame ?? dst_frame}`;
      let text = result.success
        ? `✅ Cel [frame:${src_frame} layer:${result.data?.src_layer ?? src_layer}] → [${dstLabel} layer:${result.data?.dst_layer ?? dst_layer ?? src_layer}] (${result.data?.cels_copied ?? 1} cel(s), ${result.data?.pixels_copied ?? 0} pixels each)`
        : `❌ ${result.error}`;
      if (result.data?.warning) {
        text += `\n⚠️ Warning: ${result.data.warning}`;
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
  );

  server.tool(
    "clear_cel",
    "Clear all pixels in one or more cels, making them fully transparent. Supports single 'frame', explicit 'frames' list, 'from_frame'/'to_frame' range, 'tag', or 'all_frames'. Recorded in undo history.",
    {
      frame: coerceInt(0)
        .optional()
        .describe("Single frame index (defaults to current frame when no batch selector is given)"),
      layer: layerHandleSchema
        .describe("Target layer index (defaults to current layer), stable layer ID, or layer name"),
      ...frameRangeFields,
    },
    async ({ frame, layer, frames, from_frame, to_frame, tag, all_frames }) => {
      const params: Record<string, unknown> = {};
      if (frame !== undefined) params.frame = frame;
      if (layer !== undefined) params.layer = layer;
      if (frames !== undefined) params.frames = frames;
      if (from_frame !== undefined) params.from_frame = from_frame;
      if (to_frame !== undefined) params.to_frame = to_frame;
      if (tag !== undefined) params.tag = tag;
      if (all_frames !== undefined) params.all_frames = all_frames;
      const result = await sendCommand("clear_cel", params);
      const clearedCount = result.data?.frames_cleared ?? 1;
      const frameStr =
        clearedCount > 1
          ? `frames:[${(result.data?.frames as number[]).join(",")}]`
          : `frame:${result.data?.frame}`;
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Cleared ${clearedCount} cel(s) on [${frameStr}, layer:${result.data?.layer}] (action is undoable with 'undo')`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  // ── EXPORT ─────────────────────────────────────────────────────────────

  server.tool(
    "export_animation",
    "Export the animation. Mode 'frames' saves individual PNGs (frame_0000.png, frame_0001.png, …). Mode 'spritesheet' packs frames into one image grid. Both modes support 'tag', 'start_frame'/'end_frame', and nearest-neighbor 'scale'; spritesheet mode also supports 'exact_path' or 'exact_filename' to avoid the default '_spritesheet.png' suffix.",
    {
      path: z
        .string()
        .optional()
        .describe("Absolute directory path to export into (required unless 'exact_path' is provided in spritesheet mode)"),
      prefix: z
        .string()
        .default("frame")
        .describe("Filename prefix (e.g. 'walk' → walk_0000.png or walk_spritesheet.png)"),
      mode: z
        .enum(["frames", "spritesheet"])
        .default("frames")
        .describe("Export mode: 'frames' or 'spritesheet'"),
      columns: coerceInt(1)
        .optional()
        .describe("Spritesheet columns (only for 'spritesheet' mode, defaults to exported frame count)"),
      tag: z
        .string()
        .optional()
        .describe("Optional animation tag name — exports only frames belonging to that tag (works in both 'frames' and 'spritesheet' modes)"),
      start_frame: coerceInt(0)
        .optional()
        .describe("First 0-based frame index to export (works in both 'frames' and 'spritesheet' modes, defaults to 0)"),
      end_frame: coerceInt(0)
        .optional()
        .describe("Last 0-based frame index to export (works in both 'frames' and 'spritesheet' modes, defaults to last frame)"),
      exact_path: z
        .string()
        .optional()
        .describe("Exact absolute .png file path for 'spritesheet' mode (e.g. '/path/to/en_shambler_walk.png'), suppressing the '_spritesheet.png' suffix"),
      exact_filename: z
        .string()
        .optional()
        .describe("Exact .png filename inside 'path' directory for 'spritesheet' mode (e.g. 'en_shambler_walk.png'), suppressing the '_spritesheet.png' suffix"),
      scale: coerceInt(1, 32)
        .default(1)
        .describe("Non-destructive nearest-neighbor upscale multiplier (1..32, default: 1)"),
    },
    async ({ path, prefix, mode, columns, tag, start_frame, end_frame, exact_path, exact_filename, scale }) => {
      const params: Record<string, unknown> = { mode, scale };
      try {
        if (exact_path !== undefined && exact_path.trim() !== "") {
          if (mode !== "spritesheet") {
            return { content: [{ type: "text" as const, text: "❌ 'exact_path' is only supported when mode is 'spritesheet'." }] };
          }
          const normalizedExact = exact_path.toLowerCase().endsWith(".png") ? exact_path : `${exact_path}.png`;
          params.exact_path = resolveSafeOutputFile(normalizedExact, [".png"], "exact_path");
        } else {
          if (!path || path.trim() === "") {
            return {
              content: [
                {
                  type: "text" as const,
                  text: "❌ Missing 'path' directory parameter (or provide 'exact_path' in spritesheet mode).",
                },
              ],
            };
          }
          const safeDir = resolveSafeDirectory(path, "path");
          params.path = safeDir;

          if (exact_filename !== undefined && exact_filename.trim() !== "") {
            if (mode !== "spritesheet") {
              return { content: [{ type: "text" as const, text: "❌ 'exact_filename' is only supported when mode is 'spritesheet'." }] };
            }
            const cleanFn = sanitizeAssetName(exact_filename, "exact_filename");
            const pngName = cleanFn.toLowerCase().endsWith(".png") ? cleanFn : `${cleanFn}.png`;
            params.exact_path = resolveSafeOutputFile(nodePath.join(safeDir, pngName), [".png"], "exact_filename");
          } else {
            params.prefix = sanitizeAssetName(prefix, "prefix");
          }
        }
      } catch (err) {
        return { content: [{ type: "text" as const, text: `❌ ${err instanceof Error ? err.message : String(err)}` }] };
      }

      if (columns !== undefined) params.columns = columns;
      if (tag !== undefined) params.tag = tag;
      if (start_frame !== undefined) params.start_frame = start_frame;
      if (end_frame !== undefined) params.end_frame = end_frame;

      const result = await sendCommand("export_animation", params);
      if (result.success && result.data) {
        const d = result.data;
        const tagNote = d.tag ? `, tag: "${d.tag}"` : "";
        const rangeNote = d.start_frame !== undefined ? ` [${d.start_frame}..${d.end_frame}${tagNote}]` : "";
        const scaleNote = d.scale && d.scale > 1 ? `, scale: ${d.scale}x` : "";
        if (d.mode === "spritesheet") {
          const sizeNote = d.width && d.height ? ` (${d.width}×${d.height}px${scaleNote})` : "";
          return {
            content: [
              {
                type: "text" as const,
                text: `✅ Spritesheet exported: ${d.path}\n  ${d.frames} frames${rangeNote}, ${d.columns}×${d.rows} grid${sizeNote}`,
              },
            ],
          };
        }
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Frames exported: ${d.count} files${rangeNote}${scaleNote}\n  ${(d.files as string[]).join("\n  ")}`,
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
      layer: layerHandleSchema.describe("Layer index, ID, or name to tween (defaults to active layer)"),
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
    "Render the current project's animation (or a specific tag / frame range) directly to an animated .gif file on disk, with optional crisp nearest-neighbor scaling.",
    {
      path: z.string().describe("Absolute file path to save the .gif file (e.g. '/path/to/animation.gif')"),
      scale: coerceInt(1, 32)
        .default(1)
        .describe("Non-destructive nearest-neighbor upscale multiplier (1..32, e.g. 4 for crisp 4x preview GIFs)"),
      tag: z
        .string()
        .optional()
        .describe("Optional animation tag name — exports only frames belonging to that tag"),
      start_frame: coerceInt(0)
        .optional()
        .describe("Optional first 0-based frame index to export"),
      end_frame: coerceInt(0)
        .optional()
        .describe("Optional last 0-based frame index to export"),
    },
    async ({ path, scale, tag, start_frame, end_frame }) => {
      let safePath: string;
      try {
        safePath = resolveSafeOutputFile(path, [".gif"], "path");
      } catch (err) {
        return { content: [{ type: "text" as const, text: `❌ ${err instanceof Error ? err.message : String(err)}` }] };
      }
      const params: Record<string, unknown> = { path: safePath, scale };
      if (tag !== undefined) params.tag = tag;
      if (start_frame !== undefined) params.start_frame = start_frame;
      if (end_frame !== undefined) params.end_frame = end_frame;
      const result = await sendCommand("export_gif", params);
      const d = result.data;
      const tagNote = d?.tag ? `, tag: "${d.tag}"` : "";
      const rangeNote = d?.start_frame !== undefined ? ` [${d.start_frame}..${d.end_frame}${tagNote}]` : "";
      const dimNote = d?.width && d?.height ? `, ${d.width}×${d.height}px (${d.scale ?? scale}x)` : "";
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Animated GIF exported to: ${d?.path} (${d?.frames} frames${rangeNote}${dimNote}, ${d?.size_bytes ?? ""} bytes)`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "export_apng",
    "Render the current project's animation (or a specific tag / frame range) directly to an animated .apng file on disk, with optional crisp nearest-neighbor scaling.",
    {
      path: z.string().describe("Absolute file path to save the .apng file (e.g. '/path/to/animation.apng')"),
      scale: coerceInt(1, 32)
        .default(1)
        .describe("Non-destructive nearest-neighbor upscale multiplier (1..32, default: 1)"),
      tag: z
        .string()
        .optional()
        .describe("Optional animation tag name — exports only frames belonging to that tag"),
      start_frame: coerceInt(0)
        .optional()
        .describe("Optional first 0-based frame index to export"),
      end_frame: coerceInt(0)
        .optional()
        .describe("Optional last 0-based frame index to export"),
    },
    async ({ path, scale, tag, start_frame, end_frame }) => {
      let safePath: string;
      try {
        safePath = resolveSafeOutputFile(path, [".apng", ".png"], "path");
      } catch (err) {
        return { content: [{ type: "text" as const, text: `❌ ${err instanceof Error ? err.message : String(err)}` }] };
      }
      const params: Record<string, unknown> = { path: safePath, scale };
      if (tag !== undefined) params.tag = tag;
      if (start_frame !== undefined) params.start_frame = start_frame;
      if (end_frame !== undefined) params.end_frame = end_frame;
      const result = await sendCommand("export_apng", params);
      const d = result.data;
      const tagNote = d?.tag ? `, tag: "${d.tag}"` : "";
      const rangeNote = d?.start_frame !== undefined ? ` [${d.start_frame}..${d.end_frame}${tagNote}]` : "";
      const dimNote = d?.width && d?.height ? `, ${d.width}×${d.height}px (${d.scale ?? scale}x)` : "";
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Animated APNG exported to: ${d?.path} (${d?.frames} frames${rangeNote}${dimNote})`
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
      let safeTargetDir: string;
      let safeBaseName: string | undefined;
      try {
        safeTargetDir = resolveSafeDirectory(target_dir, "target_dir");
        if (base_name !== undefined && base_name.trim() !== "") {
          safeBaseName = sanitizeAssetName(base_name, "base_name");
        }
      } catch (err) {
        return { content: [{ type: "text" as const, text: `❌ ${err instanceof Error ? err.message : String(err)}` }] };
      }

      const params: Record<string, unknown> = { target_dir: safeTargetDir };
      if (safeBaseName !== undefined) params.base_name = safeBaseName;
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
