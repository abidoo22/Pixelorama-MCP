#!/usr/bin/env node
/**
 * pix-MCP — MCP Server Entry Point
 *
 * Starts the MCP server and connects it to the stdio transport
 * for communication with AI clients (Claude Desktop, Cursor, etc.)
 */

import { createServer } from "./server.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

async function main(): Promise<void> {
  const server = createServer();
  const transport = new StdioServerTransport();

  await server.connect(transport);
  console.error("[pix-MCP] Server started on stdio transport");
}

main().catch((error) => {
  console.error("[pix-MCP] Fatal error:", error);
  process.exit(1);
});
