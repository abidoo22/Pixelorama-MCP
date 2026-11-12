# 🔌 Pixelorama Bridge Plugin Setup, Updating & Architecture

The **Pixelorama REST Bridge Plugin (`PixMcpBridge.pck`)** is a lightweight extension for **Pixelorama** (v1.1.10 through v1.2.4+) that runs a local HTTP server on `127.0.0.1:7373` so AI assistants can draw, animate, and manage layers live on your canvas.

> 💡 **Regular user? You do NOT need Godot or to compile anything!**
> This repository already ships with a ready-to-use **`PixMcpBridge.pck`** file (both in the repository root and in `pixelorama-plugin/PixMcpBridge.pck`). Follow the quick steps right below and skip the developer compilation section.

---

## ✅ Quick Install & Updating (No Compiling Required)

### First-time install
1. Open **Pixelorama** and go to **Edit → Preferences** (`Ctrl+,`) → **Extensions**.
2. Click **Add Extension** and choose **`PixMcpBridge.pck`** from the `Pixelorama-MCP` folder.
3. Tick **Enable** next to **pix-MCP Bridge**, then **restart Pixelorama**.
4. Open `http://127.0.0.1:7373/health` in your browser to confirm you see `"status": "ok"`.

### Updating to a newer version
1. Pull or download the latest `Pixelorama-MCP` repository.
2. **Quit Pixelorama** completely.
3. Copy the updated **`PixMcpBridge.pck`** into your Pixelorama extensions folder (paths listed below) — *or* open Pixelorama, remove the old **pix-MCP Bridge** under **Edit → Preferences → Extensions**, click **Add Extension** to select the new `PixMcpBridge.pck`, and restart Pixelorama.

---

## 📁 Where Pixelorama Stores Installed Extensions

Depending on how you installed Pixelorama, it loads `PixMcpBridge.pck` from one of these folders:

### A. Standard Installations (Installer, System Package, AppImage, DMG)
* **Linux:** `~/.local/share/pixelorama/extensions/PixMcpBridge.pck`
* **macOS:** `~/Library/Application Support/Pixelorama/extensions/PixMcpBridge.pck`
* **Windows:** `%APPDATA%\Pixelorama\extensions\PixMcpBridge.pck`

### B. Portable Mode (Unzipped folder with a `pixelorama_data` directory next to the app)
If a `pixelorama_data` folder exists next to your Pixelorama executable, Pixelorama reads extensions **only** from there:
* `Pixelorama-Linux-64bit/pixelorama_data/Extensions/PixMcpBridge.pck` *(or `extensions/`)*

---

## ⚠️ Troubleshooting: Why Did the Extension Disappear? (Quarantine System)

Pixelorama includes an automatic safety feature so broken extensions can never crash startup:

1. **What happens:** If Pixelorama hits an error loading an extension, it marks it faulty and moves the `.pck` file out of `extensions/` into a sibling `give_in_bug_report/` folder (for example `~/.local/share/pixelorama/give_in_bug_report/PixMcpBridge.pck`).
2. **The symptom:** `pix-MCP Bridge` disappears from **Edit → Preferences → Extensions**.
3. **How to fix it:**
   1. Quit Pixelorama.
   2. Delete any old `PixMcpBridge.pck` inside `give_in_bug_report/`.
   3. Copy the fresh `PixMcpBridge.pck` from this repository back into `extensions/` (or add it again via **Edit → Preferences → Extensions → Add Extension**).
   4. Restart Pixelorama.

### Lockfile cleanup (if Pixelorama was force-closed)
Pixelorama writes a `.running` file while open. If a crash or force-kill leaves an orphan lockfile behind on Linux:
```bash
killall -9 Pixelorama.x86_64 || true
rm -f ~/.local/share/pixelorama/.running
```

---

## 🛠️ For Contributors & Maintainers Only: Compiling `.pck` from Source

You only need this section if you modified the GDScript files inside `pixelorama-plugin/` and want to repackage `PixMcpBridge.pck` using **Godot 4.x**.

### Directory Layout (`pixelorama-plugin/`)
- **`extension.json`** — Extension metadata and supported Pixelorama API versions (`6`–`10`, including Pixelorama 1.2.4).
- **`Main.tscn` & `Main.gd`** — Background thread TCP listener on `127.0.0.1:7373` that safely dispatches commands to Pixelorama's main thread.
- **`command_handler.gd`** — Translates MCP REST commands into Pixelorama `ExtensionsApi` operations, compact-cel offset math, and Undo/Redo history.
- **`converter.gd`, `lookup_color.gdshader`, `lookup_similar.gdshader`** — Bundled GIF exporter helper script and shaders so `PixMcpBridge.pck` packs completely from any clean clone.

### 1. Build a development `.pck` (without touching release files)
By default, `pack.gd` writes `PixMcpBridge-dev.pck` (ignored by Git) so contributors can test safely before replacing an installed extension:

```bash
# Linux / Windows (when `godot` is on your PATH)
godot --headless --path "$PWD" -s pack.gd

# macOS example
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path "$PWD" -s pack.gd
```

### 2. Build the release `PixMcpBridge.pck` for users
When publishing an update to GitHub so regular users get the pre-built plugin automatically, set `PIX_MCP_PCK_OUTPUT="PixMcpBridge.pck"` and update both copies in the repository:

```bash
PIX_MCP_PCK_OUTPUT="PixMcpBridge.pck" godot --headless --path "$PWD" -s pack.gd
cp PixMcpBridge.pck pixelorama-plugin/PixMcpBridge.pck
```

You should see `[9/9 - 100%]` in the Godot output confirming the plugin scripts and GIF shaders were all packaged cleanly.
