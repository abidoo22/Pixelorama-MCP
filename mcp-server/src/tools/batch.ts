/**
 * Batch Command Execution Tool
 *
 * Executes an ordered list of Pixelorama commands inside Godot in a single
 * MCP / HTTP round-trip, drastically cutting multi-frame setup latency while
 * strictly enforcing path_guard.ts security checks and tool allowlisting.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import * as nodePath from "path";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceBool, safeJsonArray, MAX_FLAT_PIXEL_ELEMENTS } from "../utils/schema_helpers.js";
import { resolveSafeDirectory, resolveSafeOutputFile, sanitizeAssetName } from "../utils/path_guard.js";

const MAX_BATCH_OPS = 200;

const ALLOWED_IN_EDITOR_TOOLS = new Set<string>([
  // Canvas & viewport
  "create_canvas",
  "get_canvas_info",
  "list_canvases",
  "switch_canvas",
  "close_canvas",
  "rename_canvas",
  "fit_viewport",
  "crop_to_content",
  "scale_canvas",
  "set_tile_mode",
  "set_symmetry_guide",
  "set_onion_skinning",
  // Drawing & procedural
  "undo",
  "redo",
  "draw_pixel",
  "draw_pixels",
  "draw_pixels_fast",
  "draw_rect",
  "draw_line",
  "draw_path",
  "draw_polygon",
  "draw_ellipse",
  "draw_text",
  "fill_area",
  "apply_outline",
  "apply_dithering",
  "apply_drop_shadow",
  "apply_glow",
  "apply_gradient",
  "check_seamless_tile",
  "mirror_layer",
  "transform_cel",
  "rotate_cel",
  // Inspection & QA
  "get_pixel",
  "get_pixels",
  "get_region",
  "get_layer_markers",
  "get_palette_usage",
  "clean_isolated_pixels",
  "validate_sprite",
  "get_history",
  "get_canvas_snapshot",
  // Color & palette
  "set_color",
  "get_color",
  "color_replace",
  "adjust_hsv",
  "remap_to_palette",
  "get_palette_colors",
  "create_palette",
  "add_palette_color",
  "set_palette_color",
  "list_palettes",
  "switch_palette",
  "delete_palette",
  // Layers
  "add_layer",
  "duplicate_layer",
  "merge_layers",
  "create_layer_group",
  "delete_layer",
  "get_layers",
  "set_layer_opacity",
  "set_layer_blend_mode",
  "set_layer_visibility",
  "set_layer_name",
  "reorder_layers",
  // Frames, cels & tags
  "add_frame",
  "delete_frame",
  "duplicate_frame",
  "set_frame_duration",
  "switch_frame",
  "get_frames",
  "get_fps",
  "set_fps",
  "reverse_frames",
  "tween_cel",
  "add_animation_tag",
  "get_animation_tags",
  "delete_animation_tag",
  "switch_cel",
  "copy_cel",
  "clear_cel",
  // Selection
  "select_rect",
  "select_by_color",
  "invert_selection",
  "transform_selection",
  "select_all",
  "deselect",
]);

const GUARDED_FILE_OUTPUT_TOOLS = new Set<string>([
  "save_project",
  "export_image",
  "export_animation",
  "export_gif",
  "export_apng",
]);

function sanitizeBatchOperation(
  index: number,
  rawTool: string,
  rawParams: Record<string, unknown>
): { tool: string; params: Record<string, unknown> } {
  const tool = rawTool.trim();
  const params: Record<string, unknown> = { ...rawParams };

  if (tool === "batch_commands" || tool === "eval_gdscript") {
    throw new Error(`operations[${index}]: Tool '${tool}' is not permitted inside batch_commands.`);
  }

  if (!ALLOWED_IN_EDITOR_TOOLS.has(tool) && !GUARDED_FILE_OUTPUT_TOOLS.has(tool)) {
    throw new Error(`operations[${index}]: Tool '${tool}' is not allowed inside batch_commands.`);
  }

  if (tool === "draw_pixels_fast" || tool === "draw_pixels") {
    const flat = (params.data ?? params.flat_pixels) as unknown;
    if (Array.isArray(flat) && flat.length > MAX_FLAT_PIXEL_ELEMENTS) {
      throw new Error(
        `operations[${index}] (${tool}): flat pixel array exceeds maximum safe limit (${MAX_FLAT_PIXEL_ELEMENTS} elements).`
      );
    }
  }

  if (tool === "save_project") {
    if (typeof params.path === "string" && params.path.trim() !== "") {
      params.path = resolveSafeOutputFile(params.path, [".pxo"], `operations[${index}].params.path`);
    }
  } else if (tool === "export_image") {
    if (typeof params.path !== "string" || params.path.trim() === "") {
      throw new Error(`operations[${index}] (export_image): Missing required 'path'.`);
    }
    params.path = resolveSafeOutputFile(params.path, [".png"], `operations[${index}].params.path`);
  } else if (tool === "export_gif") {
    if (typeof params.path !== "string" || params.path.trim() === "") {
      throw new Error(`operations[${index}] (export_gif): Missing required 'path'.`);
    }
    params.path = resolveSafeOutputFile(params.path, [".gif"], `operations[${index}].params.path`);
  } else if (tool === "export_apng") {
    if (typeof params.path !== "string" || params.path.trim() === "") {
      throw new Error(`operations[${index}] (export_apng): Missing required 'path'.`);
    }
    params.path = resolveSafeOutputFile(params.path, [".apng", ".png"], `operations[${index}].params.path`);
  } else if (tool === "export_animation") {
    const mode = typeof params.mode === "string" ? params.mode : "frames";
    const exactPath = typeof params.exact_path === "string" ? params.exact_path.trim() : "";
    const exactFilename = typeof params.exact_filename === "string" ? params.exact_filename.trim() : "";
    if (exactPath !== "") {
      if (mode !== "spritesheet") {
        throw new Error(`operations[${index}] (export_animation): 'exact_path' is only supported in 'spritesheet' mode.`);
      }
      const norm = exactPath.toLowerCase().endsWith(".png") ? exactPath : `${exactPath}.png`;
      params.exact_path = resolveSafeOutputFile(norm, [".png"], `operations[${index}].params.exact_path`);
    } else {
      if (typeof params.path !== "string" || params.path.trim() === "") {
        throw new Error(`operations[${index}] (export_animation): Missing required 'path' directory.`);
      }
      const safeDir = resolveSafeDirectory(params.path, `operations[${index}].params.path`);
      params.path = safeDir;
      if (exactFilename !== "") {
        if (mode !== "spritesheet") {
          throw new Error(`operations[${index}] (export_animation): 'exact_filename' is only supported in 'spritesheet' mode.`);
        }
        const cleanFn = sanitizeAssetName(exactFilename, `operations[${index}].params.exact_filename`);
        const pngName = cleanFn.toLowerCase().endsWith(".png") ? cleanFn : `${cleanFn}.png`;
        params.exact_path = resolveSafeOutputFile(
          nodePath.join(safeDir, pngName),
          [".png"],
          `operations[${index}].params.exact_filename`
        );
        delete params.exact_filename;
      } else if (typeof params.prefix === "string" && params.prefix.trim() !== "") {
        params.prefix = sanitizeAssetName(params.prefix, `operations[${index}].params.prefix`);
      }
    }
  }

  return { tool, params };
}

export function registerBatchTools(server: McpServer): void {
  server.tool(
    "batch_commands",
    "Execute an ordered sequence of Pixelorama tool commands inside Godot in a single MCP/HTTP round-trip (max 200 operations). Ideal for setting up multi-frame animations, copying/nudging cels, tagging ranges, applying outlines/dithering, and exporting multiple tags without per-call round-trip overhead. Disallows nested 'batch_commands' and 'eval_gdscript'; file-output paths are strictly validated by path_guard.",
    {
      operations: safeJsonArray(
        z.object({
          tool: z.string().min(1).describe("Tool name to execute (e.g. 'add_frame', 'copy_cel', 'transform_cel', 'add_animation_tag', 'export_animation')"),
          params: z.record(z.any()).optional().default({}).describe("Parameters object for the tool"),
        }),
        1
      ).describe("Ordered array of { tool, params } operations (1..200)"),
      stop_on_error: coerceBool()
        .default(true)
        .describe("If true (default), halts execution at the first failed operation; if false, continues executing remaining operations"),
    },
    async ({ operations, stop_on_error }) => {
      if (operations.length > MAX_BATCH_OPS) {
        return {
          content: [
            {
              type: "text" as const,
              text: `❌ Batch size ${operations.length} exceeds maximum allowed ${MAX_BATCH_OPS} operations per call.`,
            },
          ],
        };
      }

      const sanitizedOps: Array<{ tool: string; params: Record<string, unknown> }> = [];
      try {
        for (let i = 0; i < operations.length; i++) {
          const op = operations[i];
          sanitizedOps.push(sanitizeBatchOperation(i, op.tool, op.params ?? {}));
        }
      } catch (err) {
        return {
          content: [
            {
              type: "text" as const,
              text: `❌ Batch validation failed: ${err instanceof Error ? err.message : String(err)}`,
            },
          ],
        };
      }

      const result = await sendCommand("batch_commands", {
        operations: sanitizedOps,
        stop_on_error,
      });

      const d = result.data;
      if (d && Array.isArray(d.results)) {
        const resList = d.results as Array<{
          index: number;
          tool: string;
          success: boolean;
          data?: Record<string, unknown>;
          error?: string;
        }>;
        const lines: string[] = [
          `${result.success ? "✅" : "⚠️"} Batch executed ${d.executed}/${d.total_requested} operations (${d.succeeded} succeeded, ${d.failed} failed${d.stopped_early ? ", stopped early" : ""}):`,
        ];
        for (const r of resList) {
          if (r.success) {
            lines.push(`  [${r.index}] ✅ ${r.tool}`);
          } else {
            lines.push(`  [${r.index}] ❌ ${r.tool}: ${r.error ?? "Failed"}`);
          }
        }
        return { content: [{ type: "text" as const, text: lines.join("\n") }] };
      }

      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? "✅ Batch completed" : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
