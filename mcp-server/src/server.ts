/**
 * pix-MCP — Server Setup
 *
 * Creates and configures the MCP server with all tool definitions.
 * Tools are registered from individual modules (canvas, drawing, color, etc.)
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerCanvasTools } from "./tools/canvas.js";
import { registerDrawingTools } from "./tools/drawing.js";
import { registerColorTools } from "./tools/color.js";
import { registerLayerTools } from "./tools/layers.js";
import { registerFrameTools } from "./tools/frames.js";
import { registerSelectionTools } from "./tools/selection.js";
import { registerAiHelperTools } from "./tools/ai_helpers.js";
import { registerVisionTools } from "./tools/vision.js";
import { registerImporterTools } from "./tools/importer.js";
import { registerProceduralTools } from "./tools/procedural.js";
import { registerTilemapTools } from "./tools/tilemap.js";
import { registerGodotExportTools } from "./tools/godot_export.js";

export function createServer(): McpServer {
  const server = new McpServer({
    name: "pix-mcp",
    version: "0.2.0",
  });

  // Register all tool groups
  registerCanvasTools(server);
  registerDrawingTools(server);
  registerColorTools(server);
  registerLayerTools(server);
  registerFrameTools(server);
  registerSelectionTools(server);
  registerAiHelperTools(server);
  registerVisionTools(server);
  registerImporterTools(server);
  registerProceduralTools(server);
  registerTilemapTools(server);
  registerGodotExportTools(server);

  console.error("[pix-MCP] All 40+ tools registered successfully");

  return server;
}
