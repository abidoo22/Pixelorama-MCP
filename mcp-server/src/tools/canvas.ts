/**
 * Canvas & Project Tools
 *
 * Tools for creating canvases, getting project info, saving, exporting,
 * auto-cropping, and integer scaling.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt } from "../utils/schema_helpers.js";

export function registerCanvasTools(server: McpServer): void {
  server.tool(
    "create_canvas",
    "Create a new canvas/project in Pixelorama with the specified dimensions, name, and optional fill color.",
    {
      width: coerceInt(1, 4096)
        .default(64)
        .describe("Canvas width in pixels"),
      height: coerceInt(1, 4096)
        .default(64)
        .describe("Canvas height in pixels"),
      name: z
        .string()
        .default("untitled")
        .describe("Project name"),
      fill_color: z
        .string()
        .optional()
        .describe("Fill color as hex (e.g. '#FF0000' or 'transparent')"),
    },
    async ({ width, height, name, fill_color }) => {
      const result = await sendCommand("create_canvas", {
        width,
        height,
        name,
        fill_color: fill_color || "",
      });

      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Canvas created: ${width}×${height} pixels, name: "${name}"`
              : `❌ Failed to create canvas: ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "get_canvas_info",
    "Get information about the current canvas/project including dimensions, number of layers, frames, and which layer/frame is active.",
    {},
    async () => {
      const result = await sendCommand("get_canvas_info", {});

      if (result.success && result.data) {
        const d = result.data;
        return {
          content: [
            {
              type: "text" as const,
              text: `Canvas Info:\n- Name: ${d.name}\n- Size: ${d.width}×${d.height}\n- Layers: ${d.layers}\n- Frames: ${d.frames}\n- Active layer: ${d.current_layer}\n- Active frame: ${d.current_frame}`,
            },
          ],
        };
      }

      return {
        content: [
          { type: "text" as const, text: `❌ ${result.error}` },
        ],
      };
    }
  );

  server.tool(
    "save_project",
    "Save the current Pixelorama project (.pxo file). Optionally specify a file path.",
    {
      path: z.string().optional().describe("Optional file path to save the project (.pxo file)"),
    },
    async ({ path }) => {
      const params: Record<string, unknown> = {};
      if (path) params.path = path;
      const result = await sendCommand("save_project", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Project saved to: ${result.data?.path}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "export_image",
    "Export the current canvas as a PNG image to the specified file path.",
    {
      path: z.string().describe("Absolute file path to save the PNG (e.g. '/home/user/sprite.png')"),
      frame: coerceInt(0)
        .default(0)
        .describe("Frame index to export (0-based)"),
    },
    async ({ path, frame }) => {
      const result = await sendCommand("export_image", { path, frame });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Image exported to: ${path}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "fit_viewport",
    "Center and fit the canvas in the Pixelorama viewport. Call this after creating or finishing a drawing.",
    {},
    async () => {
      const result = await sendCommand("fit_viewport", {});
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? "✅ Viewport fitted to canvas"
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "crop_to_content",
    "Automatically trim and crop the canvas to fit the bounding box of non-transparent pixels. Perfect for removing excess blank space around drawn sprites.",
    {},
    async () => {
      const result = await sendCommand("crop_to_content", {});
      if (result.success && result.data) {
        const orig = result.data.original_size as number[];
        const nsize = result.data.new_size as number[];
        const crop = result.data.crop_rect as number[];
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Canvas cropped to content: ${orig[0]}×${orig[1]} → ${nsize[0]}×${nsize[1]} pixels (Bounds: x=${crop[0]}, y=${crop[1]})`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );

  server.tool(
    "scale_canvas",
    "Scale the canvas using pixel-perfect nearest-neighbor interpolation. Use integer factors (2, 3, 4) for crisp retro scaling.",
    {
      factor: coerceInt(1, 16)
        .optional()
        .describe("Integer scaling factor (e.g. 2 for 2x, 4 for 4x upscale)"),
      width: coerceInt(1, 8192)
        .optional()
        .describe("Explicit target width in pixels"),
      height: coerceInt(1, 8192)
        .optional()
        .describe("Explicit target height in pixels"),
    },
    async ({ factor, width, height }) => {
      const params: Record<string, unknown> = {};
      if (factor !== undefined) params.factor = factor;
      if (width !== undefined) params.width = width;
      if (height !== undefined) params.height = height;

      const result = await sendCommand("scale_canvas", params);
      if (result.success && result.data) {
        const orig = result.data.original_size as number[];
        const nsize = result.data.new_size as number[];
        return {
          content: [
            {
              type: "text" as const,
              text: `✅ Canvas scaled from ${orig[0]}×${orig[1]} to ${nsize[0]}×${nsize[1]} pixels`,
            },
          ],
        };
      }
      return { content: [{ type: "text" as const, text: `❌ ${result.error}` }] };
    }
  );
}
