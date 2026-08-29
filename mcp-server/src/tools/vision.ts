/**
 * Vision Tools — Multimodal Visual Inspection
 *
 * Allows multimodal LLMs (Claude 3.7, GPT-4o, etc.) to visually inspect the Pixelorama canvas
 * and self-correct their drawings.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt } from "../utils/schema_helpers.js";

export function registerVisionTools(server: McpServer): void {
  server.tool(
    "capture_canvas_image",
    "Capture a visual screenshot of the current canvas (all visible layers blended) as a PNG image. Use this to visually inspect what you have drawn, verify proportions, check lighting/outlines, and self-correct.",
    {
      frame: coerceInt(0)
        .optional()
        .describe("Frame index to capture (defaults to current active frame)"),
    },
    async ({ frame }) => {
      const params: Record<string, unknown> = {};
      if (frame !== undefined) params.frame = frame;

      const result = await sendCommand("get_canvas_image_base64", params);

      if (result.success && result.data && typeof result.data.base64 === "string") {
        const d = result.data;
        return {
          content: [
            {
              type: "image" as const,
              data: d.base64 as string,
              mimeType: "image/png",
            },
            {
              type: "text" as const,
              text: `Canvas visual snapshot (${d.width}×${d.height} px, frame ${d.frame}). Inspect your artwork and refine as needed.`,
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
