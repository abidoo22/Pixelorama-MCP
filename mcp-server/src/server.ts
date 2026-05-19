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

export function createServer(): McpServer {
  const server = new McpServer({
    name: "pix-mcp",
    version: "0.1.0",
  });

  // Register all tool groups
  registerCanvasTools(server);
  registerDrawingTools(server);
  registerColorTools(server);
  registerLayerTools(server);
  registerFrameTools(server);
  registerSelectionTools(server);
  registerAiHelperTools(server);

  console.error("[pix-MCP] All tools registered");

  return server;
}
