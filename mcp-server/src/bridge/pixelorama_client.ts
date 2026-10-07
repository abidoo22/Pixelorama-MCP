/**
 * Pixelorama Bridge Client
 *
 * HTTP client that sends commands to the Pixelorama plugin's local HTTP server.
 * All drawing operations are sent as POST /command with a JSON body.
 */

const BRIDGE_URL = process.env.PIX_MCP_BRIDGE_URL || "http://127.0.0.1:7373";
const DEFAULT_TIMEOUT_MS = parseInt(process.env.PIX_MCP_TIMEOUT_MS || "30000", 10) || 30_000;

export interface BridgeResponse {
  success: boolean;
  data?: Record<string, any>;
  error?: string;
}

// FIFO queue to serialize commands and prevent race conditions when LLMs fire parallel tool calls
let commandQueue: Promise<unknown> = Promise.resolve();

/**
 * Send a command to the Pixelorama bridge plugin.
 * Serialized in strict order to avoid concurrent mutation races.
 */
export async function sendCommand(
  tool: string,
  params: Record<string, unknown> = {},
  timeoutMs?: number
): Promise<BridgeResponse> {
  return new Promise<BridgeResponse>((resolve) => {
    commandQueue = commandQueue
      .then(async () => {
        const res = await _executeHttpCommand(tool, params, timeoutMs);
        resolve(res);
      })
      .catch((err) => {
        resolve({
          success: false,
          error: err instanceof Error ? err.message : String(err),
        });
      });
  });
}

async function _executeHttpCommand(
  tool: string,
  params: Record<string, unknown>,
  timeoutMs?: number
): Promise<BridgeResponse> {
  const body = JSON.stringify({ tool, params });
  const effectiveTimeout = timeoutMs ?? DEFAULT_TIMEOUT_MS;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), effectiveTimeout);

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
        error: `Request timed out after ${effectiveTimeout}ms while executing '${tool}'. The operation may still be processing or completed inside Pixelorama. You can increase timeout via PIX_MCP_TIMEOUT_MS environment variable (e.g. 60000).`,
      };
    }

    const message =
      error instanceof Error ? error.message : "Unknown error";

    // Provide helpful error message if connection refused
    if (message.includes("ECONNREFUSED") || message.includes("fetch failed")) {
      return {
        success: false,
        error: `Cannot connect to Pixelorama bridge at ${BRIDGE_URL}. Make sure Pixelorama is running with the PixMcpBridge.pck plugin enabled.`,
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
