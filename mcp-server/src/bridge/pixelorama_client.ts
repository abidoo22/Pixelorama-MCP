/**
 * Pixelorama Bridge Client
 *
 * HTTP client that sends commands to the Pixelorama plugin's local HTTP server.
 * All drawing operations are sent as POST /command with a JSON body.
 */

const BRIDGE_URL = process.env.PIX_MCP_BRIDGE_URL || "http://127.0.0.1:7373";
const REQUEST_TIMEOUT_MS = 10_000;

export interface BridgeResponse {
  success: boolean;
  data?: Record<string, unknown>;
  error?: string;
}

/**
 * Send a command to the Pixelorama bridge plugin.
 */
export async function sendCommand(
  tool: string,
  params: Record<string, unknown> = {}
): Promise<BridgeResponse> {
  const body = JSON.stringify({ tool, params });

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

    const response = await fetch(`${BRIDGE_URL}/command`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
      signal: controller.signal,
    });

    clearTimeout(timeout);

    const result = (await response.json()) as BridgeResponse;
    return result;
  } catch (error) {
    if (error instanceof Error && error.name === "AbortError") {
      return {
        success: false,
        error: `Request timed out after ${REQUEST_TIMEOUT_MS}ms. Is Pixelorama running with the pix-MCP bridge plugin enabled?`,
      };
    }

    const message =
      error instanceof Error ? error.message : "Unknown error";

    // Provide helpful error message if connection refused
    if (message.includes("ECONNREFUSED") || message.includes("fetch failed")) {
      return {
        success: false,
        error: `Cannot connect to Pixelorama bridge at ${BRIDGE_URL}. Make sure Pixelorama is running with the pix-MCP bridge plugin enabled.`,
      };
    }

    return { success: false, error: message };
  }
}

/**
 * Check if the Pixelorama bridge is reachable.
 */
export async function checkHealth(): Promise<BridgeResponse> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3000);

    const response = await fetch(`${BRIDGE_URL}/health`, {
      signal: controller.signal,
    });

    clearTimeout(timeout);
    return (await response.json()) as BridgeResponse;
  } catch {
    return {
      success: false,
      error: `Pixelorama bridge not reachable at ${BRIDGE_URL}`,
    };
  }
}
