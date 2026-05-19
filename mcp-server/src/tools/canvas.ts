/**
 * Canvas & Project Tools
 *
 * Tools for creating canvases, getting project info, saving, and exporting.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";

export function registerCanvasTools(server: McpServer): void {
  server.tool(
    "create_canvas",
    "Create a new canvas/project in Pixelorama with the specified dimensions, name, and optional fill color.",
    {
      width: z
        .number()
        .int()
        .min(1)
        .max(4096)
        .default(64)
        .describe("Canvas width in pixels"),
      height: z
        .number()
        .int()
        .min(1)
        .max(4096)
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
    "Save the current Pixelorama project. The project must have been saved before (has a save path).",
    {},
    async () => {
      const result = await sendCommand("save_project", {});
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
      frame: z
        .number()
        .int()
        .min(0)
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

}

