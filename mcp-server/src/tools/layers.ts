/**
 * Layer Tools
 *
 * Tools for adding layers, deleting layers, opacity, blend modes, and visibility.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceFloat, coerceBool } from "../utils/schema_helpers.js";

export function registerLayerTools(server: McpServer): void {
  server.tool(
    "add_layer",
    "Add a new layer to the current project. Layers are counted bottom to top (0 is the bottom-most layer).",
    {
      name: z
        .string()
        .default("")
        .describe("Layer name (empty for auto-naming)"),
      type: coerceInt(0, 2)
        .default(0)
        .describe("Layer type: 0 = Pixel, 1 = Group, 2 = 3D"),
      above_layer: coerceInt(0)
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
      index: coerceInt(0).describe("Layer index to delete"),
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
      index: coerceInt(0).describe("Layer index"),
      opacity: coerceFloat(0, 1).describe("Opacity (0.0 = transparent, 1.0 = opaque)"),
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
      index: coerceInt(0).describe("Layer index"),
      blend_mode: coerceInt(0, 21).describe("Blend mode enum value (0 = Normal)"),
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
      index: coerceInt(0).describe("Layer index"),
      visible: coerceBool().describe("True to show layer, false to hide it"),
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

  server.tool(
    "set_layer_name",
    "Rename a layer in the project.",
    {
      index: coerceInt(0).describe("Layer index"),
      name: z.string().min(1).describe("New layer name (e.g. 'Background', 'Armor', 'Shadows')"),
    },
    async ({ index, name }) => {
      const result = await sendCommand("set_layer_name", { index, name });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Layer ${index} renamed from "${result.data?.old_name}" to "${name}"`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "reorder_layers",
    "Change the stack order of layers (move a layer from one index to another).",
    {
      from_index: coerceInt(0).describe("Source layer index to move"),
      to_index: coerceInt(0).describe("Destination layer index in the stack"),
    },
    async ({ from_index, to_index }) => {
      const result = await sendCommand("reorder_layers", { from_index, to_index });
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Layer moved from index ${from_index} to ${to_index}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "duplicate_layer",
    "Duplicate an entire layer and all of its pixel cels across every frame in the project.",
    {
      index: coerceInt(0).optional().describe("Layer index to duplicate (defaults to active layer)"),
    },
    async ({ index }) => {
      const params: Record<string, unknown> = {};
      if (index !== undefined) params.index = index;
      const result = await sendCommand("duplicate_layer", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Layer duplicated: "${result.data?.name}" at index [${result.data?.new_index}] (Total layers: ${result.data?.total_layers})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "merge_layers",
    "Merge a source layer down into a target layer (composites cel pixels using alpha blending and removes the source layer).",
    {
      source_index: coerceInt(0).optional().describe("Layer index to merge down (defaults to current layer)"),
      target_index: coerceInt(0).optional().describe("Target layer index to merge into (defaults to layer below source)"),
    },
    async ({ source_index, target_index }) => {
      const params: Record<string, unknown> = {};
      if (source_index !== undefined) params.source_index = source_index;
      if (target_index !== undefined) params.target_index = target_index;
      const result = await sendCommand("merge_layers", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Merged layer into index [${result.data?.merged_into}]. Remaining layers: ${result.data?.remaining_layers}`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );

  server.tool(
    "create_layer_group",
    "Create a new folder/GroupLayer in Pixelorama to organize complex multi-layer character or scene rigs.",
    {
      name: z.string().default("Group").describe("Group folder name"),
      above_layer: coerceInt(0).optional().describe("Insert above this layer index (defaults to current layer)"),
    },
    async ({ name, above_layer }) => {
      const params: Record<string, unknown> = { name };
      if (above_layer !== undefined) params.above_layer = above_layer;
      const result = await sendCommand("create_layer_group", params);
      return {
        content: [
          {
            type: "text" as const,
            text: result.success
              ? `✅ Created Layer Group: "${name}" at index [${result.data?.index}] (Total layers: ${result.data?.total_layers})`
              : `❌ ${result.error}`,
          },
        ],
      };
    }
  );
}
