/**
 * Vision Tools — Multimodal Visual Inspection
 *
 * Allows multimodal LLMs (Claude 3.7, GPT-4o, etc.) to visually inspect the Pixelorama canvas
 * and self-correct their drawings.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat } from "../utils/schema_helpers.js";

export function registerVisionTools(server: McpServer): void {
  server.tool(
    "capture_canvas_image",
    "Capture a visual screenshot of the current canvas (all visible layers blended) as a PNG image. Supports sub-region cropping and downscaling to reduce payload size and context usage.",
    {
      frame: coerceInt(0)
        .optional()
        .describe("Frame index to capture (defaults to current active frame)"),
      x: coerceInt(0).optional().describe("Optional crop region top-left X coordinate"),
      y: coerceInt(0).optional().describe("Optional crop region top-left Y coordinate"),
      width: coerceInt(1).optional().describe("Optional crop region width in pixels"),
      height: coerceInt(1).optional().describe("Optional crop region height in pixels"),
      max_size: coerceInt(1, 4096).optional().describe("Optional maximum image dimension in pixels (downscales to fit while preserving aspect ratio)"),
      scale: coerceFloat(0.01, 1.0).optional().describe("Optional downscale scale factor (e.g. 0.5 for 50% scale, 0.25 for 25% scale)"),
    },
    async ({ frame, x, y, width, height, max_size, scale }) => {
      const params: Record<string, unknown> = {};
      if (frame !== undefined) params.frame = frame;
      if (x !== undefined) params.x = x;
      if (y !== undefined) params.y = y;
      if (width !== undefined) params.width = width;
      if (height !== undefined) params.height = height;
      if (max_size !== undefined) params.max_size = max_size;
      if (scale !== undefined) params.scale = scale;

      const result = await sendCommand("get_canvas_image_base64", params);

      if (result.success && result.data && typeof result.data.base64 === "string") {
        const d = result.data;
        const byteSize = Math.round(((d.base64 as string).length * 3) / 4);
        const regionInfo = d.region ? ` region (${d.region.x},${d.region.y} ${d.region.width}x${d.region.height})` : "";
        const downscaleInfo = d.downscaled ? ` [downscaled to ${d.width}×${d.height}]` : "";
        return {
          content: [
            {
              type: "image" as const,
              data: d.base64 as string,
              mimeType: "image/png",
            },
            {
              type: "text" as const,
              text: `🖼️ Canvas visual snapshot captured (${d.width}×${d.height} px${regionInfo}${downscaleInfo}, frame ${d.frame}, ~${Math.round(byteSize / 1024)} KB PNG).`,
            },
          ],
        };
      }

      return {
        content: [
          {
            type: "text" as const,
            text: `❌ Failed to capture canvas image: ${result.error ?? "Unknown error"}`,
          },
        ],
      };
    }
  );
}
