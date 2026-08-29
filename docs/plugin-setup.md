# 🔌 Pixelorama Bridge Plugin Setup & Architecture

The **Pixelorama REST Bridge Plugin** is a lightweight Godot-based extension targeting **Pixelorama** that runs a simple local HTTP server inside the Pixelorama environment on port `7373`. It parses JSON commands received from the `Pixelorama-MCP` server over HTTP REST and translates them into Godot API calls via the Pixelorama `ExtensionsApi`.

This guide documents the layout, compilation process, and troubleshooting mechanisms of the extension.

---

## 🏗️ Directory Layout

The plugin source code is located in `pixelorama-plugin/` and consists of the following key files:
- **`extension.json`:** The metadata configuration declaring the plugin name, version, API version limits, and standard entries.
- **`Main.tscn`:** The main Godot scene loader file pointing to `Main.gd`.
- **`Main.gd`:** Initializes the `TCPServer` listening on port `7373` and processes standard TCP clients.
- **`command_handler.gd`:** The translator mapping the REST tool payloads to their corresponding `ExtensionsApi` functions.

---

## 🛠️ Compiling and Packing the PCK

Pixelorama extensions must be bundled as compressed Godot PCK or ZIP packages to load correctly.

To pack the source files into a compiled `PixMcpBridge.pck`:
1. Ensure you have **Godot v4.6** (or the exact Pixelorama editor binary) available.
2. Run the provided packing utility script:
   ```bash
   Godot_v4.6 --headless -s pack.gd
   ```

This runs `pack.gd` in a headless terminal, packaging `extension.json`, `Main.tscn`, `Main.gd`, and `command_handler.gd` with relative paths (`src/Extensions/PixMcpBridge/`) into `PixMcpBridge.pck`.

---

## 📁 Installation Directory Pathing

Depending on how Pixelorama is installed, it will look for extensions in different directories:

### A. Portable Mode (Standard for zipped releases)
If you run a portable version of Pixelorama, it reads extensions **only** from the folder next to its executable:
* `Pixelorama-Linux-64bit/pixelorama_data/Extensions/PixMcpBridge.pck`

### B. Standard Mode (Standard for system/flatpak/snap installations)
Standard system installations read extensions from the user share directory:
* **Linux:** `~/.local/share/pixelorama/extensions/PixMcpBridge.pck`
* **macOS:** `~/Library/Application Support/Pixelorama/extensions/PixMcpBridge.pck`
* **Windows:** `%APPDATA%\Pixelorama\extensions\PixMcpBridge.pck`

---

## ⚠️ Troubleshooting: The Quarantine System

Pixelorama features an automatic safety system to prevent corrupted or crash-prone extensions from blocking app startups:

1. **The Quarantine Action:** If Pixelorama encounters a compilation, pathing, or runtime error while loading an extension, it immediately flags it as **"Faulty"** and moves the PCK file out of the active `extensions/` directory.
2. **The Destination:** It moves the faulty PCK to a subdirectory named `give_in_bug_report/`:
   - `~/.local/share/pixelorama/give_in_bug_report/PixMcpBridge.pck`
3. **The Symptom:** The extension suddenly disappears from the **Edit → Preferences → Extensions** list and cannot be re-enabled.

### How to Fix Quarantine Block:
1. Terminate Pixelorama.
2. Navigate to your user share directory and delete the quarantined file from the `give_in_bug_report/` folder.
3. Fix any underlying script compile errors.
4. Re-compile and copy a clean, working `PixMcpBridge.pck` back to the active `extensions/` folder.
5. Restart Pixelorama.

---

## 🔒 Lockfile Handling

Pixelorama writes a small lockfile named `.running` to the user share directory when launching. If Pixelorama crashes or is killed forcefully, this lockfile can sometimes persist, causing subsequent headless runs to believe a instance is already active.

To guarantee a clean start, you can safely wipe the lockfile:
```bash
# Force kill any active orphan processes and remove the lockfile
killall -9 Pixelorama.x86_64 || true
rm -f ~/.local/share/pixelorama/.running
```
