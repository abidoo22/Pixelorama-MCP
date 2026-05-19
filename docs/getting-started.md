# 🚀 Getting Started with pix-MCP

Welcome to **pix-MCP**! This guide walks you through the step-by-step process of setting up the environment, installing the Model Context Protocol (MCP) server, configuring it with your favorite AI client (like Claude Desktop or Cursor), and running your very first drawing command.

---

## 📋 Prerequisites

Before you begin, ensure you have the following installed on your system:
- **Node.js** (version 18 or higher)
- **npm** (comes bundled with Node.js)
- **Pixelorama** (version v1.1.10-stable)
- **Godot v4.6** (only required if you want to modify or compile the bridge extension)

---

## 🛠️ Step 1: Clone and Build the MCP Server

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/abidoo22/Pixelorama-MCP.git
   cd Pixelorama-MCP
   ```

2. **Install and Build Server Dependencies:**
   ```bash
   cd mcp-server
   npm install
   npm run build
   ```

   This will compile the TypeScript files and place the final JavaScript build inside `mcp-server/dist/index.js`.

---

## 📦 Step 2: Install and Enable the Pixelorama Extension

To allow the MCP server to communicate with Pixelorama, you must install the lightweight REST bridge extension.

1. **Locate the Pre-compiled PCK:**
   The pre-compiled extension is located at `pixelorama-plugin/PixMcpBridge.pck`.

2. **Add to Pixelorama:**
   - Launch Pixelorama.
   - Go to **Edit → Preferences** (or press `Ctrl + ,`).
   - Navigate to the **Extensions** tab.
   - Click the **Add Extension** button at the top.
   - Select the `PixMcpBridge.pck` file.
   - Click **Enable** next to the newly loaded extension.
   - Close the Preferences dialog and restart Pixelorama.

3. **Verify Connection:**
   Open a terminal and perform a health check:
   ```bash
   curl -s http://127.0.0.1:7373/health
   ```
   You should receive a successful JSON response:
   ```json
   {
     "status": "ok",
     "server": "pix-mcp-bridge",
     "pixelorama_version": "v1.1.10-stable",
     "api_version": 8
   }
   ```

---

## 🔌 Step 3: Connect to your AI Client

### A. Connecting to Claude Desktop
Add the server definition to your `claude_desktop_config.json`:

* **Linux:** `~/.config/Claude/claude_desktop_config.json`
* **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
* **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "pix-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/pix-MCP/mcp-server/dist/index.js"]
    }
  }
}
```

### B. Connecting to Cursor IDE
1. Open Cursor and navigate to **Settings → Features → MCP**.
2. Click **+ Add New MCP Server**.
3. Fill out the fields:
   - **Name:** `pix-mcp`
   - **Type:** `command`
   - **Command:** `node /absolute/path/to/pix-MCP/mcp-server/dist/index.js`
4. Click **Save** and verify the status turns green.

---

## 🎨 Step 4: Your First Drawing Prompt

Once connected, start a new chat session with your AI assistant and send a drawing prompt:

> **Prompt:** *"Create a 64x64 canvas named 'Apple' and draw a beautiful shiny red apple on it with a green leaf and a nice drop shadow!"*

### 💡 What the AI will do under the hood:
1. Call `create_canvas` to set up the 64x64 artboard.
2. Formulate a shading grid (with highlights on the top-left, shadows on the bottom-right).
3. Compute the drop shadow offset.
4. Draw the outline and details in high-performance pixel batches via `draw_pixels`.
5. Focus and center the screen so you can inspect your brand-new sprite instantly!

---

## ⚡ High-Speed Drawing & Manual Custom Scripts

### A. How to Run & Draw Scripts Manually (For Humans)
If you want to write or execute a `.js` drawing script yourself instead of asking an AI client, follow these steps:

> [!IMPORTANT]
> **🖥️ Pixelorama Window Must Be Visible & Not Minimized:**
> Godot throttles process loops and rendering ticks when the application is minimized or run entirely in the background. **For the drawing commands to process instantly, make sure Pixelorama is fully open on your screen and not minimized!**

1. **Make sure Pixelorama is open:**
   Launch it in single-window mode to cleanly handle active popups:
   ```bash
   /home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.x86_64 --rendering-driver opengl3 --single-window &
   ```

2. **Run the script using Node.js:**
   Use node to execute any script in the `docs/examples/` folder directly:
   ```bash
   node docs/examples/draw_carrot.js
   ```
   This will connect to port `7373`, create a fresh canvas, procedurally render the carrot, and fit the camera viewport instantly.


3. **To draw custom sizes (e.g., 128x128):**
   Simply modify the `width`, `height`, and loop bounds inside the script to `128`. We recommend defining coordinates relatively (e.g. `const CX = W / 2`) so they scale automatically!

---

### B. Optimal Drawing Guidelines (For Other AI Agents)
When another AI agent connects to this workspace, they should follow these performance rules to draw at maximum speed without locking the Godot engine thread:

1. **Color Caching Advantage:**
   The `PixMcpBridge` plugin features a built-in `color_cache` lookup dictionary in its GDScript handler. It only parses hex values once per color in a batch. 

2. **Group by Color:**
   When compiling coordinates, group pixels with the same color together in your array payload. This ensures that the engine only executes a single string validation parse per unique hex key.

3. **Perfect Batch Sizes:**
   - For small grids (64x64 or less), send all pixels in a single batch.
   - For large grids (128x128 to 1024x1024), split the drawing payload into chunks of **`15,000` pixels per request**. This provides the absolute best balance between HTTP connection overhead and Godot engine thread rendering responsiveness.

4. **Canvas fit:**
   Always append a call to `fit_viewport` at the end of your drawing sequence to instantly center and center-fit the frame for the user's inspection.
