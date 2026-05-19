/**
 * Layer Tools
 *
 * Tools for adding layers and querying layer information.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";

export function registerLayerTools(server: McpServer): void {
  server.tool(
    "add_layer",
    "Add a new layer to the current project. Layers are counted bottom to top (0 is the bottom-most layer).",
    {
      name: z
        .string()
        .default("")
        .describe("Layer name (empty for auto-naming)"),
      type: z
        .number()
        .int()
        .min(0)
        .max(2)
        .default(0)
        .describe("Layer type: 0 = Pixel, 1 = Group, 2 = 3D"),
      above_layer: z
        .number()
        .int()
        .optional()
        .describe("Insert above this layer index (defaults to current layer)"),
    },
    async ({ name, type, above_layer }) => {
      const params: Record<string, unknown> = { name, type };
      if (above_layer !== undefined) params.above_layer = above_layer;

      const result = await sendCommand("add_layer", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Layer added${name ? `: "${name}"` : ""} (type: ${["Pixel", "Group", "3D"][type]})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "get_layers",
    "List all layers in the current project with their index, name, visibility, and type.",
    {},
    async () => {
      const result = await sendCommand("get_layers", {});
      if (result.success && result.data) {
        const layers = result.data.layers as Array<{
          index: number;
          name: string;
          visible: boolean;
          locked: boolean;
          opacity: number;
          blend_mode: number;
          type: string;
        }>;
        const layerList = layers
          .map(
            (l) =>
              `  [${l.index}] ${l.name} (${l.type}) ${l.visible ? "👁" : "🚫"} Opacity:${Math.round(l.opacity * 100)}% BlendMode:${l.blend_mode}`
          )
          .join("\n");
        return {
          content: [
            {
              type: "text" as const,
              text: `Layers (current: ${result.data.current_layer}):\n${layerList}`,
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
    "delete_layer",
    "Delete a layer from the project by its index.",
    {
      index: z.number().int().min(0).describe("Layer index to delete"),
    },
    async ({ index }) => {
      const result = await sendCommand("delete_layer", { index });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Layer ${index} deleted` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "set_layer_opacity",
    "Set the opacity of a layer (0.0 to 1.0).",
    {
      index: z.number().int().min(0).describe("Layer index"),
      opacity: z.number().min(0).max(1).describe("Opacity (0.0 = transparent, 1.0 = opaque)"),
    },
    async ({ index, opacity }) => {
      const result = await sendCommand("set_layer_opacity", { index, opacity });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Layer ${index} opacity set to ${opacity}` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "set_layer_blend_mode",
    "Set the blend mode of a layer (0 = Normal, 1 = Erase, 2 = Darken, 3 = Multiply, 4 = Color Burn, etc.).",
    {
      index: z.number().int().min(0).describe("Layer index"),
      blend_mode: z.number().int().min(0).max(21).describe("Blend mode enum value (0 = Normal)"),
    },
    async ({ index, blend_mode }) => {
      const result = await sendCommand("set_layer_blend_mode", { index, blend_mode });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Layer ${index} blend mode set to ${blend_mode}` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "set_layer_visibility",
    "Set the visibility of a layer.",
    {
      index: z.number().int().min(0).describe("Layer index"),
      visible: z.boolean().describe("True to show layer, false to hide it"),
    },
    async ({ index, visible }) => {
      const result = await sendCommand("set_layer_visibility", { index, visible });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success ? `✅ Layer ${index} visibility set to ${visible}` : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
