# 🎨 pix-MCP

> **Let AI draw pixel art in Pixelorama — no drawing skills required.**

![AI Generated Coin in Pixelorama](coin.png)

pix-MCP is a [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server that bridges AI assistants (Claude, GPT, Gemini, etc.) with [Pixelorama](https://www.pixelorama.org/), the free & open-source pixel art editor.

Describe what you want in plain English. The AI handles the rest — shapes, colours, layers, animations, and full sprites.

---

## ✨ Features

- **30+ drawing tools** exposed as MCP tools — pixels, lines, rectangles, ellipses, polygons, flood fill, and more
- **Full layer management** — create, rename, reorder, set opacity & blend modes
- **Colour & palette control** — set colours, create palettes, pick colours from canvas
- **Animation support** — add/remove frames, set durations, export GIFs
- **Selection & transform** — rectangular/elliptical selection, move, resize, flip, rotate
- **AI helpers** — `generate_sprite` orchestrates multi-step drawing from a text prompt
- **Client-agnostic** — works with Claude Desktop, Cursor, autonomous agents, or any MCP-compatible client

## 🏗️ Architecture

```
AI Client (Claude / Cursor / etc.)
        │ MCP (JSON-RPC over stdio)
        ▼
   pix-MCP Server (TypeScript / Node.js)
        │ HTTP REST (localhost:7373)
        ▼
   Pixelorama Bridge Plugin (GDScript)
        │ ExtensionsApi v8
        ▼
   Pixelorama v1.1.10
```

## 📦 Quick Start

### Prerequisites

- [Node.js](https://nodejs.org/) ≥ 18
- [Pixelorama](https://www.pixelorama.org/) v1.1.10

### 1. Install the MCP server

```bash
git clone https://github.com/abidoo22/Pixelorama-MCP.git
cd Pixelorama-MCP/mcp-server
npm install
npm run build
```

### 2. Install the Pixelorama plugin

1. In Pixelorama, go to **Edit → Preferences → Extensions**
2. Click **Add Extension** and select `pixelorama-plugin/PixMcpBridge.pck`
3. Enable the extension and restart Pixelorama

### 3. Connect to your AI client

**Claude Desktop** — add to `claude_desktop_config.json`:

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

Then ask Claude: *"Create a 32×32 pixel art sword with a golden blade and brown handle"*

## 🛠️ Development

```bash
# MCP Server
cd mcp-server
npm install
npm run dev        # watch mode

# Test with MCP Inspector
npx @modelcontextprotocol/inspector node dist/index.js
```

See [docs/getting-started.md](docs/getting-started.md) for the full development guide.

## 📖 Documentation

- [Getting Started Guide](docs/getting-started.md) — Setup, prerequisites, and client integration
- [Tool Reference](docs/tool-reference.md) — Comprehensive details on all 35+ registered MCP tools
- [Plugin Setup & Troubleshoot](docs/plugin-setup.md) — Compiling Godot PCK and debugging quarantine blocks
- [Agentic Drawing Playbook](AGENTIC_DRAWING_PLAYBOOK.md) — 💡 **Highly Recommended:** Shading algorithms, star geometries, drop shadow rendering, and fast batch drawing tips for other agents and developers!
- [Worked Examples](docs/examples/) — Fully tested drawing scripts (potatoes, bananas, coins, etc.)

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a PR.

## 📄 License

[MIT](LICENSE) — go wild.

## 🙏 Credits

- [Pixelorama](https://www.pixelorama.org/) by Orama Interactive
- [Model Context Protocol](https://modelcontextprotocol.io/) by Anthropic
