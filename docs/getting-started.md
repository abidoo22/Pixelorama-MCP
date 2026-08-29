# 🚀 Getting Started with Pixelorama-MCP

Welcome to **Pixelorama-MCP**! This guide covers everything you need: installing the server, connecting an AI client, running drawing scripts manually, and importing existing images into Pixelorama.

---

## 📋 Prerequisites

- **Node.js** v18 or higher — [nodejs.org](https://nodejs.org/)
- **Pixelorama** v1.1.10-stable or higher — [pixelorama.org](https://www.pixelorama.org/)
- **Godot v4.6+** *(only if you want to modify or recompile the bridge plugin)*

---

## Step 1 — Clone and Build the MCP Server

```bash
git clone https://github.com/abidoo22/Pixelorama-MCP.git
cd Pixelorama-MCP/mcp-server
npm install
npm run build
```

This compiles TypeScript into `mcp-server/dist/index.js`.

---

## Step 2 — Install the Pixelorama Plugin

The bridge plugin runs a lightweight HTTP server inside Pixelorama on port `7373`. The MCP server talks to it.

1. Launch Pixelorama
2. Go to **Edit → Preferences** (or `Ctrl+,`) → **Extensions** tab
3. Click **Add Extension** and select `pixelorama-plugin/PixMcpBridge.pck`
4. Click **Enable** next to the extension
5. Close Preferences and **restart Pixelorama**

**Verify it's working:**
```bash
curl -s http://127.0.0.1:7373/health
```
Expected response:
```json
{
  "status": "ok",
  "server": "pix-mcp-bridge",
  "pixelorama_version": "v1.2.1-stable",
  "api_version": 9
}
```

---

## Step 3 — Connect to Your AI Client

### Claude Desktop

Edit your config file:
- **Linux:** `~/.config/Claude/claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "pixelorama": {
      "command": "node",
      "args": ["/absolute/path/to/Pixelorama-MCP/mcp-server/dist/index.js"]
    }
  }
}
```

Restart Claude Desktop. You should see pixelorama appear in the tools list.

### Cursor IDE

1. Go to **Settings → Features → MCP**
2. Click **+ Add New MCP Server**
3. Set **Name** to `pixelorama`, **Type** to `command`, **Command** to:
   ```
   node /absolute/path/to/Pixelorama-MCP/mcp-server/dist/index.js
   ```
4. Save and verify the status turns green

---

## Step 4 — Your First Drawing Prompt

Make sure Pixelorama is open and visible. Then ask your AI client:

> *"Create a 64x64 canvas named 'Apple' and draw a shiny red apple with a green leaf and a drop shadow"*

The AI will call `create_canvas`, compute the geometry and shading in memory, and batch-send all pixels to Pixelorama via `draw_pixels`. You'll see it appear live.

---

## <a name="manual-scripts"></a> Running Drawing Scripts Manually (No API Key Needed)

Don't have an API key? No problem. Every example in `docs/examples/` is a standalone Node.js script you can run directly.

**Make sure Pixelorama is open and visible, then:**
```bash
node docs/examples/draw_coin.js
node docs/examples/draw_potato.js
node docs/examples/draw_banana.js
```

Each script connects to port `7373`, creates its canvas, computes all geometry locally, and draws everything in optimized batches.

**Want a custom sprite?** Describe what you want to an AI assistant (Claude, ChatGPT, etc.) and ask it to write you a drawing script in the same style as the examples. Paste the coin script as a reference — the AI will understand the pattern immediately.

---

## <a name="image-import"></a> Importing Any Image into Pixelorama

This is the most powerful workflow for complex sprites. Generate an image with any AI tool (Midjourney, DALL-E, Stable Diffusion, Nano Banana, etc.), then import it directly into Pixelorama as an editable pixel art file.

### How it works

The import script (`docs/examples/import_universal_asset.js`):
1. Reads any PNG file using only built-in Node.js modules (no external dependencies)
2. Auto-detects the background color by sampling the image corners
3. Strips out background pixels using Euclidean color distance
4. Lets you blacklist additional colors by RGB value
5. Streams the remaining pixels into Pixelorama with full transparency

### Setup

Open `docs/examples/import_universal_asset.js` and edit the **USER CONFIGURATION ZONE** at the top:

```javascript
// 1. Path to your source image
const IMAGE_PATH = './my-sprite.png';

// 2. Colors to remove (add as many as needed)
const bannedColors = [
  { r: 166, g: 163, b: 156 }, // example: background gray
  { r: 36,  g: 231, b: 30  }, // example: artifact green outline
];

// 3. How aggressively to clean edges (higher = more aggressive)
const TOLERANCE = 20;
```

Then run:
```bash
node docs/examples/import_universal_asset.js
```

### Tips for best results

**Choosing TOLERANCE:**
- `10–15` — conservative, preserves fine color gradients near edges
- `20–25` — good default for most AI-generated images
- `30+` — aggressive, use if background bleeds into the sprite edges

**Finding background colors to blacklist:**
Open your source image in any image editor, use the color picker on the background area, and note the RGB values. Add them to `bannedColors`.

**Preparing your source image:**
- Use a flat, solid background color when generating (not gradient)
- Higher resolution source = more detail preserved
- PNG format only (JPEG compression artifacts cause color bleeding)

---

## Performance Reference

| Canvas Size | Recommended Batch Size | Typical Draw Time |
|---|---|---|
| 64×64 | All pixels at once | < 1 second |
| 128×128 | 15,000 pixels/batch | 1–3 seconds |
| 256×256 | 15,000 pixels/batch | 5–10 seconds |
| 512×512+ | 15,000 pixels/batch | 20–60 seconds |

---

## Troubleshooting

**Port 7373 refused / no response**
- Make sure the PixMcpBridge extension is enabled in Pixelorama's preferences
- Make sure Pixelorama is fully open (not minimized)
- Check if the extension was quarantined — see [Plugin Setup](plugin-setup.md#quarantine)

**Drawing appears but is very slow**
- Pixelorama is probably minimized or hidden — bring it to the foreground
- Reduce batch size to 2,000 if on a slow machine

**Background not fully removed after import**
- Sample the exact background RGB values from your image and add them to `bannedColors`
- Increase `TOLERANCE` by 5–10

**Extension disappeared from Pixelorama preferences**
- It was quarantined due to a load error — see [Plugin Setup](plugin-setup.md#quarantine) for the fix
